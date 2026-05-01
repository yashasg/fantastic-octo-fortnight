import os
import ScreenTimeExtensionShared
import UserNotifications

// MARK: - Fallback Timer Shims and Private Helpers

extension AppCoordinator {

    /// Configure the `ScreenTimeTracker` with current settings and start counting.
    ///
    /// Retained for call-site compatibility. The "fallback timer" concept is
    /// superseded by `ScreenTimeTracker` which handles both notification-authorized
    /// and notification-denied paths uniformly.
    func startFallbackTimers() {
        configureScreenTimeTracker()
    }

    /// Stop the `ScreenTimeTracker` and reset all elapsed counters.
    ///
    /// Retained for call-site compatibility (e.g., test `tearDown`).
    func stopFallbackTimers() {
        screenTimeTracker.stopMonitoring()
        pauseConditionManager.stopMonitoring()
    }

    // MARK: - Snooze Wake

    /// Schedule an in-process `Task` that wakes and resumes reminders when the
    /// snooze period expires. Safe to call multiple times — cancels the previous task first.
    func scheduleSnoozeWakeTask(at date: Date) {
        snoozeWakeTask?.cancel()
        snoozeWakeTask = Task { [weak self] in
            let interval = max(0, date.timeIntervalSinceNow)
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.handleSnoozeWake()
        }
        // swiftlint:disable:next line_length
        Logger.scheduling.debug("Snooze wake task armed; fires in \(date.timeIntervalSinceNow, format: .fixed(precision: 0), privacy: .public)s")
    }

    /// Cancel the in-process snooze wake task without removing the pending
    /// notification. Called by `AppDelegate` when the snooze-wake notification
    /// is delivered while the app is in the foreground, so the task and the
    /// notification delivery path don't both call `handleSnoozeWake()` and
    /// double-fire `.snoozeExpired` analytics + double-reschedule.
    func cancelSnoozeWakeTaskIfNeeded() {
        snoozeWakeTask?.cancel()
        snoozeWakeTask = nil
    }

    /// Cancel both the in-process wake task and the one-time wake notification.
    func cancelSnoozeWake() {
        snoozeWakeTask?.cancel()
        snoozeWakeTask = nil
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [Self.snoozeWakeCategory]
        )
    }

    /// Schedule a silent one-time UNNotification that fires when the snooze
    /// period expires. Wakes the app even if it was killed and relaunched.
    func scheduleSnoozeWakeNotification(at date: Date) async {
        let interval = max(1, date.timeIntervalSinceNow)

        let content = UNMutableNotificationContent()
        // Truly silent wake notification — no banner, no sound, no badge.
        // iOS 15+ .passive level suppresses lock-screen display and sound entirely.
        content.title              = ""
        content.body               = ""
        content.sound              = nil
        content.badge              = nil
        if #available(iOS 15, *) {
            content.interruptionLevel = .passive
        }
        content.categoryIdentifier = Self.snoozeWakeCategory

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.snoozeWakeCategory,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            Logger.scheduling.debug("Snooze wake notification scheduled in \(interval)s")
        } catch {
            // swiftlint:disable:next line_length
            Logger.scheduling.error("Failed to schedule snooze wake notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Called when the snooze period expires (either via Task or notification tap).
    /// Clears snooze state and resumes normal scheduling.
    private func handleSnoozeWake() async {
        settings.snoozedUntil = nil
        settings.snoozeCount  = 0
        AnalyticsLogger.log(.snoozeExpired)
        await scheduleReminders()
        Logger.scheduling.info("Snooze wake — reminders resumed")
    }

    // MARK: - Private

    func showBreakOverlay(for type: ReminderType, duration: TimeInterval) {
        let presentationID = UUID()
        overlayManager.showOverlay(
            for: type,
            duration: duration,
            hapticsEnabled: settings.hapticsEnabled,
            pauseMediaEnabled: settings.pauseMediaDuringBreaks,
            callbacks: OverlayLifecycleCallbacks(
                onPresent: { [weak self] in
                    self?.scheduleDeviceActivityMonitoring(
                        for: type,
                        duration: duration,
                        presentationID: presentationID
                    )
                },
                onDismiss: { [weak self] in
                    self?.cancelDeviceActivityMonitoring(presentationID: presentationID)
                }
            )
        )
    }

    private func scheduleDeviceActivityMonitoring(
        for type: ReminderType,
        duration: TimeInterval,
        presentationID: UUID
    ) {
        guard shouldUseShieldPath else { return }
        enqueueDeviceActivityMonitorOperation(
            .schedule(ShieldSession(type: type, durationSeconds: duration), presentationID: presentationID)
        )
    }

    func cancelDeviceActivityMonitoring(presentationID: UUID? = nil) {
        guard deviceActivityMonitor.isAvailable else { return }
        if let presentationID {
            dismissedDeviceActivityPresentationIDs.insert(presentationID)
        }
        enqueueDeviceActivityMonitorOperation(.cancel(presentationID: presentationID))
    }

    private func enqueueDeviceActivityMonitorOperation(_ operation: DeviceActivityMonitorOperation) {
        let previousTask = deviceActivityMonitorTask
        deviceActivityMonitorTask = Task { @MainActor [weak self, previousTask, operation] in
            _ = await previousTask?.result
            guard let self, !Task.isCancelled else { return }

            do {
                switch operation {
                case .schedule(let session, _):
                    try await deviceActivityMonitor.scheduleBreakMonitoring(for: session)
                    recordIPCEvent(
                        .shieldStarted,
                        reasonRaw: session.reason.rawValue,
                        detail: "device_activity_monitor_scheduled"
                    )
                    AnalyticsLogger.log(.shieldActivated(reason: session.reason))
                    Logger.scheduling.info(
                        "DeviceActivity monitoring scheduled for \(session.reason.rawValue)"
                    )
                case .cancel:
                    try await deviceActivityMonitor.cancelBreakMonitoring()
                    recordIPCEvent(.shieldEnded, detail: "device_activity_monitor_cancelled")
                    AnalyticsLogger.log(.shieldDeactivated)
                    Logger.scheduling.info("DeviceActivity monitoring cancelled")
                }
            } catch {
                if case .schedule(let session, let presentationID) = operation,
                   notificationAuthStatus == .authorized,
                   settings.notificationFallbackEnabled,
                   let fallbackType = session.reason.reminderType {
                    AnalyticsLogger.log(.shieldActivationFailed(reason: session.reason))
                    if dismissedDeviceActivityPresentationIDs.remove(presentationID) != nil {
                        recordIPCEvent(
                            .notificationFallbackSuppressed,
                            reasonRaw: session.reason.rawValue,
                            detail: "device_activity_schedule_failed_overlay_dismissed"
                        )
                    } else if overlayManager.isOverlayVisible {
                        recordIPCEvent(
                            .notificationFallbackSuppressed,
                            reasonRaw: session.reason.rawValue,
                            detail: "device_activity_schedule_failed_overlay_visible"
                        )
                    } else {
                        await scheduler.rescheduleReminder(for: fallbackType, using: settings)
                        recordIPCEvent(
                            .notificationFallbackScheduled,
                            reasonRaw: session.reason.rawValue,
                            detail: "device_activity_schedule_failed"
                        )
                    }
                }
                Logger.scheduling.error(
                    // swiftlint:disable:next line_length
                    "DeviceActivity monitor \(operation.logDescription, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
                )
            }
            if case .cancel(let presentationID?) = operation {
                dismissedDeviceActivityPresentationIDs.remove(presentationID)
            }
        }
    }

    /// Update the ScreenTimeTracker threshold and background notification for a
    /// single type after the debounce window has elapsed.
    func performReschedule(for type: ReminderType) async {
        // #74: Skip tracker restart when snooze is active — settings changes
        // during a snooze must not override the explicit pauseAll() applied at snooze start.
        guard (settings.snoozedUntil ?? .distantPast) <= Date() else {
            Logger.scheduling.debug("performReschedule skipped — snooze still active")
            return
        }
        await refreshAuthStatus()

        if settings.isEnabled(for: type) {
            let interval = settings.settings(for: type).interval
            screenTimeTracker.setThreshold(interval, for: type)
            screenTimeTracker.startMonitoring()
            if notificationAuthStatus == .authorized, shouldScheduleNotificationFallback {
                await scheduler.rescheduleReminder(for: type, using: settings)
            } else {
                scheduler.cancelReminder(for: type)
            }
            Logger.scheduling.info("Rescheduled \(type.rawValue): screen-time threshold → \(interval)s")
        } else {
            screenTimeTracker.disableTracking(for: type)
            scheduler.cancelReminder(for: type)
            Logger.scheduling.info("Rescheduled \(type.rawValue): disabled, tracking cleared")
        }
    }

    /// Configure all `ScreenTimeTracker` thresholds from current settings
    /// and start counting if the app is active.
    ///
    /// Called from `scheduleReminders()` after the snooze guard clears.
    /// Only calls `resumeAll()` if no pause condition is currently active —
    /// preserves the invariant that PauseConditionManager and snooze are
    /// independent pause axes.
    func configureScreenTimeTracker() {
        for type in ReminderType.allCases {
            if settings.isEnabled(for: type) {
                let interval = settings.settings(for: type).interval
                screenTimeTracker.setThreshold(interval, for: type)
            } else {
                screenTimeTracker.disableTracking(for: type)
            }
        }
        guard !pauseConditionManager.isPaused else {
            Logger.scheduling.debug("configureScreenTimeTracker: pause condition active — skipping resumeAll")
            return
        }
        screenTimeTracker.resumeAll()
        screenTimeTracker.startMonitoring()
    }

    var shouldScheduleNotificationFallback: Bool {
        settings.notificationFallbackEnabled &&
            hasEnabledReminder &&
            (!deviceActivityMonitor.isAvailable || !isTrueInterruptEnabled || !hasTrueInterruptSelection)
    }

    private var shouldUseShieldPath: Bool {
        deviceActivityMonitor.isAvailable &&
            isTrueInterruptEnabled &&
            hasTrueInterruptSelection &&
            hasEnabledReminder
    }

    /// Maps `UNAuthorizationStatus` to a non-PII analytics code.
    func notificationAuthCode(from status: UNAuthorizationStatus) -> AnalyticsEvent.NotificationAuthCode {
        switch status {
        case .authorized:    return .authorized
        case .denied:        return .denied
        case .notDetermined: return .notDetermined
        case .provisional:   return .provisional
        case .ephemeral:     return .ephemeral
        @unknown default:    return .unknown
        }
    }

    /// Returns the IPC detail string and analytics reason for the current fallback routing state.
    ///
    /// Evaluate once and capture **before** any `await` — IPC state may change across a
    /// suspension point. Combining both outputs avoids evaluating the same guard chain twice.
    func fallbackRoutingContext() -> (detail: String, analyticsReason: AnalyticsEvent.SchedulePathReason) {
        guard deviceActivityMonitor.isAvailable else {
            return ("shield_unavailable", .shieldUnavailable)
        }
        guard isTrueInterruptEnabled else {
            return ("true_interrupt_disabled", .trueInterruptDisabled)
        }
        guard hasTrueInterruptSelection else {
            return ("true_interrupt_empty_selection", .trueInterruptEmptySelection)
        }
        // Defensive path: shield routing became available between the
        // `shouldScheduleNotificationFallback` check and this evaluation.
        Logger.scheduling.error("fallbackRoutingContext: shield routing available — IPC state may have changed")
        return ("unexpected_shield_routing_state", .unexpectedShieldRoutingState)
    }

    private var isTrueInterruptEnabled: Bool {
        ipcStore.isTrueInterruptEnabled()
    }

    private var hasTrueInterruptSelection: Bool {
        do {
            let selection = try ipcStore.readSelection()
            if selection.isEmpty {
                Logger.scheduling.debug("True Interrupt disabled because no apps or categories are selected")
                return false
            }
            return true
        } catch {
            Logger.scheduling.error(
                "True Interrupt selection unavailable: \(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    private var hasEnabledReminder: Bool {
        ReminderType.allCases.contains { settings.isEnabled(for: $0) }
    }

    func recordIPCEvent(
        _ kind: AppGroupIPCEventKind,
        reasonRaw: String? = nil,
        detail: String? = nil
    ) {
        do {
            try ipcStore.recordEvent(AppGroupIPCEvent(kind: kind, reasonRaw: reasonRaw, detail: detail))
        } catch {
            Logger.scheduling.error("App Group IPC event write failed: \(error.localizedDescription, privacy: .public)")
            AnalyticsLogger.log(.ipcOperationFailed(operation: .writeEvent, reason: .writeFailed))
        }
    }

    func recordWatchdogHeartbeat(_ detail: WatchdogHeartbeatDetail) {
        do {
            try WatchdogHeartbeat.record(detail, using: ipcStore)
        } catch {
            // swiftlint:disable:next line_length
            Logger.scheduling.error("App Group watchdog heartbeat write failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
