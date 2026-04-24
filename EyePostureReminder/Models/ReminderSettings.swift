import Foundation

/// Immutable value type holding the schedule parameters for a single reminder type.
///
/// Both `interval` and `breakDuration` are expressed in seconds so they map
/// directly onto `TimeInterval` arithmetic in `ReminderScheduler`.
struct ReminderSettings: Equatable {
    /// Time between reminders (seconds). e.g. 1200 = every 20 minutes.
    let interval: TimeInterval

    /// How long the break overlay is shown (seconds). e.g. 20 = 20-second eye break.
    let breakDuration: TimeInterval
}

// MARK: - Defaults

extension ReminderSettings {
    /// 20-20-20 rule: every 20 minutes, look away for 20 seconds.
    static let defaultEyes = ReminderSettings(interval: 1200, breakDuration: 20)

    /// Posture check every 30 minutes, 15-second awareness pause.
    static let defaultPosture = ReminderSettings(interval: 1800, breakDuration: 15)
}
