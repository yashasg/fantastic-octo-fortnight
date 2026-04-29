import Foundation
import os
import UserNotifications

// MARK: - NotificationScheduling Protocol

/// Abstracts `UNUserNotificationCenter` so scheduling logic can be tested
/// without firing real system notifications. Production code passes
/// `UNUserNotificationCenter.current()`; tests inject a mock.
protocol NotificationScheduling {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeAllPendingNotificationRequests()
    func getPendingNotificationRequests() async -> [UNNotificationRequest]
    /// Returns the current notification authorization status without triggering a prompt.
    func getAuthorizationStatus() async -> UNAuthorizationStatus
}

// Production conformance — zero overhead, zero extra code at the call site.
extension UNUserNotificationCenter: NotificationScheduling {
    func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        await pendingNotificationRequests()
    }

    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

// MARK: - ReminderScheduling Protocol

/// Contract for the component that owns reminder scheduling lifecycle.
///
/// Callers provide a `SettingsStore` snapshot; the scheduler is responsible
/// for translating settings into `UNNotificationRequest` objects and managing
/// the notification identifier namespace.
@MainActor
protocol ReminderScheduling: AnyObject {
    /// Schedule (or reschedule) all enabled reminders based on current settings.
    func scheduleReminders(using settings: SettingsStore) async

    /// Reschedule a single reminder type — e.g. after the user changes its interval.
    func rescheduleReminder(for type: ReminderType, using settings: SettingsStore) async

    /// Cancel all pending reminders of the given type.
    func cancelReminder(for type: ReminderType)

    /// Cancel all pending reminders unconditionally (e.g. master toggle off).
    func cancelAllReminders()
}

// MARK: - ReminderScheduler

/// Concrete implementation of `ReminderScheduling`.
///
/// Depends on `NotificationScheduling` (injected) for all system calls.
/// All `async` methods must be called from a `Task` or `async` context.
@MainActor
final class ReminderScheduler: ReminderScheduling {

    // MARK: - Notification Identifier Namespace

    private enum NotificationID {
        static func identifier(for type: ReminderType) -> String {
            "com.yashasg.eyeposturereminder.\(type.rawValue)"
        }
    }

    // MARK: - Dependencies

    private let notificationCenter: NotificationScheduling

    init(notificationCenter: NotificationScheduling = UNUserNotificationCenter.current()) {
        self.notificationCenter = notificationCenter
    }

    // MARK: - ReminderScheduling

    // MARK: Scheduling — production + test paths
    //
    // `scheduleReminders(using:)` and `rescheduleReminder(for:using:)` are called
    // by `AppCoordinator.scheduleReminders()` and `performReschedule(for:)` when
    // notification permission is `.authorized`, and are also exercised by unit tests.
    // `AppCoordinator`'s `ReminderScheduling` conformance routes calls through its
    // own auth-aware paths before delegating here.

    func scheduleReminders(using settings: SettingsStore) async {
        Logger.scheduling.info("Scheduling all reminders")
        for type in ReminderType.allCases {
            await rescheduleReminder(for: type, using: settings)
        }
    }

    func rescheduleReminder(for type: ReminderType, using settings: SettingsStore) async {
        cancelReminder(for: type)

        guard settings.isEnabled(for: type) else {
            Logger.scheduling.info("Skipping \(type.rawValue) — disabled")
            return
        }

        let reminderSettings = settings.settings(for: type)
        let identifier = NotificationID.identifier(for: type)

        let content = UNMutableNotificationContent()
        content.title              = type.notificationTitle
        content.body               = type.notificationBody
        content.sound              = .default
        content.categoryIdentifier = type.categoryIdentifier

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: reminderSettings.interval,
            repeats: reminderSettings.interval >= 60
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            Logger.scheduling.info("Scheduled \(type.rawValue) every \(reminderSettings.interval)s")
        } catch {
            Logger.scheduling.error("Failed to schedule \(type.rawValue): \(error.localizedDescription)")
        }
    }

    func cancelReminder(for type: ReminderType) {
        let identifier = NotificationID.identifier(for: type)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        Logger.scheduling.debug("Cancelled reminder: \(type.rawValue)")
    }

    func cancelAllReminders() {
        notificationCenter.removeAllPendingNotificationRequests()
        Logger.scheduling.info("Cancelled all reminders")
    }
}
