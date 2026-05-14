import ComposableArchitecture
import XCTest

@testable import EyePostureReminder

/// `TestStore` baseline coverage for `OverlayFeature` (Phase 1 reducer
/// `p0-tca-8` / #671). Verifies the synchronous state mutations and pure
/// dispatch contracts of every action; long-form behavioural parity with
/// `OverlayManager` lives under Phase 3 issue `p0-tca-20` (#683).
@MainActor
final class OverlayFeatureTests: XCTestCase {

    // MARK: - State.init

    func test_state_init_clampsNegativeDurationToZero() {
        let state = OverlayFeature.State(
            type: .eyes,
            duration: -5,
            hapticsEnabled: true,
            pauseMediaEnabled: false
        )

        XCTAssertEqual(state.secondsRemaining, 0,
                       "Negative duration must clamp secondsRemaining to 0")
    }

    func test_state_init_roundsFractionalDuration() {
        let state = OverlayFeature.State(
            type: .posture,
            duration: 19.6,
            hapticsEnabled: true,
            pauseMediaEnabled: true
        )

        XCTAssertEqual(state.secondsRemaining, 20,
                       "Fractional duration must round to nearest second")
    }

    func test_state_init_assignsDocumentedDefaults() {
        let id = UUID()
        let state = OverlayFeature.State(
            id: id,
            type: .eyes,
            duration: 10
        )

        XCTAssertEqual(state.id, id)
        XCTAssertEqual(state.type, .eyes)
        XCTAssertEqual(state.duration, 10)
        XCTAssertTrue(state.hapticsEnabled, "hapticsEnabled defaults to true")
        XCTAssertFalse(state.pauseMediaEnabled, "pauseMediaEnabled defaults to false")
        XCTAssertFalse(state.isDismissing, "isDismissing defaults to false")
        XCTAssertEqual(state.secondsRemaining, 10)
    }

    // MARK: - .onAppear

    func test_onAppear_withZeroSecondsRemaining_immediatelyExpires() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 0)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.onAppear)
        await store.receive(\.timerExpired) {
            $0.isDismissing = true
        }
        await store.receive(\.dismissed)
    }

    // MARK: - .timerTick

    func test_timerTick_decrementsSecondsRemaining() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 5)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.timerTick) {
            $0.secondsRemaining = 4
        }
    }

    func test_timerTick_atOne_decrementsAndEmitsTimerExpired() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .posture, duration: 1)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.timerTick) {
            $0.secondsRemaining = 0
        }
        await store.receive(\.timerExpired) {
            $0.isDismissing = true
        }
        await store.receive(\.dismissed)
    }

    func test_timerTick_belowZero_clampsAtZeroAndEmitsTimerExpired() async {
        var initial = OverlayFeature.State(type: .eyes, duration: 5)
        initial.secondsRemaining = 0
        let store = TestStore(initialState: initial) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.timerTick)
        // secondsRemaining stays clamped at 0 (max(0, 0-1) == 0) and re-fires expiry.
        await store.receive(\.timerExpired) {
            $0.isDismissing = true
        }
        await store.receive(\.dismissed)
    }

    // MARK: - .dismissTapped

    func test_dismissTapped_setsIsDismissingAndDismisses() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 10)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.dismissTapped) {
            $0.isDismissing = true
        }
        await store.receive(\.dismissed)
    }

    func test_dismissTapped_whileAlreadyDismissing_isNoOp() async {
        var initial = OverlayFeature.State(type: .eyes, duration: 10)
        initial.isDismissing = true
        let store = TestStore(initialState: initial) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.dismissTapped)
    }

    // MARK: - .settingsTapped

    func test_settingsTapped_logsAnalyticsAndProducesNoStateChange() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 10)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.settingsTapped)
    }

    // MARK: - .timerExpired

    func test_timerExpired_setsIsDismissingAndDismisses() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .posture, duration: 5)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.timerExpired) {
            $0.isDismissing = true
        }
        await store.receive(\.dismissed)
    }

    func test_timerExpired_whileAlreadyDismissing_isNoOp() async {
        var initial = OverlayFeature.State(type: .eyes, duration: 5)
        initial.isDismissing = true
        let store = TestStore(initialState: initial) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.timerExpired)
    }

    // MARK: - .dismissed

    func test_dismissed_isAcceptedAndCancelsTimer() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 10)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.dismissed)
    }
}
