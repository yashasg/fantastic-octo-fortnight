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

    // MARK: - Preset Options

    /// Available reminder interval options in seconds (10 / 20 / 30 / 45 / 60 minutes).
    static let intervalOptions: [TimeInterval] = [
        10 * 60,
        20 * 60,
        30 * 60,
        45 * 60,
        60 * 60,
    ]

    /// Available break duration options in seconds (10 / 20 / 30 / 60 seconds).
    static let breakDurationOptions: [TimeInterval] = [10, 20, 30, 60]

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

    // MARK: - Formatting Helpers

    /// Human-readable label for an interval option (e.g. "20 min").
    static func labelForInterval(_ seconds: TimeInterval) -> String {
        "\(Int(seconds) / 60) min"
    }

    /// Human-readable label for a break duration option (e.g. "20 sec").
    static func labelForBreakDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return s < 60 ? "\(s) sec" : "\(s / 60) min"
    }
}
