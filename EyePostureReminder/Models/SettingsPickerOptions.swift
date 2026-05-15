import Foundation

/// Preset values and human-readable labels for the reminder interval /
/// break-duration pickers rendered by `SettingsView`, `OnboardingSetupView`,
/// and `ReminderRowView`.
///
/// Extracted from the legacy `SettingsViewModel` as part of `#755` Phase B so
/// the SwiftUI surfaces can keep their picker rows after the view-model is
/// deleted. The values themselves are byte-identical to the MVVM-era
/// constants — analytics codes, accessibility labels, and persisted
/// UserDefaults values all keep their stable mapping.
enum SettingsPickerOptions {
    /// Available reminder interval presets, in seconds (1 / 10 / 20 / 30 / 45
    /// / 60 minutes).
    ///
    /// The 1-minute option is intentionally placed first for testing purposes
    /// only — it is not the default interval. Default interval is set in
    /// `SettingsStore`.
    static let intervalOptions: [TimeInterval] = [
        1 * 60,
        10 * 60,
        20 * 60,
        30 * 60,
        45 * 60,
        60 * 60
    ]

    /// Available break duration presets, in seconds (10 / 20 / 30 / 60).
    static let breakDurationOptions: [TimeInterval] = [10, 20, 30, 60]

    /// Human-readable label for an interval option (e.g. "20 min").
    static func labelForInterval(_ seconds: TimeInterval) -> String {
        String(
            format: String(localized: "settings.picker.minuteFormat", bundle: .module),
            Int(seconds) / 60
        )
    }

    /// Human-readable label for a break-duration option (e.g. "20 sec").
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
