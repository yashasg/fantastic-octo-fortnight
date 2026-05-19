import ComposableArchitecture
import ScreenTimeExtensionShared
import UserNotifications
import XCTest

@testable import EyePostureReminder

/// Watchdog-recovery TestStore coverage for `SchedulingFeature` —
/// Phase 3 issue `p0-tca-17` (#680) + Phase 2 watchdog-recovery
/// follow-up (#892).
///
/// Watchdog recovery reads the App Group IPC log via
/// `IPCClient.recentEvents`, detects a stale heartbeat using the live
/// `@Dependency(\.date)` clock, cancels every reminder, and restarts the
/// schedule. The `.watchdogRecoveryTriggered` action delegates the verdict
/// to `WatchdogHeartbeat.status(...)` so the behaviour stays in lock-step
/// with the legacy `WatchdogHeartbeat` parity contract (see
/// `Tests/EyePostureReminderTests/Services/WatchdogHeartbeatTests.swift`).
///
/// Two additional in-scope analogues are exercised below: the
/// `ipcStream` true-interrupt subscriber, which fires `.scheduleReminders`
/// on every emitted change, and the `pauseStream` subscriber, which routes
/// every emitted `Bool` to `.pauseConditionChanged`. They are kept here as
/// belt-and-braces coverage of the related external-signal-driven
/// reschedule rails.
@MainActor
final class SchedulingFeatureWatchdogRecoveryTests: XCTestCase {

    // MARK: - .watchdogRecoveryTriggered — stale heartbeat

    /// A stale device-activity-lifecycle heartbeat (older than the
    /// 130 s threshold) must trigger the recovery branch: cancel every
    /// reminder, restart the schedule, record an IPC
    /// `watchdogRecoveryTriggered` event, and emit the
    /// `watchdogRecoveryTriggered` + `watchdogRecoveryCompleted`
    /// analytics pair. Legacy parity vector mirrors
    /// `WatchdogHeartbeatTests.test_status_whenLatestHeartbeatExceedsThreshold_returnsStale`.
    func test_watchdogRecoveryTriggered_staleHeartbeat_cancelsAndReschedules() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let staleHeartbeat = WatchdogHeartbeat.event(
            .deviceActivityIntervalEnded,
            timestamp: now.addingTimeInterval(-200)
        )
        let cancelledAll = LockIsolated(0)
        let recordedEvents = LockIsolated<[AppGroupIPCEvent]>([])
        let recordedContexts = LockIsolated<[String?]>([])
        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.date = .constant(now)
            $0.ipcClient = IPCClient(
                isTrueInterruptEnabled: { false },
                setTrueInterruptEnabled: { _ in false },
                readSelection: { .empty },
                writeSelection: { _ in false },
                record: { event, context in
                    recordedEvents.withValue { $0.append(event) }
                    recordedContexts.withValue { $0.append(context) }
                },
                trueInterruptChanges: { .finished },
                selectionChanges: { .finished },
                recentEvents: { [staleHeartbeat] },
                fallbackRoute: { _ in nil }
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { _, _ in },
                cancelReminder: { _ in },
                cancelAllReminders: { cancelledAll.withValue { $0 += 1 } }
            )
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
        }
        store.exhaustivity = .off

        await store.send(.watchdogRecoveryTriggered)
        await store.receive(\.scheduleReminders)
        await store.finish()

        XCTAssertEqual(
            cancelledAll.value, 1,
            "Stale heartbeat must invoke schedulerClient.cancelAllReminders exactly once"
        )
        XCTAssertEqual(
            recordedEvents.value.map(\.kind), [.watchdogRecoveryTriggered],
            "Stale heartbeat must persist an IPC watchdogRecoveryTriggered event"
        )
        XCTAssertEqual(
            recordedEvents.value.first?.detail, "device_activity_interval_ended",
            "Recovery event detail must carry the staleness heartbeat detail"
        )
        XCTAssertEqual(
            recordedEvents.value.first?.timestamp, now,
            "Recovery event timestamp must use the deterministic clock"
        )
        XCTAssertEqual(
            recordedContexts.value, ["watchdog_recovery"],
            "Recovery event must carry the watchdog_recovery context tag"
        )
        XCTAssertTrue(
            analyticsEvents.value.contains(where: { event in
                if case .watchdogRecoveryTriggered(nil, "device_activity_interval_ended") = event {
                    return true
                }
                return false
            }),
            "Analytics must include watchdogRecoveryTriggered with the staleness detail"
        )
        XCTAssertTrue(
            analyticsEvents.value.contains(where: { event in
                if case .watchdogRecoveryCompleted(true, false) = event {
                    return true
                }
                return false
            }),
            "Analytics must include watchdogRecoveryCompleted after recovery finishes"
        )
    }

    // MARK: - .watchdogRecoveryTriggered — missing heartbeat

    /// A `recentEvents` log that contains no watchdog heartbeats must
    /// classify as `.missing` and trigger the recovery branch. Legacy
    /// parity vector mirrors
    /// `WatchdogHeartbeatTests.test_status_whenNoHeartbeat_returnsMissing`.
    func test_watchdogRecoveryTriggered_missingHeartbeat_triggersRecovery() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cancelledAll = LockIsolated(0)
        let recordedEvents = LockIsolated<[AppGroupIPCEvent]>([])
        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.date = .constant(now)
            $0.ipcClient = IPCClient(
                isTrueInterruptEnabled: { false },
                setTrueInterruptEnabled: { _ in false },
                readSelection: { .empty },
                writeSelection: { _ in false },
                record: { event, _ in recordedEvents.withValue { $0.append(event) } },
                trueInterruptChanges: { .finished },
                selectionChanges: { .finished },
                recentEvents: { [] },
                fallbackRoute: { _ in nil }
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { _, _ in },
                cancelReminder: { _ in },
                cancelAllReminders: { cancelledAll.withValue { $0 += 1 } }
            )
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
        }
        store.exhaustivity = .off

        await store.send(.watchdogRecoveryTriggered)
        await store.receive(\.scheduleReminders)
        await store.finish()

        XCTAssertEqual(cancelledAll.value, 1)
        XCTAssertEqual(recordedEvents.value.first?.detail, "missing")
        XCTAssertTrue(
            analyticsEvents.value.contains(where: { event in
                if case .watchdogRecoveryTriggered(nil, "missing") = event {
                    return true
                }
                return false
            })
        )
    }

    // MARK: - .watchdogRecoveryTriggered — fresh heartbeat is a no-op

    /// A fresh device-activity-lifecycle heartbeat (within the 130 s
    /// threshold) must classify as `.fresh` and must NOT trigger
    /// recovery — the action is idempotent under fresh sessions. Legacy
    /// parity vector mirrors
    /// `WatchdogHeartbeatTests.test_status_whenLatestHeartbeatWithinThreshold_returnsFresh`.
    func test_watchdogRecoveryTriggered_freshHeartbeat_isNoOp() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let freshHeartbeat = WatchdogHeartbeat.event(
            .deviceActivityIntervalStarted,
            timestamp: now.addingTimeInterval(-30)
        )
        let cancelledAll = LockIsolated(0)
        let recordedEvents = LockIsolated<[AppGroupIPCEvent]>([])
        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.date = .constant(now)
            $0.ipcClient = IPCClient(
                isTrueInterruptEnabled: { false },
                setTrueInterruptEnabled: { _ in false },
                readSelection: { .empty },
                writeSelection: { _ in false },
                record: { event, _ in recordedEvents.withValue { $0.append(event) } },
                trueInterruptChanges: { .finished },
                selectionChanges: { .finished },
                recentEvents: { [freshHeartbeat] },
                fallbackRoute: { _ in nil }
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { _, _ in },
                cancelReminder: { _ in },
                cancelAllReminders: { cancelledAll.withValue { $0 += 1 } }
            )
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
        }
        store.exhaustivity = .off

        await store.send(.watchdogRecoveryTriggered)
        await store.finish()

        XCTAssertEqual(
            cancelledAll.value, 0,
            "Fresh heartbeat must not cancel reminders"
        )
        XCTAssertTrue(
            recordedEvents.value.isEmpty,
            "Fresh heartbeat must not record an IPC recovery event"
        )
        XCTAssertTrue(
            analyticsEvents.value.isEmpty,
            "Fresh heartbeat must not emit any analytics events"
        )
    }

    // MARK: - .watchdogRecoveryTriggered — coordinator heartbeat ignored

    /// A coordinator-side heartbeat (`appForeground`) must NOT be
    /// counted against the device-activity-lifecycle staleness window.
    /// If only coordinator heartbeats are present, the verdict must be
    /// `.missing` and recovery must fire. Legacy parity vector mirrors
    /// `WatchdogHeartbeatTests.test_status_matchingDeviceActivityDetails_ignoresNewerCoordinatorHeartbeat`.
    func test_watchdogRecoveryTriggered_ignoresCoordinatorHeartbeats() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let coordinatorHeartbeat = WatchdogHeartbeat.event(
            .appForeground,
            timestamp: now.addingTimeInterval(-5)
        )
        let cancelledAll = LockIsolated(0)
        let recordedEvents = LockIsolated<[AppGroupIPCEvent]>([])

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.date = .constant(now)
            $0.ipcClient = IPCClient(
                isTrueInterruptEnabled: { false },
                setTrueInterruptEnabled: { _ in false },
                readSelection: { .empty },
                writeSelection: { _ in false },
                record: { event, _ in recordedEvents.withValue { $0.append(event) } },
                trueInterruptChanges: { .finished },
                selectionChanges: { .finished },
                recentEvents: { [coordinatorHeartbeat] },
                fallbackRoute: { _ in nil }
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { _, _ in },
                cancelReminder: { _ in },
                cancelAllReminders: { cancelledAll.withValue { $0 += 1 } }
            )
        }
        store.exhaustivity = .off

        await store.send(.watchdogRecoveryTriggered)
        await store.receive(\.scheduleReminders)
        await store.finish()

        XCTAssertEqual(
            cancelledAll.value, 1,
            "Coordinator-only heartbeats must not mask a missing device-activity heartbeat"
        )
        XCTAssertEqual(recordedEvents.value.first?.detail, "missing")
    }

    // MARK: - IPC stream → reschedule (closest in-scope analogue)

    /// `startEffect()` installs an `ipcStream` subscriber that fires
    /// `.scheduleReminders` on every emitted true-interrupt change. This is
    /// the closest currently-implemented analogue to a watchdog-driven
    /// "external signal forces a reschedule" path. Verifies the contract by
    /// driving the stream from the test body and asserting the resulting
    /// `.scheduleReminders` action.
    func test_ipcStream_trueInterruptChange_triggersScheduleReminders() async {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.ipcClient = IPCClient(
                isTrueInterruptEnabled: { false },
                setTrueInterruptEnabled: { _ in false },
                readSelection: { .empty },
                writeSelection: { _ in false },
                record: { _, _ in },
                trueInterruptChanges: { stream },
                selectionChanges: { .finished },
                recentEvents: { [] },
                fallbackRoute: { _ in nil }
            )
        }
        store.exhaustivity = .off

        await store.send(.start)

        continuation.yield(true)
        await store.receive(\.scheduleReminders)

        // Tear down the long-lived streams so `store.finish()` doesn't trip.
        continuation.finish()
        await store.send(.stop)
    }

    // MARK: - Pause stream → pauseConditionChanged (closest in-scope analogue)

    /// `startEffect()` also installs a `pauseStream` subscriber that maps
    /// every emitted `Bool` onto `.pauseConditionChanged`. This is the
    /// in-scope analogue to the "external resume / pause condition forces
    /// a state transition" guard rail. Verifies the routing by yielding
    /// from the test body.
    func test_pauseStream_pauseConditionChange_routesToReducer() async {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let pausedAll = LockIsolated(0)

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.pauseConditionClient = PauseConditionClient(
                isPaused: { false },
                pauseChanges: { stream },
                startMonitoring: {},
                stopMonitoring: {}
            )
            $0.screenTimeTrackerClient = ScreenTimeTrackerClient(
                setThreshold: { _, _ in },
                enableTracking: { _ in },
                disableTracking: { _ in },
                pauseAll: { pausedAll.withValue { $0 += 1 } },
                resumeAll: {},
                reset: { _ in },
                thresholdReached: { .finished }
            )
            $0.overlayClient = OverlayClient(
                lifecycleEvents: { .finished },
                broadcast: { _ in },
                pauseExternalAudio: {},
                resumeExternalAudio: {},
                postScreenChanged: {}
            )
        }
        store.exhaustivity = .off

        await store.send(.start)

        continuation.yield(true)
        await store.receive(\.pauseConditionChanged) {
            $0.isPausedByConditions = true
        }

        continuation.finish()
        await store.send(.stop)

        XCTAssertEqual(pausedAll.value, 1,
                       "pauseConditionChanged(true) must call trackerClient.pauseAll")
    }
}
