import ComposableArchitecture
import Foundation

/// Reducer (`p0-tca-8` / #671) backing the on-screen break overlay rendered
/// by `RootView.fullScreenCover(item:)`.
///
/// Owns the *currently presented* overlay's state — countdown, dismissal
/// flag, and analytics emission for both manual and automatic dismissal.
/// `#919` Phase 1 added the canonical `RootView.fullScreenCover` driven by
/// `state.overlay`; `#920` Phase 2 retired the parallel `OverlayManager`
/// `UIWindow` path, so this reducer now also owns:
///
/// - the audio-pause / resume side effects (`pauseMediaEnabled`-gated, via
///   `OverlayClient.pauseExternalAudio` / `resumeExternalAudio`),
/// - the `UIAccessibility.screenChanged` posts that fire on present and
///   dismiss (via `OverlayClient.postScreenChanged`),
/// - the `OverlayClient.lifecycleEvents` broadcast for `.presented`,
///   `.dismissed`, and `.settingsTapped` so `AppFeature` (settings handoff
///   #786) and `SchedulingFeature` (session-timing #901, DeviceActivity
///   #903) subscribers keep working unchanged.
///
/// `AppFeature` continues to own the `@Presents var overlay` slot teardown
/// once `.dismissed` arrives — the parent nil-write also drives the queue
/// pop for any pending `AppFeature.State.overlayQueue` entries.
///
/// ## Two-phase dismiss (issue #738)
///
/// `.dismissTapped` and `.timerExpired` no longer call any side effect
/// directly. Instead they:
/// 1. flip `state.isDismissing = true` (so the view can react and start
///    its slide-up + fade exit animation),
/// 2. emit the corresponding analytics event,
/// 3. cancel the running timer effect.
///
/// The view (or test) must then dispatch `.dismissAnimationCompleted` once
/// its exit transition has finished. That second action flips
/// `state.isFinalized` and dispatches `.dismissed`, which carries the
/// `resumeExternalAudio` + `broadcast(.dismissed)` + `postScreenChanged`
/// side effects. `AppFeature` observes `.overlay(.presented(.dismissed))`
/// to nil the slot and pop the queue head.
@Reducer
struct OverlayFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        let id: UUID
        let type: ReminderType
        let duration: TimeInterval
        let hapticsEnabled: Bool
        let pauseMediaEnabled: Bool
        var secondsRemaining: Int
        /// Set as soon as a dismiss path (`.dismissTapped` or
        /// `.timerExpired`) is acknowledged. The view observes this to drive
        /// its exit animation; the reducer uses it to suppress duplicate
        /// dismiss attempts.
        var isDismissing: Bool = false
        /// Set after `.dismissAnimationCompleted` has fired so re-entrant
        /// completion callbacks (e.g. SwiftUI firing `.onCompletion` more
        /// than once across animation interrupts) do not double-dispatch
        /// `.dismissed` and double-run the resume-audio / broadcast effects.
        var isFinalized: Bool = false

        init(
            id: UUID = UUID(),
            type: ReminderType,
            duration: TimeInterval,
            hapticsEnabled: Bool = true,
            pauseMediaEnabled: Bool = false
        ) {
            self.id = id
            self.type = type
            self.duration = duration
            self.hapticsEnabled = hapticsEnabled
            self.pauseMediaEnabled = pauseMediaEnabled
            self.secondsRemaining = max(0, Int(duration.rounded()))
        }
    }

    enum Action: Equatable {
        case onAppear
        case timerTick
        case dismissTapped
        case settingsTapped
        case timerExpired
        /// Dispatched by the view (or a test driver) once the overlay's
        /// exit animation has finished. Flips `state.isFinalized` and
        /// dispatches `.dismissed` so the side-effect chain (resume audio,
        /// broadcast `.dismissed`, post `screenChanged`) runs exactly once.
        /// Idempotent — guarded by `state.isFinalized`.
        case dismissAnimationCompleted
        case dismissed
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.overlayClient) var overlayClient: OverlayClient
    @Dependency(\.analyticsClient) var analyticsClient: AnalyticsClient

    private enum CancelID: Hashable {
        case timer
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let presentationEffects = onAppearSideEffects(state: state)
                guard state.secondsRemaining > 0 else {
                    return .merge(presentationEffects, .send(.timerExpired))
                }
                return .merge(
                    presentationEffects,
                    .run { [clock] send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            await send(.timerTick)
                        }
                    }
                    .cancellable(id: CancelID.timer, cancelInFlight: true)
                )

            case .timerTick:
                state.secondsRemaining = max(0, state.secondsRemaining - 1)
                if state.secondsRemaining == 0 {
                    return .send(.timerExpired)
                }
                return .none

            case .dismissTapped:
                guard !state.isDismissing else { return .none }
                state.isDismissing = true
                let elapsed = elapsed(in: state)
                let type = state.type
                analyticsClient.log(
                    .overlayDismissed(type: type, method: .button, elapsedS: elapsed)
                )
                // Two-phase dismiss (#738): cancel the running timer + flip
                // `isDismissing` so the view animates the exit transition.
                // The dismissal side-effects (resume audio, broadcast
                // `.dismissed`, post screenChanged) run from `.dismissed`
                // once the view dispatches `.dismissAnimationCompleted`.
                return .cancel(id: CancelID.timer)

            case .settingsTapped:
                let elapsed = elapsed(in: state)
                let type = state.type
                analyticsClient.log(
                    .overlayDismissed(
                        type: type,
                        method: .settingsTap,
                        elapsedS: elapsed
                    )
                )
                return .run { [overlayClient] _ in
                    await overlayClient.broadcast(.settingsTapped(type))
                }

            case .timerExpired:
                guard !state.isDismissing else { return .none }
                state.isDismissing = true
                analyticsClient.log(
                    .overlayAutoDismissed(type: state.type, durationS: state.duration)
                )
                // Two-phase dismiss (#738): same as `.dismissTapped`. The
                // auto-dismiss exit animation runs in the view; the
                // dismissal side-effects fire from `.dismissed` once
                // `.dismissAnimationCompleted` arrives.
                return .cancel(id: CancelID.timer)

            case .dismissAnimationCompleted:
                // Idempotent — multiple completion callbacks (e.g. SwiftUI
                // animation interrupts) must not run the dismissal side
                // effects twice. Also tolerate arrival in unexpected order
                // (e.g. before any dismiss path has fired) by gating on
                // `isDismissing`.
                guard state.isDismissing, !state.isFinalized else {
                    return .none
                }
                state.isFinalized = true
                return .send(.dismissed)

            case .dismissed:
                let type = state.type
                let pauseMediaEnabled = state.pauseMediaEnabled
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { [overlayClient] _ in
                        if pauseMediaEnabled {
                            await overlayClient.resumeExternalAudio()
                        }
                        await overlayClient.broadcast(.dismissed(type))
                        await overlayClient.postScreenChanged()
                    }
                )
            }
        }
    }

    private func elapsed(in state: State) -> TimeInterval {
        max(0, state.duration - TimeInterval(state.secondsRemaining))
    }

    /// Side effects fired exactly once when the overlay first appears on
    /// screen: optionally pause external audio (`pauseMediaEnabled`-gated),
    /// post `UIAccessibility.screenChanged` so VoiceOver refocuses on the
    /// overlay, and broadcast `.presented(type)` so `SchedulingFeature`
    /// session-timing (#901) and DeviceActivity hooks (#903) fire.
    private func onAppearSideEffects(state: State) -> Effect<Action> {
        let type = state.type
        let pauseMediaEnabled = state.pauseMediaEnabled
        return .run { [overlayClient] _ in
            if pauseMediaEnabled {
                await overlayClient.pauseExternalAudio()
            }
            await overlayClient.broadcast(.presented(type))
            await overlayClient.postScreenChanged()
        }
    }
}
