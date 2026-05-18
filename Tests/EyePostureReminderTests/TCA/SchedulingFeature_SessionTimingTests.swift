import ComposableArchitecture
import Foundation
import XCTest

@testable import EyePostureReminder

/// `TestStore` coverage for #901 — `SchedulingFeature.overlayLifecycleEvent`
/// must dispatch `SessionTimingClient.sessionStarted` on `.presented(_:)`
/// and `SessionTimingClient.sessionEnded` on `.dismissed(_:)` keyed by the
/// emitting `ReminderType`, using the `@Dependency(\.date)` clock for the
/// wall-clock timestamp so test runs stay deterministic.
///
/// Each test installs a recording `SessionTimingClient` plus a fixed
/// `Date` dependency, sends `.overlayLifecycleEvent(_:)` directly (skipping
/// the upstream subscription wired by #904, which has its own coverage in
/// `OverlayLifecycleSubscriptionTests`) and asserts the recorded calls.
@MainActor
final class SessionTimingTests: XCTestCase {

    /// `.presented(.eyes)` must dispatch exactly one
    /// `sessionStarted(.eyes, <now>)` call and no `sessionEnded` calls.
    func test_overlayLifecycleEvent_presentedEyes_dispatchesSessionStarted() async {
        let recorder = SessionTimingRecorder()
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.sessionTimingClient = recorder.client()
            $0.date = .constant(fixedNow)
        }

        await store.send(.overlayLifecycleEvent(.presented(.eyes)))
        await store.finish()

        let started = await recorder.startedCalls
        let ended = await recorder.endedCalls
        XCTAssertEqual(started.count, 1)
        XCTAssertEqual(started.first?.0, .eyes)
        XCTAssertEqual(started.first?.1, fixedNow)
        XCTAssertTrue(ended.isEmpty)
    }

    /// `.dismissed(.posture)` must dispatch exactly one
    /// `sessionEnded(.posture, <now>)` call and no `sessionStarted` calls.
    func test_overlayLifecycleEvent_dismissedPosture_dispatchesSessionEnded() async {
        let recorder = SessionTimingRecorder()
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_100)

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.sessionTimingClient = recorder.client()
            $0.date = .constant(fixedNow)
        }

        await store.send(.overlayLifecycleEvent(.dismissed(.posture)))
        await store.finish()

        let started = await recorder.startedCalls
        let ended = await recorder.endedCalls
        XCTAssertTrue(started.isEmpty)
        XCTAssertEqual(ended.count, 1)
        XCTAssertEqual(ended.first?.0, .posture)
        XCTAssertEqual(ended.first?.1, fixedNow)
    }

    /// A full present → dismiss cycle must produce a matching
    /// started + ended pair keyed by the same `ReminderType`. Also
    /// validates the two calls land in order so downstream consumers can
    /// safely assume `started` precedes `ended` per cycle.
    func test_overlayLifecycleEvent_presentThenDismiss_pairsCallsByType() async {
        let recorder = SessionTimingRecorder()
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_200)

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.sessionTimingClient = recorder.client()
            $0.date = .constant(fixedNow)
        }

        await store.send(.overlayLifecycleEvent(.presented(.eyes)))
        await store.send(.overlayLifecycleEvent(.dismissed(.eyes)))
        await store.finish()

        let started = await recorder.startedCalls
        let ended = await recorder.endedCalls
        XCTAssertEqual(started.map(\.0), [.eyes])
        XCTAssertEqual(ended.map(\.0), [.eyes])
        XCTAssertEqual(started.first?.1, fixedNow)
        XCTAssertEqual(ended.first?.1, fixedNow)
    }

    /// `.settingsTapped(_:)` must NOT touch the timing client — it is
    /// owned by a future sibling tracker. Sending it on its own must keep
    /// both recorder buckets empty.
    func test_overlayLifecycleEvent_settingsTapped_doesNotDispatchTiming() async {
        let recorder = SessionTimingRecorder()

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.sessionTimingClient = recorder.client()
        }

        await store.send(.overlayLifecycleEvent(.settingsTapped(.eyes)))
        await store.send(.overlayLifecycleEvent(.settingsTapped(.posture)))
        await store.finish()

        let started = await recorder.startedCalls
        let ended = await recorder.endedCalls
        XCTAssertTrue(started.isEmpty)
        XCTAssertTrue(ended.isEmpty)
    }
}

/// Actor-isolated call recorder for `SessionTimingClient` so async closures
/// can append concurrently without data races. Returns a client whose
/// `sessionStarted` / `sessionEnded` closures forward every call into the
/// actor for later assertion.
private actor SessionTimingRecorder {
    private(set) var startedCalls: [(ReminderType, Date)] = []
    private(set) var endedCalls: [(ReminderType, Date)] = []

    func appendStarted(_ type: ReminderType, _ date: Date) {
        startedCalls.append((type, date))
    }

    func appendEnded(_ type: ReminderType, _ date: Date) {
        endedCalls.append((type, date))
    }

    nonisolated func client() -> SessionTimingClient {
        SessionTimingClient(
            sessionStarted: { type, date in
                await self.appendStarted(type, date)
            },
            sessionEnded: { type, date in
                await self.appendEnded(type, date)
            }
        )
    }
}
