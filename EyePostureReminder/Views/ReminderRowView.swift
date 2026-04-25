import SwiftUI

struct ReminderRowView: View {

    let type: ReminderType
    @Binding var isEnabled: Bool
    @Binding var interval: TimeInterval
    @Binding var breakDuration: TimeInterval
    let onChanged: () -> Void

    private let intervalOptions: [TimeInterval] = [10 * 60, 20 * 60, 30 * 60, 45 * 60, 60 * 60]
    private let durationOptions: [TimeInterval] = [10, 20, 30, 60]

    var body: some View {
        Toggle(isOn: $isEnabled) {
            Label(type.title, systemImage: type.symbolName)
        }
        .tint(type.color)
        .onChange(of: isEnabled) { _ in onChanged() }
        .accessibilityHint(
            isEnabled
                ? String(
                    format: String(localized: "settings.reminder.toggle.enabled.hint", bundle: .module),
                    type.title)
                : String(
                    format: String(localized: "settings.reminder.toggle.disabled.hint", bundle: .module),
                    type.title)
        )

        if isEnabled {
            Picker(String(localized: "settings.reminder.intervalPicker", bundle: .module), selection: $interval) {
                ForEach(intervalOptions, id: \.self) { seconds in
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

            Picker(String(localized: "settings.reminder.durationPicker", bundle: .module), selection: $breakDuration) {
                ForEach(durationOptions, id: \.self) { seconds in
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
        }
    }

    // MARK: - Formatting

    private func formatInterval(_ seconds: TimeInterval) -> String {
        "\(Int(seconds) / 60) min"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let secs = Int(seconds)
        return secs < 60 ? "\(secs) sec" : "\(secs / 60) min"
    }
}
