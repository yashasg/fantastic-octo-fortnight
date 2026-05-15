import ComposableArchitecture
import XCTest

@testable import EyePostureReminder

/// Phase 3 (`p0-tca-20` / #683) behavioural-parity coverage for
/// `OverlayFeature`.
///
/// Complements the synchronous-only `OverlayFeatureTests` by exercising
/// the reducer through its real `continuousClock` timer effect, the
/// `OverlayClient.dismiss` side effect, and every analytics emission the
/// previous `OverlayManager`/`OverlayManagerTests` pair guaranteed.
@MainActor
final class OverlayFeatureBehaviorTests: XCTestCase {

    // MARK: - Helpers

    /// Captured `AnalyticsEvent`s + `OverlayClient.dismiss` invocation count
    /// for assertion. Lock-isolated so the `@Sendable` client closures may
    /// mutate them safely from any executor.
    private struct Spies {
        let analytics: LockIsolated<[AnalyticsEvent]>
        let dismissCalls: LockIsolated<Int>
    }

    private func makeSpies() -> Spies {
        Spies(analytics: LockIsolated([]), dismissCalls: LockIsolated(0))
    }

    /// Builds a `TestStore` for `OverlayFeature` with a `TestClock`,
    /// analytics capture, and an `OverlayClient` whose `dismiss` increments
    /// `spies.dismissCalls`. Every other Phase-1 client is stubbed silent so
    /// child-reducer scopes inside `AppFeature` would not crash if these
    /// dependencies were ever read.
    private func makeStore(
        initialState: OverlayFeature.State,
        clock: TestClock<Duration>,
        spies: Spies
    ) -> TestStoreOf<OverlayFeature> {
        TestStore(initialState: initialState) {
            OverlayFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.continuousClock = clock
            $0.analyticsClient = AnalyticsClient(log: { event in
                spies.analytics.withValue { $0.append(event) }
            })
            $0.overlayClient = OverlayClient(
                show: { _, _, _, _ in },
                dismiss: { spies.dismissCalls.withValue { $0 += 1 } },
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { .finished }
            )
        }
    }

    // MARK: - .onAppear: TestClock drives the 1 s tick

    func test_onAppear_withPositiveDuration_emitsTickEverySecondUntilExpiry() async {
        let clock = TestClock()
        let spies = makeSpies()
        let store = makeStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 3),
            clock: clock,
            spies: spies
        )

        await store.send(.onAppear)

        await clock.advance(by: .seconds(1))
        await store.receive(\.timerTick) { $0.secondsRemaining = 2 }

        await clock.advance(by: .seconds(1))
        await store.receive(\.timerTick) { $0.secondsRemaining = 1 }

        await clock.advance(by: .seconds(1))
        await store.receive(\.timerTick) { $0.secondsRemaining = 0 }
        await store.receive(\.timerExpired) { $0.isDismissing = true }
        await store.send(.dismissAnimationCompleted) { $0.isFinalized = true }
        await store.receive(\.dismissed)

        XCTAssertEqual(spies.dismissCalls.value, 1,
                       "overlayClient.dismiss must fire exactly once on auto-expiry")
    }

    // MARK: - .dismissTapped: cancels timer + side effects

    func test_dismissTapped_cancelsRunningTimerEffectAndPreventsFurtherTicks() async {
        let clock = TestClock()
        let spies = makeSpies()
        let store = makeStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 10),
            clock: clock,
            spies: spies
        )

        await store.send(.onAppear)

        await clock.advance(by: .seconds(1))
        await store.receive(\.timerTick) { $0.secondsRemaining = 9 }

        await store.send(.dismissTapped) { $0.isDismissing = true }
        await store.send(.dismissAnimationCompleted) { $0.isFinalized = true }
        await store.receive(\.dismissed)

        // Advance well past the original duration: tick effect must be
        // cancelled, so no further `timerTick` actions arrive.
        await clock.advance(by: .seconds(30))
    }

    func test_dismissTapped_callsOverlayClientDismissExactlyOnce() async {
        let clock = TestClock()
        let spies = makeSpies()
        let store = makeStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 10),
            clock: clock,
            spies: spies
        )

        await store.send(.dismissTapped) { $0.isDismissing = true }
        // Two-phase dismiss (#738): `overlayClient.dismiss` must NOT have
        // fired yet — only the animation-completion phase owns that side
        // effect.
        XCTAssertEqual(spies.dismissCalls.value, 0,
                       "overlayClient.dismiss must not fire on dismissTapped alone (two-phase dismiss)")
        await store.send(.dismissAnimationCompleted) { $0.isFinalized = true }
        await store.receive(\.dismissed)

        XCTAssertEqual(spies.dismissCalls.value, 1,
                       "overlayClient.dismiss must fire exactly once per user tap")
    }

    func test_dismissTapped_immediately_logsOverlayDismissedWithButtonAndZeroElapsed() async {
        let clock = TestClock()
        let spies = makeSpies()
        let store = makeStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 20),
            clock: clock,
            spies: spies
        )

        await store.send(.dismissTapped) { $0.isDismissing = true }
        await store.send(.dismissAnimationCompleted) { $0.isFinalized = true }
        await store.receive(\.dismissed)

        let events = spies.analytics.value
        XCTAssertEqual(events.count, 1,
                       "Exactly one analytics event must be emitted on dismissTapped")
        guard let event = events.first,
              case let .overlayDismissed(type, method, elapsedS) = event else {
            return XCTFail("Expected .overlayDismissed but got \(events)")
        }
        XCTAssertEqual(type, .eyes)
        XCTAssertEqual(method, .button,
                       "User-tap dismissal must use DismissMethod.button")
        XCTAssertEqual(elapsedS, 0, accuracy: 0.001,
                       "Immediate dismissal must report 0 elapsed seconds")
    }

    func test_dismissTapped_afterTicks_logsCorrectElapsedSeconds() async {
        let clock = TestClock()
        let spies = makeSpies()
        let store = makeStore(
            initialState: OverlayFeature.State(type: .posture, duration: 20),
            clock: clock,
            spies: spies
        )

        await store.send(.onAppear)
        for tick in 1...3 {
            await clock.advance(by: .seconds(1))
            await store.receive(\.timerTick) { $0.secondsRemaining = 20 - tick }
        }

        await store.send(.dismissTapped) { $0.isDismissing = true }
        await store.send(.dismissAnimationCompleted) { $0.isFinalized = true }
        await store.receive(\.dismissed)

        let events = spies.analytics.value
        guard let event = events.first,
              case let .overlayDismissed(type, method, elapsedS) = event else {
            return XCTFail("Expected .overlayDismissed but got \(events)")
        }
        XCTAssertEqual(type, .posture)
        XCTAssertEqual(method, .button)
        XCTAssertEqual(elapsedS, 3, accuracy: 0.001,
                       "elapsedS must equal duration − secondsRemaining")
    }

    func test_dismissTapped_whileAlreadyDismissing_emitsNoAnalyticsAndNoOverlayCall() async {
        let clock = TestClock()
        let spies = makeSpies()
        var initial = OverlayFeature.State(type: .eyes, duration: 10)
        initial.isDismissing = true
        let store = makeStore(initialState: initial, clock: clock, spies: spies)

        await store.send(.dismissTapped)

        XCTAssertEqual(spies.analytics.value.count, 0,
                       "Re-entrant dismissTapped must not double-log analytics")
        XCTAssertEqual(spies.dismissCalls.value, 0,
                       "Re-entrant dismissTapped must not call overlay.dismiss again")
    }

    // MARK: - Two-phase dismiss ordering (#738)

    /// Asserts the strict happens-before ordering required by #702 Phase 2:
    /// **analytics → animation-pending → animation-completed → overlay
    /// client dismiss → dismissed.** The `overlayClient.dismiss` call is
    /// gated entirely on `.dismissAnimationCompleted` arriving — it never
    /// fires off `.dismissTapped` alone.
    func test_twoPhaseDismiss_dismissTapped_ordering() async {
        let clock = TestClock()
        let spies = makeSpies()
        let store = makeStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 30),
            clock: clock,
            spies: spies
        )

        // Phase 1: tap → analytics + isDismissing flip; no dismiss yet.
        await store.send(.dismissTapped) { $0.isDismissing = true }
        XCTAssertEqual(spies.analytics.value.count, 1,
                       "Analytics emits on dismissTapped, not on completion")
        XCTAssertEqual(spies.dismissCalls.value, 0,
                       "overlayClient.dismiss must wait for animation completion")

        // Phase 2: animation completes → overlayClient.dismiss + dismissed.
        await store.send(.dismissAnimationCompleted) { $0.isFinalized = true }
        await store.receive(\.dismissed)
        XCTAssertEqual(spies.dismissCalls.value, 1,
                       "overlayClient.dismiss must fire exactly once after completion")
    }

    /// Same ordering contract applied to the auto-dismiss path so the view
    /// can play `AppAnimation.overlayAutoDismiss` before the underlying
    /// `UIWindow` is torn down.
    func test_twoPhaseDismiss_timerExpired_ordering() async {
        let clock = TestClock()
        let spies = makeSpies()
        let store = makeStore(
            initialState: OverlayFeature.State(type: .posture, duration: 10),
            clock: clock,
            spies: spies
        )

        await store.send(.timerExpired) { $0.isDismissing = true }
        XCTAssertEqual(spies.analytics.value.count, 1,
                       "Analytics emits on timerExpired, not on completion")
        XCTAssertEqual(spies.dismissCalls.value, 0,
                       "overlayClient.dismiss must wait for animation completion")

        await store.send(.dismissAnimationCompleted) { $0.isFinalized = true }
        await store.receive(\.dismissed)
        XCTAssertEqual(spies.dismissCalls.value, 1,
                       "overlayClient.dismiss must fire exactly once after completion")
    }

    /// Defence-in-depth: a re-entrant `.dismissAnimationCompleted` (e.g.
    /// SwiftUI animation interrupt firing the completion callback twice)
    /// must not call `overlayClient.dismiss` a second time.
    func test_dismissAnimationCompleted_reentrant_doesNotCallOverlayDismissTwice() async {
        let clock = TestClock()
        let spies = makeSpies()
        let store = makeStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 10),
            clock: clock,
            spies: spies
        )

        await store.send(.dismissTapped) { $0.isDismissing = true }
        await store.send(.dismissAnimationCompleted) { $0.isFinalized = true }
        await store.receive(\.dismissed)
        XCTAssertEqual(spies.dismissCalls.value, 1)

        await store.send(.dismissAnimationCompleted)
        XCTAssertEqual(spies.dismissCalls.value, 1,
                       "Re-entrant .dismissAnimationCompleted must not fire overlay.dismiss again")
    }

    // MARK: - .settingsTapped: analytics-only side effect

    func test_settingsTapped_logsOverlayDismissedWithSettingsTapMethod() async {
        let clock = TestClock()
        let spies = makeSpies()
        let store = makeStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 15),
            clock: clock,
            spies: spies
        )

        await store.send(.settingsTapped)

        let events = spies.analytics.value
        XCTAssertEqual(events.count, 1)
        guard let event = events.first,
              case let .overlayDismissed(type, method, elapsedS) = event else {
            return XCTFail("Expected .overlayDismissed but got \(events)")
        }
        XCTAssertEqual(type, .eyes)
        XCTAssertEqual(method, .settingsTap,
                       "Settings-tap dismissal must use DismissMethod.settingsTap")
        XCTAssertEqual(elapsedS, 0, accuracy: 0.001)

        XCTAssertEqual(spies.dismissCalls.value, 0,
                       "settingsTapped does not itself dismiss the overlay")
    }

    func test_settingsTapped_afterTicks_reportsElapsedSeconds() async {
        let clock = TestClock()
        let spies = makeSpies()
        let store = makeStore(
            initialState: OverlayFeature.State(type: .posture, duration: 30),
            clock: clock,
            spies: spies
        )

        await store.send(.onAppear)
        for tick in 1...5 {
            await clock.advance(by: .seconds(1))
            await store.receive(\.timerTick) { $0.secondsRemaining = 30 - tick }
        }

        await store.send(.settingsTapped)
        // Cancel the still-running tick effect to let the test finish cleanly.
        await store.send(.dismissed)

        let dismissEvents = spies.analytics.value.compactMap { event -> TimeInterval? in
            if case let .overlayDismissed(_, method, elapsed) = event,
               method == .settingsTap {
                return elapsed
            }
            return nil
        }
        XCTAssertEqual(dismissEvents.count, 1)
        XCTAssertEqual(dismissEvents.first ?? -1, 5, accuracy: 0.001,
                       "settingsTapped must report elapsed = duration − secondsRemaining")
    }

    // MARK: - .timerExpired: auto-dismissal analytics + overlay.dismiss

    func test_timerExpired_logsOverlayAutoDismissedWithFullDuration() async {
        let clock = TestClock()
        let spies = makeSpies()
        let store = makeStore(
            initialState: OverlayFeature.State(type: .posture, duration: 25),
            clock: clock,
            spies: spies
        )

        await store.send(.timerExpired) { $0.isDismissing = true }
        await store.send(.dismissAnimationCompleted) { $0.isFinalized = true }
        await store.receive(\.dismissed)

        let events = spies.analytics.value
        XCTAssertEqual(events.count, 1)
        guard let event = events.first,
              case let .overlayAutoDismissed(type, durationS) = event else {
            return XCTFail("Expected .overlayAutoDismissed but got \(events)")
        }
        XCTAssertEqual(type, .posture)
        XCTAssertEqual(durationS, 25, accuracy: 0.001,
                       "Auto-dismissal analytics must report the full configured duration")
    }

    func test_timerExpired_callsOverlayClientDismissExactlyOnce() async {
        let clock = TestClock()
        let spies = makeSpies()
        let store = makeStore(
            initialState: OverlayFeature.State(type: .eyes, duration: 5),
            clock: clock,
            spies: spies
        )

        await store.send(.timerExpired) { $0.isDismissing = true }
        // Two-phase dismiss (#738): the side-effect doesn't fire until the
        // view (or this test) sends `.dismissAnimationCompleted`.
        XCTAssertEqual(spies.dismissCalls.value, 0,
                       "overlayClient.dismiss must not fire on timerExpired alone (two-phase dismiss)")
        await store.send(.dismissAnimationCompleted) { $0.isFinalized = true }
        await store.receive(\.dismissed)

        XCTAssertEqual(spies.dismissCalls.value, 1)
    }

    func test_timerExpired_whileAlreadyDismissing_emitsNoAnalyticsAndNoOverlayCall() async {
        let clock = TestClock()
        let spies = makeSpies()
        var initial = OverlayFeature.State(type: .eyes, duration: 5)
        initial.isDismissing = true
        let store = makeStore(initialState: initial, clock: clock, spies: spies)

        await store.send(.timerExpired)

        XCTAssertEqual(spies.analytics.value.count, 0,
                       "Re-entrant timerExpired must not double-log auto-dismissal")
        XCTAssertEqual(spies.dismissCalls.value, 0,
                       "Re-entrant timerExpired must not call overlay.dismiss again")
    }
}
