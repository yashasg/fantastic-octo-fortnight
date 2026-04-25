import Foundation
@testable import EyePostureReminder

/// Mock implementation of `ReminderScheduling` for SettingsViewModel unit tests.
///
/// Records every call for assertion in tests. All async methods resolve immediately.
@MainActor
final class MockReminderScheduler: ReminderScheduling {

    // MARK: - Call Counts

    private(set) var scheduleRemindersCallCount = 0
    private(set) var rescheduleCallCount = 0
    private(set) var cancelReminderCallCount = 0
    private(set) var cancelAllCallCount = 0

    // MARK: - Call Arguments

    private(set) var lastScheduledSettings: SettingsStore?
    private(set) var lastRescheduledType: ReminderType?
    private(set) var cancelledTypes: [ReminderType] = []

    // MARK: - Reset

    func reset() {
        scheduleRemindersCallCount = 0
        rescheduleCallCount = 0
        cancelReminderCallCount = 0
        cancelAllCallCount = 0
        lastScheduledSettings = nil
        lastRescheduledType = nil
        cancelledTypes = []
    }

    // MARK: - ReminderScheduling

    func scheduleReminders(using settings: SettingsStore) async {
        scheduleRemindersCallCount += 1
        lastScheduledSettings = settings
    }

    func rescheduleReminder(for type: ReminderType, using settings: SettingsStore) async {
        rescheduleCallCount += 1
        lastRescheduledType = type
        lastScheduledSettings = settings
    }

    func cancelReminder(for type: ReminderType) {
        cancelReminderCallCount += 1
        cancelledTypes.append(type)
    }

    func cancelAllReminders() {
        cancelAllCallCount += 1
    }
}
