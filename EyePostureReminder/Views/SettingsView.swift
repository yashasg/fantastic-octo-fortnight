import SwiftUI
import UIKit

struct SettingsView: View {

    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: AppCoordinator

    // SettingsViewModel handles scheduling side-effects only.
    // Using @State is correct here because we only call action methods on it —
    // the view never observes any @Published properties from the VM itself.
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Form {
            // MARK: Master toggle
            Section {
                Toggle("Enable Reminders", isOn: $settings.masterEnabled)
                    .tint(AppColor.reminderBlue)
                    .onChange(of: settings.masterEnabled) { _ in
                        viewModel?.masterToggleChanged()
                    }
            } footer: {
                if !settings.masterEnabled {
                    Text("All reminders are paused.")
                        .font(AppFont.caption)
                }
            }

            // MARK: Per-type sections (only shown when master is on)
            if settings.masterEnabled {
                Section("Eyes — 20-20-20 Rule") {
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

            // MARK: Notification permission warning
            if coordinator.notificationAuthStatus == .denied {
                Section {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: AppSymbol.warning)
                            .foregroundStyle(AppColor.warningOrange)
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Notifications Disabled")
                                .font(AppFont.bodyEmphasized)
                            Text("Enable notifications in Settings to receive reminders in the background.")
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)

                    Button("Open System Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(AppFont.body)
                }
            }
        }
        .navigationTitle("Eye & Posture Reminder")
        .navigationBarTitleDisplayMode(.large)
        .animation(AppAnimation.settingsExpandCurve, value: settings.masterEnabled)
        .onAppear {
            if viewModel == nil {
                // Pass `coordinator` as `ReminderScheduling` so setting changes
                // route through the auth-aware coordinator paths (including
                // fallback-timer updates when notifications are denied).
                viewModel = SettingsViewModel(
                    settings: settings,
                    scheduler: coordinator
                )
            }
        }
        .task {
            await coordinator.refreshAuthStatus()
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
