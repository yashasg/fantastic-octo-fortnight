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
    /// 20-20-20 rule defaults driven by `AppConfig` (reads `defaults.json`).
    /// `static let` ensures `AppConfig.load()` is called at most once.
    static let defaultEyes: ReminderSettings = {
        let config = AppConfig.load()
        return ReminderSettings(interval: config.defaults.eyeInterval, breakDuration: config.defaults.eyeBreakDuration)
    }()

    /// Posture check defaults driven by `AppConfig` (reads `defaults.json`).
    /// `static let` ensures `AppConfig.load()` is called at most once.
    static let defaultPosture: ReminderSettings = {
        let config = AppConfig.load()
        return ReminderSettings(
            interval: config.defaults.postureInterval,
            breakDuration: config.defaults.postureBreakDuration
        )
    }()
}
