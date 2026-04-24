import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: AppCoordinator

    // SettingsViewModel handles scheduling side-effects only.
    // Using @State is correct here because we only call action methods on it —
    // the view never observes any @Published properties from the VM itself.
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Form {
            Section {
                Toggle("Enable Reminders", isOn: $settings.masterEnabled)
                    .onChange(of: settings.masterEnabled) { _ in
                        viewModel?.masterToggleChanged()
                    }
            }

            if settings.masterEnabled {
                Section("Eyes (20-20-20 Rule)") {
                    ReminderRowView(
                        type: .eyes,
                        isEnabled: $settings.eyesEnabled,
                        interval: $settings.eyesInterval,
                        breakDuration: $settings.eyesBreakDuration,
                        onChanged: { viewModel?.reminderSettingChanged(for: .eyes) }
                    )
                }

                Section("Posture") {
                    ReminderRowView(
                        type: .posture,
                        isEnabled: $settings.postureEnabled,
                        interval: $settings.postureInterval,
                        breakDuration: $settings.postureBreakDuration,
                        onChanged: { viewModel?.reminderSettingChanged(for: .posture) }
                    )
                }
            }
        }
        .navigationTitle("Eye & Posture Reminder")
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(
                    settings: settings,
                    scheduler: coordinator.scheduler
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SettingsStore())
            .environmentObject(AppCoordinator())
    }
}
