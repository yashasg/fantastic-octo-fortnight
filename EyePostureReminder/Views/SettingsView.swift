import SwiftUI
import UIKit

struct SettingsView: View {

    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: AppCoordinator

    // SettingsViewModel handles scheduling side-effects only.
    // Using @State is correct here because we only call action methods on it —
    // the view never observes any @Published properties from the VM itself.
    @State private var viewModel: SettingsViewModel?

    // MARK: - Snooze helpers

    private var isSnoozed: Bool {
        guard let until = settings.snoozedUntil else { return false }
        return until > Date()
    }

    private var snoozeUntilFormatted: String {
        guard let until = settings.snoozedUntil, until > Date() else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: until)
    }

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

            // MARK: Snooze
            Section("Snooze") {
                if isSnoozed {
                    HStack {
                        Label("Snoozed until \(snoozeUntilFormatted)", systemImage: "moon.zzz.fill")
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.warningOrange)
                        Spacer()
                    }
                    Button(role: .destructive) {
                        viewModel?.cancelSnooze()
                    } label: {
                        Label("Cancel Snooze", systemImage: "bell.fill")
                            .font(AppFont.body)
                    }
                } else {
                    Button("5 minutes") {
                        viewModel?.snooze(for: 5)
                    }
                    .font(AppFont.body)

                    Button("1 hour") {
                        viewModel?.snooze(for: 60)
                    }
                    .font(AppFont.body)

                    Button("Rest of day") {
                        let endOfDay = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 3600)
                        let minutesLeft = max(1, Int(endOfDay.timeIntervalSince(Date()) / 60))
                        viewModel?.snooze(for: minutesLeft)
                    }
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.warningOrange)
                }
            }

            // MARK: Preferences
            Section("Preferences") {
                Toggle("Haptic Feedback", isOn: $settings.hapticsEnabled)
                    .tint(AppColor.reminderBlue)
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
        .animation(AppAnimation.settingsExpandCurve, value: isSnoozed)
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
