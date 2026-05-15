import ComposableArchitecture
import Foundation

/// Phase 1 reducer (`p0-tca-8` / #671) backing the on-screen break overlay.
///
/// Owns the *currently presented* overlay's state — countdown, dismissal
/// flag, and analytics emission for both manual and automatic dismissal.
/// Lifecycle events from `OverlayClient.lifecycleEvents` are intentionally
/// consumed by `SchedulingFeature` (`p0-tca-10`), not here, so this reducer
/// stays focused on a single presentation instance.
///
/// ## Two-phase dismiss (issue #738)
///
/// `.dismissTapped` and `.timerExpired` no longer call `overlayClient.dismiss`
/// directly. Instead they:
/// 1. flip `state.isDismissing = true` (so the view can react and start
///    its slide-up + fade exit animation),
/// 2. emit the corresponding analytics event,
/// 3. cancel the running timer effect.
///
/// The view (or test) must then dispatch `.dismissAnimationCompleted` once
/// its exit transition has finished. That second action owns the
/// `overlayClient.dismiss()` side effect (which tears down the
/// `OverlayManager` `UIWindow` synchronously) and emits `.dismissed`.
///
/// This split is required by `#702` Phase 2 (wire `OverlayView` to the
/// store): without it, the reducer would tear the `UIWindow` down before
/// `OverlayView`'s ~0.4 s `AppAnimation.overlayDismiss` /
/// `AppAnimation.overlayAutoDismiss` transition could play, regressing
/// overlay UX to a hard cut.
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
        /// Set after `.dismissAnimationCompleted` has triggered the
        /// `overlayClient.dismiss` effect. Guards against re-entrant
        /// completion callbacks (e.g. SwiftUI firing `.onCompletion` more
        /// than once across animation interrupts) double-tearing the
        /// underlying `UIWindow`.
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
        /// exit animation has finished. Owns the `overlayClient.dismiss()`
        /// side effect that tears down the underlying `UIWindow`. Idempotent
        /// — guarded by `state.isFinalized`.
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
                guard state.secondsRemaining > 0 else {
                    return .send(.timerExpired)
                }
                return .run { [clock] send in
                    for await _ in clock.timer(interval: .seconds(1)) {
                        await send(.timerTick)
                    }
                }
                .cancellable(id: CancelID.timer, cancelInFlight: true)

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
                // The actual `overlayClient.dismiss()` side effect runs once
                // the view dispatches `.dismissAnimationCompleted`.
                return .cancel(id: CancelID.timer)

            case .settingsTapped:
                let elapsed = elapsed(in: state)
                analyticsClient.log(
                    .overlayDismissed(
                        type: state.type,
                        method: .settingsTap,
                        elapsedS: elapsed
                    )
                )
                return .none

            case .timerExpired:
                guard !state.isDismissing else { return .none }
                state.isDismissing = true
                analyticsClient.log(
                    .overlayAutoDismissed(type: state.type, durationS: state.duration)
                )
                // Two-phase dismiss (#738): same as `.dismissTapped`. The
                // auto-dismiss exit animation runs in the view; the
                // `overlayClient.dismiss()` side effect waits for
                // `.dismissAnimationCompleted`.
                return .cancel(id: CancelID.timer)

            case .dismissAnimationCompleted:
                // Idempotent — multiple completion callbacks (e.g. SwiftUI
                // animation interrupts) must not tear the overlay window
                // down twice. Also tolerate arrival in unexpected order
                // (e.g. before any dismiss path has fired) by gating on
                // `isDismissing`.
                guard state.isDismissing, !state.isFinalized else {
                    return .none
                }
                state.isFinalized = true
                return .run { [overlayClient] send in
                    await overlayClient.dismiss()
                    await send(.dismissed)
                }

            case .dismissed:
                return .cancel(id: CancelID.timer)
            }
        }
    }

    private func elapsed(in state: State) -> TimeInterval {
        max(0, state.duration - TimeInterval(state.secondsRemaining))
    }
}
