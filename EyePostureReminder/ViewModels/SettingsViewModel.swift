import Foundation
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

    // MARK: - Snooze Options (M2.3)

    /// The three snooze durations available to the user via Settings.
    enum SnoozeOption: CaseIterable {
        case fiveMinutes
        case oneHour
        case restOfDay

        /// Human-readable label shown in the Settings UI.
        var label: String {
            switch self {
            case .fiveMinutes: return String(localized: "settings.snooze.5min", bundle: .module)
            case .oneHour:     return String(localized: "settings.snooze.1hour", bundle: .module)
            case .restOfDay:   return String(localized: "settings.snooze.restOfDay", bundle: .module)
            }
        }

        /// The absolute `Date` at which this snooze should expire.
        var endDate: Date {
            switch self {
            case .fiveMinutes:
                return Date().addingTimeInterval(5 * 60)
            case .oneHour:
                return Date().addingTimeInterval(60 * 60)
            case .restOfDay:
                // End of the current calendar day (midnight tonight).
                // `calendar.date(byAdding:)` never returns nil for valid inputs,
                // so no fallback is needed — a fallback of `+24h` would be wrong
                // on DST transition days (23 or 25 hours, not midnight).
                let calendar = Calendar.current
                return calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: calendar.startOfDay(for: Date())
                ) ?? {
                    // Unreachable in practice; guard against unexpected nil with a
                    // warning rather than silently computing the wrong end time.
                    Logger.settings.warning(
                        "SnoozeOption.restOfDay: calendar.date returned nil — falling back to DateComponents midnight"
                    )
                    var comps = calendar.dateComponents([.year, .month, .day], from: Date())
                    comps.day = (comps.day ?? 0) + 1
                    comps.hour = 0; comps.minute = 0; comps.second = 0
                    return calendar.date(from: comps) ?? Date().addingTimeInterval(86400)
                }()
            }
        }

        /// Duration in minutes (used by legacy `snooze(for:)` bridge).
        var minutes: Int {
            switch self {
            case .fiveMinutes: return 5
            case .oneHour:     return 60
            case .restOfDay:   return -1  // special: use endDate directly
            }
        }
    }

    /// Maximum number of consecutive snoozes allowed before a reminder must fire.
    /// Sourced from `AppConfig.features.maxSnoozeCount` at initialisation time.
    /// Note: captured once at init — changes to `defaults.json` between launches
    /// are not reflected until the ViewModel is re-created (next cold launch).
    /// This is acceptable in production; only observable in dev/test environments.
    let maxConsecutiveSnoozes: Int

    /// All available snooze options in display order.
    static let snoozeOptions: [SnoozeOption] = SnoozeOption.allCases

    // MARK: - Preset Options

    /// Available reminder interval options in seconds (1 / 10 / 20 / 30 / 45 / 60 minutes).
    ///
    /// The 1-minute option is intentionally placed first for testing purposes only —
    /// it is not the default interval. Default interval is set in `SettingsStore`.
    static let intervalOptions: [TimeInterval] = [
        1 * 60,
        10 * 60,
        20 * 60,
        30 * 60,
        45 * 60,
        60 * 60
    ]

    /// Available break duration options in seconds (10 / 20 / 30 / 60 seconds).
    static let breakDurationOptions: [TimeInterval] = [10, 20, 30, 60]

    // MARK: - Dependencies

    let settings: SettingsStore
    private let scheduler: ReminderScheduling

    // MARK: - Computed State (M2.3)

    /// `true` while a snooze is active (snoozedUntil is a future date).
    var isSnoozeActive: Bool {
        guard let until = settings.snoozedUntil else { return false }
        return until > Date()
    }

    /// `true` when the user is allowed to apply another snooze.
    /// Blocked once `maxConsecutiveSnoozes` consecutive snoozes have been used
    /// without a reminder actually firing.
    var canSnooze: Bool {
        settings.snoozeCount < maxConsecutiveSnoozes
    }

    var pauseDuringFocus: Bool {
        get { settings.pauseDuringFocus }
        set {
            let old = settings.pauseDuringFocus
            settings.pauseDuringFocus = newValue
            AnalyticsLogger.log(.settingChanged(
                setting: "pauseDuringFocus",
                oldValue: String(old),
                newValue: String(newValue)
            ))
        }
    }

    var pauseWhileDriving: Bool {
        get { settings.pauseWhileDriving }
        set {
            let old = settings.pauseWhileDriving
            settings.pauseWhileDriving = newValue
            AnalyticsLogger.log(.settingChanged(
                setting: "pauseWhileDriving",
                oldValue: String(old),
                newValue: String(newValue)
            ))
        }
    }

    // MARK: - Init

    init(
        settings: SettingsStore,
        scheduler: ReminderScheduling,
        maxSnoozeCount: Int = AppConfig.load().features.maxSnoozeCount
    ) {
        self.settings  = settings
        self.scheduler = scheduler
        self.maxConsecutiveSnoozes = maxSnoozeCount
        Logger.settings.debug("SettingsViewModel initialised")
    }

    // MARK: - User Actions

    /// Called when the master toggle is flipped.
    func globalToggleChanged() {
        Task {
            if settings.globalEnabled {
                await scheduler.scheduleReminders(using: settings)
            } else {
                scheduler.cancelAllReminders()
            }
            Logger.settings.info("Master toggle → \(self.settings.globalEnabled)")
        }
    }

    /// Called when per-type enabled state or interval/duration changes.
    func reminderSettingChanged(for type: ReminderType) {
        Task {
            await scheduler.rescheduleReminder(for: type, using: settings)
            Logger.settings.info("Settings updated for type=\(type.rawValue)")
        }
    }

    // MARK: - Snooze Actions (M2.3)

    /// Apply a snooze using one of the predefined `SnoozeOption` cases.
    ///
    /// Enforces the consecutive snooze limit (`maxConsecutiveSnoozes`). When
    /// the scheduler is `AppCoordinator`, `cancelAllReminders()` arms the
    /// in-process wake task automatically.
    func snooze(option: SnoozeOption) {
        guard canSnooze else {
            Logger.settings.info("Snooze limit reached — ignoring snooze request")
            return
        }
        let endDate = option.endDate
        guard endDate > Date() else {
            // Guard against clock skew or NTP drift producing a past end date;
            // applying a past snoozedUntil would be cleared immediately by
            // scheduleReminders() making snooze appear broken.
            Logger.settings.warning("snooze(option:) computed end date is in the past — ignoring")
            return
        }
        settings.snoozedUntil = endDate
        settings.snoozeCount += 1
        scheduler.cancelAllReminders()
        AnalyticsLogger.log(.snoozeActivated(durationOption: option.label))
        Logger.settings.info("Snoozed until \(endDate) via option: \(option.label) (count: \(self.settings.snoozeCount))")
    }

    /// Apply a snooze for an arbitrary number of minutes.
    ///
    /// Legacy bridge — no production callers remain after `snooze(option:)` was
    /// introduced. Retained for test compatibility only; new code should use
    /// `snooze(option:)`.
    @available(*, deprecated, renamed: "snooze(option:)")
    func snooze(for minutes: Int) {
        guard canSnooze else {
            Logger.settings.info("Snooze limit reached — ignoring snooze request")
            return
        }
        settings.snoozedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        settings.snoozeCount += 1
        scheduler.cancelAllReminders()
        AnalyticsLogger.log(.snoozeActivated(durationOption: "\(minutes)m"))
        Logger.settings.info("Snoozed for \(minutes) minutes (count: \(self.settings.snoozeCount))")
    }

    /// Cancel an active snooze and reschedule reminders immediately.
    func cancelSnooze() {
        settings.snoozedUntil = nil
        settings.snoozeCount  = 0
        AnalyticsLogger.log(.snoozeCancelled)
        Task {
            await scheduler.scheduleReminders(using: settings)
            Logger.settings.info("Snooze cancelled — reminders rescheduled")
        }
    }

    // MARK: - Formatting Helpers

    /// Human-readable label for an interval option (e.g. "20 min").
    static func labelForInterval(_ seconds: TimeInterval) -> String {
        String(
            format: String(localized: "settings.picker.minuteFormat", bundle: .module),
            Int(seconds) / 60
        )
    }

    /// Human-readable label for a break duration option (e.g. "20 sec").
    static func labelForBreakDuration(_ seconds: TimeInterval) -> String {
        let secs = Int(seconds)
        if secs < 60 {
            return String(
                format: String(localized: "settings.picker.secondFormat", bundle: .module),
                secs
            )
        } else {
            return String(
                format: String(localized: "settings.picker.minuteFormat", bundle: .module),
                secs / 60
            )
        }
    }
}
