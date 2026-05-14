import ComposableArchitecture
import Foundation

/// Phase 1 reducer (`p0-tca-8` / #671) backing the on-screen break overlay.
///
/// Owns the *currently presented* overlay's state — countdown, dismissal
/// flag, and analytics emission for both manual and automatic dismissal.
/// Lifecycle events from `OverlayClient.lifecycleEvents` are intentionally
/// consumed by `SchedulingFeature` (`p0-tca-10`), not here, so this reducer
/// stays focused on a single presentation instance.
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
        var isDismissing: Bool = false

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
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { [overlayClient] send in
                        await overlayClient.dismiss()
                        await send(.dismissed)
                    }
                )

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
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { [overlayClient] send in
                        await overlayClient.dismiss()
                        await send(.dismissed)
                    }
                )

            case .dismissed:
                return .cancel(id: CancelID.timer)
            }
        }
    }

    private func elapsed(in state: State) -> TimeInterval {
        max(0, state.duration - TimeInterval(state.secondsRemaining))
    }
}
