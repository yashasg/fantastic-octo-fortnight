import ComposableArchitecture
import XCTest

@testable import EyePostureReminder

/// `TestStore` baseline coverage for `OverlayFeature` (Phase 1 reducer
/// `p0-tca-8` / #671). Verifies the synchronous state mutations and pure
/// dispatch contracts of every action. `#920` removed the legacy
/// `OverlayManager` UIWindow path; long-form behavioural parity now
/// lives in `OverlayFeatureBehaviorTests` (the reducer owns the
/// dismiss-broadcast / audio / accessibility side effects directly).
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
        XCTAssertFalse(state.isFinalized, "isFinalized defaults to false")
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
        // Two-phase dismiss (#738): `.timerExpired` flips `isDismissing`
        // and emits analytics, but the actual dismissal side-effects
        // (resume audio, broadcast `.dismissed`, post screenChanged)
        // are deferred until the view (or this test) sends
        // `.dismissAnimationCompleted`.
        await store.receive(\.timerExpired) {
            $0.isDismissing = true
        }
        await store.send(.dismissAnimationCompleted) {
            $0.isFinalized = true
        }
        await store.receive(\.dismissed)
        await store.finish()
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
        await store.send(.dismissAnimationCompleted) {
            $0.isFinalized = true
        }
        await store.receive(\.dismissed)
        await store.finish()
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
        await store.send(.dismissAnimationCompleted) {
            $0.isFinalized = true
        }
        await store.receive(\.dismissed)
        await store.finish()
    }

    // MARK: - .dismissTapped

    func test_dismissTapped_setsIsDismissingButDoesNotEmitDismissed() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 10)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        // Phase 1: tap flips `isDismissing` only — no `.dismissed` follow-up
        // because the view still has to play its exit animation. (#738)
        await store.send(.dismissTapped) {
            $0.isDismissing = true
        }
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
        await store.finish()
    }

    // MARK: - .timerExpired

    func test_timerExpired_setsIsDismissingButDoesNotEmitDismissed() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .posture, duration: 5)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        // Phase 1: auto-expiry flips `isDismissing` only — no `.dismissed`
        // follow-up because the view still has to play its exit animation.
        // (#738)
        await store.send(.timerExpired) {
            $0.isDismissing = true
        }
    }

    func test_timerExpired_whileAlreadyDismissing_isNoOp() async {
        var initial = OverlayFeature.State(type: .eyes, duration: 5)
        initial.isDismissing = true
        let store = TestStore(initialState: initial) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.timerExpired)
    }

    // MARK: - .dismissAnimationCompleted (#738 — two-phase dismiss completion)

    /// `.dismissAnimationCompleted` after `.dismissTapped` flips
    /// `isFinalized` and triggers the actual dismiss side-effect chain.
    func test_dismissAnimationCompleted_afterDismissTapped_dispatchesDismissed() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 10)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.dismissTapped) {
            $0.isDismissing = true
        }
        await store.send(.dismissAnimationCompleted) {
            $0.isFinalized = true
        }
        await store.receive(\.dismissed)
        await store.finish()
    }

    /// `.dismissAnimationCompleted` after `.timerExpired` flips
    /// `isFinalized` and triggers the actual dismiss side-effect chain.
    func test_dismissAnimationCompleted_afterTimerExpired_dispatchesDismissed() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .posture, duration: 5)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.timerExpired) {
            $0.isDismissing = true
        }
        await store.send(.dismissAnimationCompleted) {
            $0.isFinalized = true
        }
        await store.receive(\.dismissed)
        await store.finish()
    }

    /// Idempotency guard: re-arrival of `.dismissAnimationCompleted` (e.g.
    /// SwiftUI animation interrupt firing the completion callback twice)
    /// must not dispatch `.dismissed` a second time, which would otherwise
    /// double-broadcast `.dismissed` and double-run the resume-audio path.
    func test_dismissAnimationCompleted_reentrant_isNoOp() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 10)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.dismissTapped) {
            $0.isDismissing = true
        }
        await store.send(.dismissAnimationCompleted) {
            $0.isFinalized = true
        }
        await store.receive(\.dismissed)

        // Second arrival is a pure no-op — no state delta, no follow-up.
        await store.send(.dismissAnimationCompleted)
        await store.finish()
    }

    /// Out-of-order arrival: a stray `.dismissAnimationCompleted` before any
    /// dismiss path has fired must not flip `isFinalized` or trigger the
    /// dismiss side effect — the reducer would be free to interpret it as
    /// "dismiss now" otherwise, breaking the `isDismissing` precondition.
    func test_dismissAnimationCompleted_beforeAnyDismissPath_isNoOp() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 10)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.dismissAnimationCompleted)
    }

    // MARK: - .dismissed

    func test_dismissed_isAcceptedAndCancelsTimer() async {
        let store = TestStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 10)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        await store.send(.dismissed)
        await store.finish()
    }
}
