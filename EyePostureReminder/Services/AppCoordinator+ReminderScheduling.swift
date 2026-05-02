import Foundation
import ScreenTimeExtensionShared

// MARK: - ReminderScheduling Conformance

/// `AppCoordinator` conforms to `ReminderScheduling` so `SettingsViewModel`
/// can treat it as its scheduler. Every method routes through the
/// auth-aware coordinator paths, keeping fallback timers in sync when
/// notifications are denied.
extension AppCoordinator: ReminderScheduling {

    func scheduleReminders(using settings: SettingsStore) async {
        // Delegate to the coordinator's full auth-aware entrypoint.
        await scheduleReminders()
    }

    func rescheduleReminder(for type: ReminderType, using settings: SettingsStore) async {
        // Debounced, auth-aware single-type reschedule.
        await reschedule(for: type)
    }

    func cancelReminder(for type: ReminderType) {
        scheduler.cancelReminder(for: type)
        screenTimeTracker.disableTracking(for: type)
        overlayManager.clearQueue(for: type)
        if pendingOverlay?.type == type { pendingOverlay = nil }
        // Cancel DeviceActivity monitoring when an active shield session for this type is live,
        // so a stuck-shield cannot outlast a cancelled reminder. Avoid cancelling unrelated sessions.
        // Use do/catch instead of try? so a read failure is logged and does not silently leave
        // an active ScreenTime shield stuck. Fixes #490.
        if deviceActivityMonitor.isAvailable {
            do {
                let session = try ipcStore.readShieldSession()
                if session.reason?.reminderType == type {
                    cancelDeviceActivityMonitoring()
                }
            } catch {
                Logger.scheduling.error(
                    "cancelReminder(\(type.rawValue, privacy: .public)): failed to read shield session — DeviceActivity monitor may remain active: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    func cancelAllReminders() {
        scheduler.cancelAllReminders()
        screenTimeTracker.pauseAll()
        overlayManager.clearQueue()
        if overlayManager.isOverlayVisible {
            overlayManager.dismissOverlay()
        }
        pendingOverlay = nil

        cancelDeviceActivityMonitoring()

        // If snooze was just applied (snoozedUntil set before this call),
        // arm the in-process wake task immediately so the app resumes on time
        // while staying in the foreground throughout the snooze period.
        // #73: Also schedule the silent background notification so a backgrounded
        // app can wake even if the in-process task is killed by the OS.
        if let snoozeEnd = settings.snoozedUntil, snoozeEnd > Date() {
            scheduleSnoozeWakeTask(at: snoozeEnd)
            if notificationAuthStatus == .authorized {
                Task { [weak self] in await self?.scheduleSnoozeWakeNotification(at: snoozeEnd) }
            }
        }
    }
}
