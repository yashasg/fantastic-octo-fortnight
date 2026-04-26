import SwiftUI
import UIKit

// MARK: - ViewModel Box

/// @StateObject container that gives SwiftUI-managed lifecycle to SettingsViewModel.
/// Using @StateObject (instead of @State) ensures SwiftUI preserves the reference
/// across view re-renders and parent view updates.
private final class SettingsViewModelBox: ObservableObject {
    var inner: SettingsViewModel?
}

// MARK: - Icon Container

/// Circular tinted icon badge used in section rows and headers.
private struct SettingsRowIcon: View {
    let systemName: String
    let tint: Color

    var body: some View {
        IconContainer(icon: systemName, color: tint, size: 32)
            .accessibilityHidden(true)
    }
}

// MARK: - Section Header

/// Section header with optional tinted icon and styled caption text.
private struct SettingsSectionHeader: View {
    let titleKey: String.LocalizationValue
    var iconName: String? = nil
    var iconTint: Color = AppColor.primaryRest

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let iconName {
                SettingsRowIcon(systemName: iconName, tint: iconTint)
            }
            Text(String(localized: titleKey, bundle: .module))
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)
                .textCase(nil)
        }
    }
}

struct SettingsView: View {

    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: AppCoordinator

    // SettingsViewModel handles scheduling side-effects only.
    // Stored in a @StateObject container so SwiftUI properly manages the class lifecycle.
    @StateObject private var vmBox = SettingsViewModelBox()

    private var viewModel: SettingsViewModel? { vmBox.inner }

    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            // MARK: Master toggle
            Section {
                AccessibleToggle(
                    isOn: $settings.globalEnabled,
                    tint: AppColor.primaryRest,
                    accessibilityHint: Text("settings.masterToggle.hint", bundle: .module),
                    onChange: { _ in viewModel?.globalToggleChanged() }
                ) {
                    HStack(spacing: AppSpacing.sm) {
                        SettingsRowIcon(systemName: "power", tint: AppColor.primaryRest)
                        Text("settings.masterToggle", bundle: .module)
                            .foregroundStyle(AppColor.textPrimary)
                    }
                }
                .listRowBackground(AppColor.surface)
                .listRowSeparatorTint(AppColor.separatorSoft)
            } footer: {
                Group {
                    if settings.globalEnabled {
                        Text("settings.masterToggle.footer", bundle: .module)
                    } else {
                        Text("settings.pausedBanner", bundle: .module)
                    }
                }
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)
            }

            // MARK: Per-type sections (only shown when master is on)
            if settings.globalEnabled {
                Section {
                    ReminderRowView(
                        type: .eyes,
                        isEnabled: $settings.eyesEnabled,
                        interval: $settings.eyesInterval,
                        breakDuration: $settings.eyesBreakDuration
                    ) {
                        viewModel?.reminderSettingChanged(for: .eyes)
                    }
                    .listRowBackground(AppColor.surface)
                    .listRowSeparatorTint(AppColor.separatorSoft)
                } header: {
                    SettingsSectionHeader(
                        titleKey: "settings.section.eyes",
                        iconName: AppSymbol.eyeBreak,
                        iconTint: AppColor.primaryRest
                    )
                } footer: {
                    if settings.eyesEnabled {
                        Text("settings.reminder.section.footer", bundle: .module)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }

                Section {
                    ReminderRowView(
                        type: .posture,
                        isEnabled: $settings.postureEnabled,
                        interval: $settings.postureInterval,
                        breakDuration: $settings.postureBreakDuration
                    ) {
                        viewModel?.reminderSettingChanged(for: .posture)
                    }
                    .listRowBackground(AppColor.surface)
                    .listRowSeparatorTint(AppColor.separatorSoft)
                } header: {
                    SettingsSectionHeader(
                        titleKey: "settings.section.posture",
                        iconName: AppSymbol.postureCheck,
                        iconTint: AppColor.secondaryCalm
                    )
                } footer: {
                    if settings.postureEnabled {
                        Text("settings.reminder.section.footer", bundle: .module)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
            }

            // MARK: Snooze (only meaningful when reminders are globally enabled)
            if settings.globalEnabled {
                SettingsSnoozeSection(viewModel: viewModel, reduceMotion: reduceMotion)
            }

            // MARK: Preferences
            Section {
                AccessibleToggle(
                    isOn: $settings.hapticsEnabled,
                    tint: AppColor.primaryRest,
                    accessibilityIdentifier: "settings.hapticFeedback",
                    accessibilityHint: Text("settings.hapticFeedback.hint", bundle: .module)
                ) {
                    HStack(spacing: AppSpacing.sm) {
                        SettingsRowIcon(systemName: "hand.tap.fill", tint: AppColor.primaryRest)
                        Text("settings.hapticFeedback", bundle: .module)
                            .foregroundStyle(AppColor.textPrimary)
                    }
                }
                .listRowBackground(AppColor.surface)
                .listRowSeparatorTint(AppColor.separatorSoft)
            } header: {
                SettingsSectionHeader(titleKey: "settings.section.preferences")
            }

            // MARK: Smart Pause
            SettingsSmartPauseSection(viewModel: viewModel)

            // MARK: Notification permission warning
            SettingsNotificationWarningSection()

            // MARK: Legal
            Section {
                Button(action: { showTerms = true },
                       label: { Text("settings.legal.terms", bundle: .module) })
                .font(AppFont.body)
                .foregroundStyle(AppColor.primaryRest)
                .accessibilityHint(Text("settings.legal.terms.hint", bundle: .module))
                .accessibilityIdentifier("settings.legal.terms")
                .listRowBackground(AppColor.surface)
                .listRowSeparatorTint(AppColor.separatorSoft)

                Button(action: { showPrivacy = true },
                       label: { Text("settings.legal.privacy", bundle: .module) })
                .font(AppFont.body)
                .foregroundStyle(AppColor.primaryRest)
                .accessibilityHint(Text("settings.legal.privacy.hint", bundle: .module))
                .accessibilityIdentifier("settings.legal.privacy")
                .listRowBackground(AppColor.surface)
                .listRowSeparatorTint(AppColor.separatorSoft)
            } header: {
                SettingsSectionHeader(titleKey: "settings.section.legal")
            }

            // MARK: Advanced
            Section {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Text("settings.resetToDefaults", bundle: .module)
                }
                .font(AppFont.body)
                .accessibilityHint(Text("settings.resetToDefaults.hint", bundle: .module))
                .accessibilityIdentifier("settings.resetToDefaults")
                .listRowBackground(AppColor.surface)
                .listRowSeparatorTint(AppColor.separatorSoft)
            } header: {
                SettingsSectionHeader(titleKey: "settings.section.advanced")
            }
            .confirmationDialog(
                Text("settings.resetToDefaults.confirmTitle", bundle: .module),
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    settings.resetToDefaults()
                } label: {
                    Text("settings.resetToDefaults.confirmAction", bundle: .module)
                }
                Button(role: .cancel) {
                    showResetConfirm = false
                } label: {
                    Text("settings.resetToDefaults.cancel", bundle: .module)
                }
            } message: {
                Text("settings.resetToDefaults.confirmMessage", bundle: .module)
            }

            // MARK: About — feedback + version
            Section {
                Button {
                    // itms-beta:// opens TestFlight when installed.
                    // For users who installed from the App Store, fall back to the
                    // TestFlight website so the tap is never a silent no-op.
                    if let url = URL(string: "itms-beta://") {
                        UIApplication.shared.open(url, options: [:]) { success in
                            if !success, let fallback = URL(string: "https://testflight.apple.com") {
                                UIApplication.shared.open(fallback)
                            }
                        }
                    }
                } label: {
                    Text("settings.feedback.sendFeedback", bundle: .module)
                }
                .font(AppFont.body)
                .foregroundStyle(AppColor.primaryRest)
                .accessibilityHint(Text("settings.feedback.sendFeedback.hint", bundle: .module))
                .accessibilityIdentifier("settings.feedback.sendFeedback")
                .listRowBackground(AppColor.surface)
                .listRowSeparatorTint(AppColor.separatorSoft)
            } header: {
                SettingsSectionHeader(titleKey: "settings.section.about")
            } footer: {
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
                let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
                Text(
                    String(
                        format: String(localized: "settings.about.versionFormat", bundle: .module),
                        version,
                        build
                    )
                )
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColor.background)
        .navigationTitle(Text("settings.navTitle", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String(localized: "settings.doneButton", bundle: .module)) {
                    isPresented = false
                }
                .font(AppFont.bodyEmphasized)
                .foregroundStyle(AppColor.primaryRest)
                .accessibilityHint(Text("settings.doneButton.hint", bundle: .module))
                .accessibilityIdentifier("settings.doneButton")
            }
        }
        .sheet(isPresented: $showTerms) {
            LegalDocumentView(document: .terms)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalDocumentView(document: .privacy)
        }
        .onAppear {
            if vmBox.inner == nil {
                vmBox.inner = SettingsViewModel(
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

// MARK: - Snooze Section

private struct SettingsSnoozeSection: View {
    @EnvironmentObject private var settings: SettingsStore
    let viewModel: SettingsViewModel?
    let reduceMotion: Bool

    private var isSnoozed: Bool {
        guard let until = settings.snoozedUntil else { return false }
        return until > Date()
    }

    private var snoozeUntilFormatted: String {
        guard let until = settings.snoozedUntil, until > Date() else { return "" }
        return until.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        Section {
            if isSnoozed {
                HStack {
                    Label(
                        String(
                            format: String(localized: "settings.snooze.activeLabel", bundle: .module),
                            snoozeUntilFormatted
                        ),
                        systemImage: AppSymbol.snoozed
                    )
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.warningText)
                    Spacer()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(
                    format: String(localized: "settings.snooze.activeLabel.accessibility", bundle: .module),
                    snoozeUntilFormatted
                ))
                .listRowBackground(AppColor.surface)
                .listRowSeparatorTint(AppColor.separatorSoft)

                Button(
                    action: {
                        if reduceMotion {
                            viewModel?.cancelSnooze()
                        } else {
                            withAnimation(AppAnimation.settingsExpandCurve) {
                                viewModel?.cancelSnooze()
                            }
                        }
                    },
                    label: {
                        Label {
                            Text("settings.snooze.cancelButton", bundle: .module)
                        } icon: {
                            Image(systemName: AppSymbol.bell)
                        }
                        .font(AppFont.body)
                    }
                )
                .foregroundStyle(AppColor.primaryRest)
                .accessibilityHint(Text("settings.snooze.cancelButton.hint", bundle: .module))
                .accessibilityIdentifier("settings.snooze.cancelButton")
                .listRowBackground(AppColor.surface)
                .listRowSeparatorTint(AppColor.separatorSoft)
            } else {
                Button(
                    action: {
                        if reduceMotion {
                            viewModel?.snooze(option: .fiveMinutes)
                        } else {
                            withAnimation(AppAnimation.settingsExpandCurve) {
                                viewModel?.snooze(option: .fiveMinutes)
                            }
                        }
                    },
                    label: { Text("settings.snooze.5min", bundle: .module) }
                )
                .font(AppFont.body)
                .foregroundStyle(AppColor.primaryRest)
                .disabled(!(viewModel?.canSnooze ?? false))
                .accessibilityLabel(Text("settings.snooze.5min.label", bundle: .module))
                .accessibilityHint(viewModel?.canSnooze ?? false
                    ? Text("settings.snooze.5min.hint", bundle: .module)
                    : Text("settings.snooze.limitReached.hint", bundle: .module))
                .accessibilityIdentifier("settings.snooze.5min")
                .listRowBackground(AppColor.surface)
                .listRowSeparatorTint(AppColor.separatorSoft)

                Button(
                    action: {
                        if reduceMotion {
                            viewModel?.snooze(option: .oneHour)
                        } else {
                            withAnimation(AppAnimation.settingsExpandCurve) {
                                viewModel?.snooze(option: .oneHour)
                            }
                        }
                    },
                    label: { Text("settings.snooze.1hour", bundle: .module) }
                )
                .font(AppFont.body)
                .foregroundStyle(AppColor.primaryRest)
                .disabled(!(viewModel?.canSnooze ?? false))
                .accessibilityLabel(Text("settings.snooze.1hour.label", bundle: .module))
                .accessibilityHint(viewModel?.canSnooze ?? false
                    ? Text("settings.snooze.1hour.hint", bundle: .module)
                    : Text("settings.snooze.limitReached.hint", bundle: .module))
                .accessibilityIdentifier("settings.snooze.1hour")
                .listRowBackground(AppColor.surface)
                .listRowSeparatorTint(AppColor.separatorSoft)

                Button(
                    action: {
                        if reduceMotion {
                            viewModel?.snooze(option: .restOfDay)
                        } else {
                            withAnimation(AppAnimation.settingsExpandCurve) {
                                viewModel?.snooze(option: .restOfDay)
                            }
                        }
                    },
                    label: { Text("settings.snooze.restOfDay", bundle: .module) }
                )
                .font(AppFont.body)
                .foregroundStyle(AppColor.warningText)
                .disabled(!(viewModel?.canSnooze ?? false))
                .accessibilityLabel(Text("settings.snooze.restOfDay.label", bundle: .module))
                .accessibilityHint(viewModel?.canSnooze ?? false
                    ? Text("settings.snooze.restOfDay.hint", bundle: .module)
                    : Text("settings.snooze.limitReached.hint", bundle: .module))
                .accessibilityIdentifier("settings.snooze.restOfDay")
                .listRowBackground(AppColor.surface)
                .listRowSeparatorTint(AppColor.separatorSoft)
            }
        } header: {
            SettingsSectionHeader(
                titleKey: "settings.section.snooze",
                iconName: AppSymbol.snoozed,
                iconTint: AppColor.accentWarm
            )
        }
    }
}

// MARK: - Smart Pause Section

private struct SettingsSmartPauseSection: View {
    @EnvironmentObject private var settings: SettingsStore
    let viewModel: SettingsViewModel?

    var body: some View {
        Section {
            AccessibleToggle(
                isOn: $settings.pauseDuringFocus,
                tint: AppColor.primaryRest,
                accessibilityIdentifier: "settings.smartPause.pauseDuringFocus",
                accessibilityHint: Text("settings.smartPause.pauseDuringFocus.hint", bundle: .module),
                onChange: { newValue in viewModel?.pauseDuringFocus = newValue }
            ) {
                Label(
                    String(localized: "settings.smartPause.pauseDuringFocus", bundle: .module),
                    systemImage: AppSymbol.pauseDuringFocus
                )
                .foregroundStyle(AppColor.textPrimary)
            }
            .listRowBackground(AppColor.surface)
            .listRowSeparatorTint(AppColor.separatorSoft)

            AccessibleToggle(
                isOn: $settings.pauseWhileDriving,
                tint: AppColor.primaryRest,
                accessibilityIdentifier: "settings.smartPause.pauseWhileDriving",
                accessibilityHint: Text("settings.smartPause.pauseWhileDriving.hint", bundle: .module),
                onChange: { newValue in viewModel?.pauseWhileDriving = newValue }
            ) {
                Label(
                    String(localized: "settings.smartPause.pauseWhileDriving", bundle: .module),
                    systemImage: AppSymbol.pauseWhileDriving
                )
                .foregroundStyle(AppColor.textPrimary)
            }
            .listRowBackground(AppColor.surface)
            .listRowSeparatorTint(AppColor.separatorSoft)
        } header: {
            SettingsSectionHeader(
                titleKey: "settings.section.smartPause",
                iconName: AppSymbol.pauseDuringFocus,
                iconTint: AppColor.primaryRest
            )
        } footer: {
            Text("settings.smartPause.footer", bundle: .module)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}

// MARK: - Notification Warning Section

private struct SettingsNotificationWarningSection: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        if coordinator.notificationAuthStatus == .denied {
            Section {
                HStack(spacing: AppSpacing.sm) {
                    IconContainer(icon: AppSymbol.warning, color: AppColor.accentWarm, size: 36)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("settings.notifications.disabledTitle", bundle: .module)
                            .font(AppFont.bodyEmphasized)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("settings.notifications.disabledBody", bundle: .module)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                .padding(.vertical, AppSpacing.xs)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("settings.notifications.disabledLabel", bundle: .module))
                .listRowBackground(AppColor.accentWarm.opacity(0.10))
                .listRowSeparatorTint(AppColor.accentWarm.opacity(0.25))

                Button(
                    action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    label: { Text("settings.notifications.openSettings", bundle: .module) }
                )
                .font(AppFont.body)
                .foregroundStyle(AppColor.accentWarm)
                .accessibilityHint(Text("settings.notifications.openSettings.hint", bundle: .module))
                .listRowBackground(AppColor.accentWarm.opacity(0.10))
                .listRowSeparatorTint(AppColor.accentWarm.opacity(0.25))
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(isPresented: .constant(true))
            .environmentObject(SettingsStore())
            .environmentObject(AppCoordinator())
    }
}
