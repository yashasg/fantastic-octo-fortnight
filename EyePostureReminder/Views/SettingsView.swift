import SwiftUI
import UIKit

struct SettingsView: View {

    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: AppCoordinator

    // SettingsViewModel handles scheduling side-effects only.
    // Using @State is correct here because we only call action methods on it —
    // the view never observes any @Published properties from the VM itself.
    @State private var viewModel: SettingsViewModel?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                Toggle(isOn: $settings.globalEnabled) {
                    Text("settings.masterToggle", bundle: .module)
                }
                    .tint(AppColor.reminderBlue)
                    .onChange(of: settings.globalEnabled) { _ in
                        viewModel?.globalToggleChanged()
                    }
                    .accessibilityHint(Text("settings.masterToggle.hint", bundle: .module))
            } footer: {
                if settings.globalEnabled {
                    Text("settings.masterToggle.footer", bundle: .module)
                        .font(AppFont.caption)
                } else {
                    Text("settings.pausedBanner", bundle: .module)
                        .font(AppFont.caption)
                }
            }

            // MARK: Per-type sections (only shown when master is on)
            if settings.globalEnabled {
                Section {
                    ReminderRowView(
                        type: .eyes,
                        isEnabled: $settings.eyesEnabled,
                        interval: $settings.eyesInterval,
                        breakDuration: $settings.eyesBreakDuration,
                        onChanged: { viewModel?.reminderSettingChanged(for: .eyes) }
                    )
                } header: {
                    Text("settings.section.eyes", bundle: .module)
                } footer: {
                    if settings.eyesEnabled {
                        Text("settings.reminder.section.footer", bundle: .module)
                            .font(AppFont.caption)
                    }
                }

                Section {
                    ReminderRowView(
                        type: .posture,
                        isEnabled: $settings.postureEnabled,
                        interval: $settings.postureInterval,
                        breakDuration: $settings.postureBreakDuration,
                        onChanged: { viewModel?.reminderSettingChanged(for: .posture) }
                    )
                } header: {
                    Text("settings.section.posture", bundle: .module)
                } footer: {
                    if settings.postureEnabled {
                        Text("settings.reminder.section.footer", bundle: .module)
                            .font(AppFont.caption)
                    }
                }
            }

            // MARK: Snooze
            Section {
                if isSnoozed {
                    HStack {
                        Label(String(format: String(localized: "settings.snooze.activeLabel", bundle: .module), snoozeUntilFormatted), systemImage: "moon.zzz.fill")
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.warningText)
                        Spacer()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(format: String(localized: "settings.snooze.activeLabel.accessibility", bundle: .module), snoozeUntilFormatted))

                    Button(role: .destructive) {
                        viewModel?.cancelSnooze()
                    } label: {
                        Label(title: { Text("settings.snooze.cancelButton", bundle: .module) }, icon: { Image(systemName: "bell.fill") })
                            .font(AppFont.body)
                    }
                    .accessibilityHint(Text("settings.snooze.cancelButton.hint", bundle: .module))
                } else {
                    Button(action: { viewModel?.snooze(option: .fiveMinutes) }) {
                        Text("settings.snooze.5min", bundle: .module)
                    }
                    .font(AppFont.body)
                    .accessibilityLabel(Text("settings.snooze.5min.label", bundle: .module))
                    .accessibilityHint(Text("settings.snooze.5min.hint", bundle: .module))

                    Button(action: { viewModel?.snooze(option: .oneHour) }) {
                        Text("settings.snooze.1hour", bundle: .module)
                    }
                    .font(AppFont.body)
                    .accessibilityLabel(Text("settings.snooze.1hour.label", bundle: .module))
                    .accessibilityHint(Text("settings.snooze.1hour.hint", bundle: .module))

                    Button(action: { viewModel?.snooze(option: .restOfDay) }) {
                        Text("settings.snooze.restOfDay", bundle: .module)
                    }
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.warningText)
                    .accessibilityLabel(Text("settings.snooze.restOfDay.label", bundle: .module))
                    .accessibilityHint(Text("settings.snooze.restOfDay.hint", bundle: .module))
                }
            } header: {
                Text("settings.section.snooze", bundle: .module)
            }

            // MARK: Preferences
            Section {
                Toggle(isOn: $settings.hapticsEnabled) {
                    Text("settings.hapticFeedback", bundle: .module)
                }
                    .tint(AppColor.reminderBlue)
                    .accessibilityHint(Text("settings.hapticFeedback.hint", bundle: .module))
            } header: {
                Text("settings.section.preferences", bundle: .module)
            }

            // MARK: Notification permission warning
            if coordinator.notificationAuthStatus == .denied {
                Section {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: AppSymbol.warning)
                            .foregroundStyle(AppColor.warningOrange)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("settings.notifications.disabledTitle", bundle: .module)
                                .font(AppFont.bodyEmphasized)
                            Text("settings.notifications.disabledBody", bundle: .module)
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                    .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("settings.notifications.disabledLabel", bundle: .module))

                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("settings.notifications.openSettings", bundle: .module)
                    }
                    .font(AppFont.body)
                    .accessibilityHint(Text("settings.notifications.openSettings.hint", bundle: .module))
                }
            }
        }
        .navigationTitle(Text("settings.navTitle", bundle: .module))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String(localized: "settings.doneButton", bundle: .module)) {
                    dismiss()
                }
                .fontWeight(.semibold)
                .accessibilityHint(Text("settings.doneButton.hint", bundle: .module))
            }
        }
        .animation(reduceMotion ? nil : AppAnimation.settingsExpandCurve, value: settings.globalEnabled)
        .animation(reduceMotion ? nil : AppAnimation.settingsExpandCurve, value: isSnoozed)
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
