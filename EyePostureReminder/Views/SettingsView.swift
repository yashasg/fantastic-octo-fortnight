import SwiftUI

struct SettingsView: View {

    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            Section {
                Toggle("Enable Reminders", isOn: viewModel.settings.$masterEnabled)
                    .onChange(of: viewModel.settings.masterEnabled) { _ in
                        viewModel.masterToggleChanged()
                    }
            }

            if viewModel.settings.masterEnabled {
                Section("Eyes (20-20-20 Rule)") {
                    ReminderRowView(
                        type: .eyes,
                        isEnabled: viewModel.settings.$eyesEnabled,
                        interval: viewModel.settings.$eyesInterval,
                        breakDuration: viewModel.settings.$eyesBreakDuration,
                        onChanged: { viewModel.reminderSettingChanged(for: .eyes) }
                    )
                }

                Section("Posture") {
                    ReminderRowView(
                        type: .posture,
                        isEnabled: viewModel.settings.$postureEnabled,
                        interval: viewModel.settings.$postureInterval,
                        breakDuration: viewModel.settings.$postureBreakDuration,
                        onChanged: { viewModel.reminderSettingChanged(for: .posture) }
                    )
                }
            }
        }
        .navigationTitle("Eye & Posture Reminder")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
