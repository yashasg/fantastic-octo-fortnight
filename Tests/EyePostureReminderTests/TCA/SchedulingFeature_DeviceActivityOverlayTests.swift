import ComposableArchitecture
import Foundation
import XCTest

@testable import EyePostureReminder

/// `TestStore` coverage for #903 — `SchedulingFeature.overlayLifecycleEvent`
/// must dispatch `DeviceActivityMonitorClient.startScheduleForOverlay(_:)`
/// on `.presented(_:)` and the existing `cancel(_:)` accessor on
/// `.dismissed(_:)`, keyed by the emitting `ReminderType`. The
/// `.settingsTapped(_:)` variant must not touch the DeviceActivity surface.
///
/// Each test installs a recording `DeviceActivityMonitorClient` and sends
/// `.overlayLifecycleEvent(_:)` directly (skipping the upstream
/// subscription wired by #904, which has its own coverage in
/// `OverlayLifecycleSubscriptionTests`). The `SessionTimingClient` call
/// pair on the same handler is asserted by `SessionTimingTests` so this
/// file stays focused on the DeviceActivity contract.
@MainActor
final class DeviceActivityOverlayTests: XCTestCase {

    /// `.presented(.eyes)` must dispatch exactly one
    /// `startScheduleForOverlay(.eyes)` call and no `cancel` calls.
    func test_overlayLifecycleEvent_presentedEyes_startsDeviceActivityForOverlay() async {
        let recorder = DeviceActivityRecorder()

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.deviceActivityMonitorClient = recorder.client()
        }

        await store.send(.overlayLifecycleEvent(.presented(.eyes)))
        await store.finish()

        let started = await recorder.startedCalls
        let cancelled = await recorder.cancelCalls
        XCTAssertEqual(started, [.eyes])
        XCTAssertTrue(cancelled.isEmpty)
    }

    /// `.presented(.posture)` must dispatch exactly one
    /// `startScheduleForOverlay(.posture)` call, confirming the reducer
    /// passes the emitting `ReminderType` through verbatim rather than
    /// collapsing every variant to a single type.
    func test_overlayLifecycleEvent_presentedPosture_startsDeviceActivityForOverlay() async {
        let recorder = DeviceActivityRecorder()

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.deviceActivityMonitorClient = recorder.client()
        }

        await store.send(.overlayLifecycleEvent(.presented(.posture)))
        await store.finish()

        let started = await recorder.startedCalls
        let cancelled = await recorder.cancelCalls
        XCTAssertEqual(started, [.posture])
        XCTAssertTrue(cancelled.isEmpty)
    }

    /// `.dismissed(_:)` must dispatch exactly one `cancel(nil)` call —
    /// matching the existing `.overlayDismissed` semantic of cancelling
    /// every active session — and must not call `startScheduleForOverlay`.
    func test_overlayLifecycleEvent_dismissed_cancelsAllActiveSessions() async {
        let recorder = DeviceActivityRecorder()

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.deviceActivityMonitorClient = recorder.client()
        }

        await store.send(.overlayLifecycleEvent(.dismissed(.eyes)))
        await store.finish()

        let started = await recorder.startedCalls
        let cancelled = await recorder.cancelCalls
        XCTAssertTrue(started.isEmpty)
        XCTAssertEqual(cancelled.count, 1)
        XCTAssertNil(cancelled.first ?? UUID(),
                     ".dismissed must call cancel(nil) — every session, matching the .overlayDismissed semantic")
    }

    /// A full present → dismiss cycle must produce a matching
    /// `startScheduleForOverlay` + `cancel` pair, in order, so consumers
    /// can rely on the start preceding the cancel per cycle.
    func test_overlayLifecycleEvent_presentThenDismiss_pairsStartThenCancel() async {
        let recorder = DeviceActivityRecorder()

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.deviceActivityMonitorClient = recorder.client()
        }

        await store.send(.overlayLifecycleEvent(.presented(.eyes)))
        await store.send(.overlayLifecycleEvent(.dismissed(.eyes)))
        await store.finish()

        let started = await recorder.startedCalls
        let cancelled = await recorder.cancelCalls
        XCTAssertEqual(started, [.eyes])
        XCTAssertEqual(cancelled.count, 1)
        XCTAssertNil(cancelled.first ?? UUID())
    }

    /// `.settingsTapped(_:)` must NOT touch the DeviceActivity client —
    /// the start / cancel hooks are reserved for the present / dismiss
    /// transitions. Sending it on its own must keep both recorder
    /// buckets empty.
    func test_overlayLifecycleEvent_settingsTapped_doesNotDispatchDeviceActivity() async {
        let recorder = DeviceActivityRecorder()

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.deviceActivityMonitorClient = recorder.client()
        }

        await store.send(.overlayLifecycleEvent(.settingsTapped(.eyes)))
        await store.send(.overlayLifecycleEvent(.settingsTapped(.posture)))
        await store.finish()

        let started = await recorder.startedCalls
        let cancelled = await recorder.cancelCalls
        XCTAssertTrue(started.isEmpty)
        XCTAssertTrue(cancelled.isEmpty)
    }
}

/// Actor-isolated call recorder for `DeviceActivityMonitorClient` so async
/// closures can append concurrently without data races. Returns a client
/// whose `startScheduleForOverlay` / `cancel` closures forward every call
/// into the actor for later assertion. `schedule` is left as a silent
/// no-op since this suite asserts only the overlay-lifecycle wiring.
private actor DeviceActivityRecorder {
    private(set) var startedCalls: [ReminderType] = []
    private(set) var cancelCalls: [UUID?] = []

    func appendStarted(_ type: ReminderType) {
        startedCalls.append(type)
    }

    func appendCancel(_ id: UUID?) {
        cancelCalls.append(id)
    }

    nonisolated func client() -> DeviceActivityMonitorClient {
        DeviceActivityMonitorClient(
            schedule: { _, _ in },
            cancel: { id in
                await self.appendCancel(id)
            },
            startScheduleForOverlay: { type in
                await self.appendStarted(type)
            }
        )
    }
}
