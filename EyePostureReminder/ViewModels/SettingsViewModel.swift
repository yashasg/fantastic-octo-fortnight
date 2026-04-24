import Foundation
import Combine
import os

/// Observable shell binding `SettingsStore` to Settings UI.
///
/// `SettingsViewModel` is the single point of contact between Views and the
/// persistence layer. Views bind to `@Published` properties here; the VM
/// translates user actions into `SettingsStore` mutations and triggers
/// scheduler reschedules as needed.
///
/// Injected dependencies default to production singletons to keep SwiftUI
/// preview and production wire-up minimal while keeping unit tests clean.
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Dependencies

    let settings: SettingsStore
    private let scheduler: ReminderScheduling

    // MARK: - Init

    init(
        settings: SettingsStore,
        scheduler: ReminderScheduling
    ) {
        self.settings  = settings
        self.scheduler = scheduler
        Logger.settings.debug("SettingsViewModel initialised")
    }

    // MARK: - User Actions

    /// Called when the master toggle is flipped.
    func masterToggleChanged() {
        Task {
            if settings.masterEnabled {
                await scheduler.scheduleReminders(using: settings)
            } else {
                scheduler.cancelAllReminders()
            }
            Logger.settings.info("Master toggle → \(self.settings.masterEnabled)")
        }
    }

    /// Called when per-type enabled state or interval/duration changes.
    func reminderSettingChanged(for type: ReminderType) {
        Task {
            await scheduler.rescheduleReminder(for: type, using: settings)
            Logger.settings.info("Settings updated for type=\(type.rawValue)")
        }
    }

    /// Apply a snooze: cancels all reminders and sets `snoozedUntil`.
    func snooze(for minutes: Int) {
        settings.snoozedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        scheduler.cancelAllReminders()
        Logger.settings.info("Snoozed for \(minutes) minutes")
    }

    /// Cancel an active snooze and reschedule reminders immediately.
    func cancelSnooze() {
        settings.snoozedUntil = nil
        Task {
            await scheduler.scheduleReminders(using: settings)
            Logger.settings.info("Snooze cancelled — reminders rescheduled")
        }
    }
}
