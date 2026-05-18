import ComposableArchitecture
import ScreenTimeExtensionShared
import UserNotifications
import XCTest

@testable import EyePostureReminder

/// `TestStore` parity coverage for `SchedulingFeature`'s notification
/// routing + threshold-reached paths — Phase 3 issue `p0-tca-17` (#680).
/// Covers the `.notificationRouted` and `.thresholdReached` branches of
/// the reducer (history: ported in `#755` Phase E, PR #760).
@MainActor
final class SchedulingNotificationRoutingTests: XCTestCase {

    // MARK: - .notificationRouted(.reminder(.eyes))

    /// `.notificationRouted(.reminder(.eyes))` fires the notification-fallback
    /// pipeline: clears the snooze counter, records an IPC fallback event,
    /// emits `.reminderTriggered(.notificationFallback)`, presents the
    /// overlay, and resets the in-app tracker so it doesn't double-fire.
    /// Eyes branch of `.notificationRouted` (#755 Phase E).
    func test_notificationRouted_reminderEyes_runsFallbackPipeline() async {
        let setSnoozeCounts = LockIsolated<[Int]>([])
        let recordedEvents = LockIsolated<[AppGroupIPCEvent]>([])
        let loggedEvents = LockIsolated<[String]>([])
        let shownOverlays = LockIsolated<[(ReminderType, TimeInterval)]>([])
        let resetTypes = LockIsolated<[ReminderType]>([])

        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(interval: 1200, breakDuration: 20)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            var settings = TCATestDependencies.silentSettingsClient()
            settings.setSnoozeCount = { value in
                setSnoozeCounts.withValue { $0.append(value) }
            }
            $0.settingsClient = settings
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
            $0.overlayClient = OverlayClient(
                show: { type, duration, _, _ in
                    shownOverlays.withValue { $0.append((type, duration)) }
                },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { .finished }
            )
            $0.screenTimeTrackerClient = ScreenTimeTrackerClient(
                setThreshold: { _, _ in },
                enableTracking: { _ in },
                disableTracking: { _ in },
                pauseAll: {},
                resumeAll: {},
                reset: { type in resetTypes.withValue { $0.append(type) } },
                thresholdReached: { .finished }
            )
            $0.analyticsClient = AnalyticsClient(log: { event in
                loggedEvents.withValue { $0.append(String(describing: event)) }
            })
        }

        await store.send(.notificationRouted(.reminder(.eyes)))
        await store.finish()

        XCTAssertEqual(setSnoozeCounts.value, [0],
                       "Reminder notification must reset the snooze counter")
        XCTAssertEqual(recordedEvents.value.count, 1)
        XCTAssertEqual(recordedEvents.value.first?.kind,
                       .notificationFallbackDelivered,
                       "Reminder notification must record a fallback-delivered IPC event")
        XCTAssertEqual(recordedEvents.value.first?.reasonRaw,
                       ReminderType.eyes.shieldReason.rawValue)
        XCTAssertEqual(shownOverlays.value.count, 1)
        XCTAssertEqual(shownOverlays.value.first?.0, .eyes)
        XCTAssertEqual(shownOverlays.value.first?.1, 20)
        XCTAssertEqual(resetTypes.value, [.eyes],
                       "Reminder notification must reset the in-app tracker for that type")
        XCTAssertTrue(loggedEvents.value.contains(where: {
            $0.contains("reminderTriggered") && $0.contains("notificationFallback")
        }))
    }

    // MARK: - .notificationRouted while snoozed

    /// While a snooze is active, an arriving reminder notification must be
    /// ignored — snooze-guard branch of `.notificationRouted`
    /// (#755 Phase E).
    func test_notificationRouted_reminderDuringActiveSnooze_isNoOp() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let recordedEvents = LockIsolated<[AppGroupIPCEvent]>([])
        let shownOverlays = LockIsolated<[ReminderType]>([])

        var initial = SchedulingFeature.State()
        initial.snoozedUntil = now.addingTimeInterval(60 * 60)
        initial.settings = ReminderSettings(interval: 1200, breakDuration: 20)

        let store = TestStore(initialState: initial) {
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
            $0.overlayClient = OverlayClient(
                show: { type, _, _, _ in shownOverlays.withValue { $0.append(type) } },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { .finished }
            )
        }

        await store.send(.notificationRouted(.reminder(.posture)))
        await store.finish()

        XCTAssertTrue(recordedEvents.value.isEmpty,
                      "Snoozed notification path must not record IPC events")
        XCTAssertTrue(shownOverlays.value.isEmpty,
                      "Snoozed notification path must not show overlay")
    }

    // MARK: - .notificationRouted(.snoozeWake)

    /// `.snoozeWake` clears the snooze state and re-runs scheduling —
    /// snooze-wake branch of `.notificationRouted` (#755 Phase E).
    func test_notificationRouted_snoozeWake_clearsAndReschedules() async {
        var initial = SchedulingFeature.State()
        initial.snoozedUntil = Date(timeIntervalSince1970: 1_700_000_000)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
        }

        await store.send(.notificationRouted(.snoozeWake)) {
            $0.snoozedUntil = nil
        }
        await store.receive(\.scheduleReminders)
        await store.receive(.internalAction(.authStatusRefreshed(.notDetermined)))
        await store.receive(.internalAction(.cancelSnoozeWake))
        await store.finish()
    }

    // MARK: - .notificationRouted(.ignore)

    /// `.ignore` is the catch-all routing for unknown / system notification
    /// categories — must be a pure no-op.
    func test_notificationRouted_ignore_isNoOp() async {
        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
        }

        await store.send(.notificationRouted(.ignore))
        await store.finish()
    }

    // MARK: - .thresholdReached — disabled type

    /// When `state.settings.interval == 0` the type is treated as disabled
    /// (Phase-1 SettingsClient single-value caveat) and `.thresholdReached`
    /// must short-circuit via the 300 ms disable-debounce guard
    /// (#755 Phase E).
    func test_thresholdReached_intervalZero_isNoOp() async {
        let shownOverlays = LockIsolated<[ReminderType]>([])
        let loggedEvents = LockIsolated<[String]>([])

        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(interval: 0, breakDuration: 20)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.overlayClient = OverlayClient(
                show: { type, _, _, _ in shownOverlays.withValue { $0.append(type) } },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { .finished }
            )
            $0.analyticsClient = AnalyticsClient(log: { event in
                loggedEvents.withValue { $0.append(String(describing: event)) }
            })
        }

        await store.send(.thresholdReached(.eyes))
        await store.finish()

        XCTAssertTrue(shownOverlays.value.isEmpty)
        XCTAssertTrue(loggedEvents.value.isEmpty)
    }

    // MARK: - .thresholdReached — enabled + authorized

    /// `.thresholdReached(.eyes)` while authorized must show the overlay,
    /// log `.reminderTriggered(.screenTimeThreshold)`, reset the snooze
    /// counter, and reschedule the next reminder for that type.
    func test_thresholdReached_enabledAuthorized_showsOverlayAndReschedules() async {
        let setSnoozeCounts = LockIsolated<[Int]>([])
        let shownOverlays = LockIsolated<[(ReminderType, TimeInterval)]>([])
        let loggedEvents = LockIsolated<[String]>([])
        let rescheduledTypes = LockIsolated<[ReminderType]>([])

        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(interval: 1200, breakDuration: 20)
        initial.notificationAuthStatus = .authorized

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            var settings = TCATestDependencies.silentSettingsClient()
            settings.setSnoozeCount = { value in
                setSnoozeCounts.withValue { $0.append(value) }
            }
            $0.settingsClient = settings
            $0.overlayClient = OverlayClient(
                show: { type, duration, _, _ in
                    shownOverlays.withValue { $0.append((type, duration)) }
                },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { .finished }
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { type, _ in
                    rescheduledTypes.withValue { $0.append(type) }
                },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
            $0.analyticsClient = AnalyticsClient(log: { event in
                loggedEvents.withValue { $0.append(String(describing: event)) }
            })
        }

        await store.send(.thresholdReached(.eyes))
        await store.finish()

        XCTAssertEqual(setSnoozeCounts.value, [0])
        XCTAssertEqual(shownOverlays.value.count, 1)
        XCTAssertEqual(shownOverlays.value.first?.0, .eyes)
        XCTAssertEqual(shownOverlays.value.first?.1, 20)
        XCTAssertEqual(rescheduledTypes.value, [.eyes])
        XCTAssertTrue(loggedEvents.value.contains(where: {
            $0.contains("reminderTriggered") && $0.contains("screenTimeThreshold")
        }))
    }

    // MARK: - .thresholdReached — enabled, unauthorized

    /// When notifications are denied the foreground threshold path still
    /// presents the overlay (threshold-callback branch, #755 Phase E) but
    /// the reducer must not call `scheduler.rescheduleReminder` because
    /// there is no notification queue to reschedule into.
    func test_thresholdReached_enabledUnauthorized_showsOverlayButSkipsReschedule() async {
        let shownOverlays = LockIsolated<[ReminderType]>([])
        let rescheduledTypes = LockIsolated<[ReminderType]>([])

        var initial = SchedulingFeature.State()
        // The test sends `.thresholdReached(.posture)`, so seed the
        // posture-side snapshot (#897) — the reducer reads
        // `state.settings(for: .posture)` for the interval guard and
        // `overlayClient.show` payload.
        initial.postureSettings = ReminderSettings(interval: 1200, breakDuration: 20)
        initial.notificationAuthStatus = .denied

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.overlayClient = OverlayClient(
                show: { type, _, _, _ in shownOverlays.withValue { $0.append(type) } },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { .finished }
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { type, _ in
                    rescheduledTypes.withValue { $0.append(type) }
                },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
        }

        await store.send(.thresholdReached(.posture))
        await store.finish()

        XCTAssertEqual(shownOverlays.value, [.posture])
        XCTAssertTrue(rescheduledTypes.value.isEmpty,
                      "Denied auth must skip scheduler.rescheduleReminder")
    }

    // MARK: - .overlayDismissed

    /// `.overlayDismissed` cancels every active DeviceActivity monitoring
    /// window so a dismissed break stops accruing shield time
    /// (#755 Phase E).
    func test_overlayDismissed_cancelsAllDeviceActivitySessions() async {
        let cancelArgs = LockIsolated<[UUID?]>([])

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.deviceActivityMonitorClient = DeviceActivityMonitorClient(
                schedule: { _, _ in },
                cancel: { id in cancelArgs.withValue { $0.append(id) } }
            )
        }

        await store.send(.overlayDismissed(.eyes))
        await store.finish()

        XCTAssertEqual(cancelArgs.value.count, 1)
        XCTAssertNil(cancelArgs.value.first ?? UUID(),
                     "overlayDismissed must call cancel(nil) — every session, not just one")
    }
}
