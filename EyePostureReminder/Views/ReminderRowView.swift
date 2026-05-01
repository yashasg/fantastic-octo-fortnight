import SwiftUI

struct ReminderRowView: View {

    let type: ReminderType
    @Binding var isEnabled: Bool
    @Binding var interval: TimeInterval
    @Binding var breakDuration: TimeInterval
    let onChanged: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let reduceMotionOverride: Bool?
    private let accessibilityNotificationPoster: AccessibilityNotificationPosting

    init(
        type: ReminderType,
        isEnabled: Binding<Bool>,
        interval: Binding<TimeInterval>,
        breakDuration: Binding<TimeInterval>,
        onChanged: @escaping () -> Void,
        reduceMotionOverride: Bool? = nil,
        accessibilityNotificationPoster: AccessibilityNotificationPosting = LiveAccessibilityNotificationPoster()
    ) {
        self.type = type
        _isEnabled = isEnabled
        _interval = interval
        _breakDuration = breakDuration
        self.onChanged = onChanged
        self.reduceMotionOverride = reduceMotionOverride
        self.accessibilityNotificationPoster = accessibilityNotificationPoster
    }

    var body: some View {
        Group {
            AccessibleToggle(
                isOn: $isEnabled,
                tint: type.color,
                accessibilityIdentifier: "settings.\(type.rawValue).toggle",
                accessibilityHint: Text(
                    isEnabled
                        ? String(
                            format: String(localized: "settings.reminder.toggle.enabled.hint", bundle: .module),
                            type.title)
                        : String(
                            format: String(localized: "settings.reminder.toggle.disabled.hint", bundle: .module),
                            type.title)
                ),
                onChange: { _ in onChanged() },
                label: {
                    Label(type.title, systemImage: type.symbolName)
                }
            )

            if isEnabled {
                Picker(String(localized: "settings.reminder.intervalPicker", bundle: .module), selection: $interval) {
                    ForEach(SettingsViewModel.intervalOptions, id: \.self) { seconds in
                        Text(formatInterval(seconds)).tag(seconds)
                    }
                }
                .onChange(of: interval) { _ in onChanged() }
                .accessibilityHint(
                    String(
                        format: String(localized: "settings.reminder.intervalPicker.hint", bundle: .module),
                        type.title
                    )
                )
                .accessibilityIdentifier("settings.\(type.rawValue).intervalPicker")

                Picker(
                    String(localized: "settings.reminder.durationPicker", bundle: .module),
                    selection: $breakDuration
                ) {
                    ForEach(SettingsViewModel.breakDurationOptions, id: \.self) { seconds in
                        Text(formatDuration(seconds)).tag(seconds)
                    }
                }
                .onChange(of: breakDuration) { _ in onChanged() }
                .accessibilityHint(
                    String(
                        format: String(localized: "settings.reminder.durationPicker.hint", bundle: .module),
                        type.title
                    )
                )
                .accessibilityIdentifier("settings.\(type.rawValue).durationPicker")
            }
        }
        .animation(shouldReduceMotion ? nil : AppAnimation.settingsExpandCurve, value: isEnabled)
        // Announce picker visibility change to VoiceOver when the reminder is toggled (#432).
        .onChange(of: isEnabled) { newValue in
            let message = newValue
                ? String(localized: "settings.reminder.pickers.visible.announcement", bundle: .module)
                : String(localized: "settings.reminder.pickers.hidden.announcement", bundle: .module)
            accessibilityNotificationPoster.postAnnouncement(message: message)
        }
    }

    // MARK: - Formatting

    private var shouldReduceMotion: Bool {
        reduceMotionOverride ?? reduceMotion
    }

    private func formatInterval(_ seconds: TimeInterval) -> String {
        SettingsViewModel.labelForInterval(seconds)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        SettingsViewModel.labelForBreakDuration(seconds)
    }
}
