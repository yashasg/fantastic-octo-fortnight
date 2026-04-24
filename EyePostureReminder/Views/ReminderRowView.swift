import SwiftUI

struct ReminderRowView: View {

    let type: ReminderType
    @Binding var isEnabled: Bool
    @Binding var interval: TimeInterval
    @Binding var breakDuration: TimeInterval
    let onChanged: () -> Void

    private let intervalOptions: [TimeInterval] = [10*60, 20*60, 30*60, 45*60, 60*60]
    private let durationOptions: [TimeInterval] = [10, 20, 30, 60]

    var body: some View {
        Toggle(isOn: $isEnabled) {
            Label(type.title, systemImage: type.symbolName)
        }
        .tint(type.color)
        .onChange(of: isEnabled) { _ in onChanged() }
        .accessibilityHint(isEnabled ? "Tap to disable \(type.title) reminders" : "Tap to enable \(type.title) reminders")

        if isEnabled {
            Picker("Remind me every", selection: $interval) {
                ForEach(intervalOptions, id: \.self) { seconds in
                    Text(formatInterval(seconds)).tag(seconds)
                }
            }
            .onChange(of: interval) { _ in onChanged() }
            .accessibilityHint("Sets how frequently \(type.title) reminders appear")

            Picker("Break duration", selection: $breakDuration) {
                ForEach(durationOptions, id: \.self) { seconds in
                    Text(formatDuration(seconds)).tag(seconds)
                }
            }
            .onChange(of: breakDuration) { _ in onChanged() }
            .accessibilityHint("Sets how long each \(type.title) break overlay stays on screen")
        }
    }

    // MARK: - Formatting

    private func formatInterval(_ seconds: TimeInterval) -> String {
        "\(Int(seconds) / 60) min"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return s < 60 ? "\(s) sec" : "\(s / 60) min"
    }
}
