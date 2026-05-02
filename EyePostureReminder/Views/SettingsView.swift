import SwiftUI
import UIKit
// swiftlint:disable file_length

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
    var iconName: String?
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
    @State private var showDisclaimer = false
    // Previous TimeInterval values for oldValue capture in analytics.
    // SwiftUI mutates $settings.xxx bindings before onChange fires, so we cannot
    // read the pre-mutation value inside the ViewModel setter (#386).
    @State private var prevEyesInterval: TimeInterval = .zero
    @State private var prevEyesBreakDuration: TimeInterval = .zero
    @State private var prevPostureInterval: TimeInterval = .zero
    @State private var prevPostureBreakDuration: TimeInterval = .zero
    @State private var showResetConfirm = false
    // #434: Transient "Settings saved" banner state.
    @State private var showSavedBanner = false
    @State private var savedBannerTask: Task<Void, Never>?

    private let accessibilityNotificationPoster: AccessibilityNotificationPosting

    init(
        isPresented: Binding<Bool>,
        accessibilityNotificationPoster: AccessibilityNotificationPosting = LiveAccessibilityNotificationPoster()
    ) {
        self._isPresented = isPresented
        self.accessibilityNotificationPoster = accessibilityNotificationPoster
    }

    var body: some View {
        Form {
            // MARK: Master toggle
            Section {
                AccessibleToggle(
                    isOn: $settings.globalEnabled,
                    tint: AppColor.primaryRest,
                    accessibilityIdentifier: "settings.masterToggle",
                    accessibilityHint: Text("settings.masterToggle.hint", bundle: .module),
                    onChange: { newValue in
                        viewModel?.notifySettingChanged(.globalEnabled, old: String(!newValue), new: String(newValue))
                        viewModel?.globalToggleChanged()
                        showSavedFeedback()
                    },
                    label: {
                        HStack(spacing: AppSpacing.sm) {
                            SettingsRowIcon(systemName: AppSymbol.masterToggle, tint: AppColor.primaryRest)
                            Text("settings.masterToggle", bundle: .module)
                                .foregroundStyle(AppColor.textPrimary)
                        }
                    }
                )
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
                    isOn: Binding(
                        get: { viewModel?.hapticsEnabled ?? settings.hapticsEnabled },
                        set: { newValue in
                            if let viewModel {
                                viewModel.hapticsEnabled = newValue
                            } else {
                                settings.hapticsEnabled = newValue
                            }
                        }
                    ),
                    tint: AppColor.primaryRest,
                    accessibilityIdentifier: "settings.hapticFeedback",
                    accessibilityHint: Text("settings.hapticFeedback.hint", bundle: .module)
                ) {
                    HStack(spacing: AppSpacing.sm) {
                        SettingsRowIcon(systemName: AppSymbol.haptics, tint: AppColor.primaryRest)
                        Text("settings.hapticFeedback", bundle: .module)
                            .foregroundStyle(AppColor.textPrimary)
                    }
                }
                .listRowBackground(AppColor.surface)
                .listRowSeparatorTint(AppColor.separatorSoft)

                AccessibleToggle(
                    isOn: Binding(
                        get: { viewModel?.notificationFallbackEnabled ?? settings.notificationFallbackEnabled },
                        set: { newValue in
                            if let viewModel {
                                viewModel.notificationFallbackEnabled = newValue
                            } else {
                                settings.notificationFallbackEnabled = newValue
                            }
                        }
                    ),
                    tint: AppColor.primaryRest,
                    accessibilityIdentifier: "settings.notificationFallback",
                    accessibilityHint: Text("settings.notificationFallback.hint", bundle: .module)
                ) {
                    HStack(spacing: AppSpacing.sm) {
                        SettingsRowIcon(systemName: AppSymbol.bell, tint: AppColor.primaryRest)
                        Text("settings.notificationFallback", bundle: .module)
                            .foregroundStyle(AppColor.textPrimary)
                    }
                }
                .listRowBackground(AppColor.surface)
                .listRowSeparatorTint(AppColor.separatorSoft)
            } header: {
                SettingsSectionHeader(titleKey: "settings.section.preferences")
            } footer: {
                Text("settings.notificationFallback.footer", bundle: .module)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }

            // MARK: Smart Pause
            SettingsSmartPauseSection(viewModel: viewModel)

            // MARK: True Interrupt Mode
            SettingsTrueInterruptSection()

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

                Button(action: { showDisclaimer = true },
                       label: { Text("settings.legal.disclaimer", bundle: .module) })
                .font(AppFont.body)
                .foregroundStyle(AppColor.primaryRest)
                .accessibilityHint(Text("settings.legal.disclaimer.hint", bundle: .module))
                .accessibilityIdentifier("settings.legal.disclaimer")
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
        // #434: "Settings saved" transient feedback banner at bottom.
        .safeAreaInset(edge: .bottom) {
            if showSavedBanner {
                SettingsSavedBanner()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, AppSpacing.md)
                    .accessibilityIdentifier("settings.savedBanner")
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showSavedBanner)
        .scrollContentBackground(.hidden)
        .background(AppColor.background.ignoresSafeArea())
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
        .sheet(isPresented: $showDisclaimer) {
            LegalDocumentView(document: .disclaimer)
        }
        .onAppear {
            if vmBox.inner == nil {
                vmBox.inner = SettingsViewModel(
                    settings: settings,
                    scheduler: coordinator
                )
            }
            prevEyesInterval = settings.eyesInterval
            prevEyesBreakDuration = settings.eyesBreakDuration
            prevPostureInterval = settings.postureInterval
            prevPostureBreakDuration = settings.postureBreakDuration
        }
        .onDisappear { savedBannerTask?.cancel() }
        .task {
            await coordinator.refreshAuthStatus()
        }
        // Announce master-toggle state changes to VoiceOver (#287).
        .onChangeCompat(of: settings.globalEnabled) { newValue in
            let message = newValue
                ? String(localized: "home.status.active", bundle: .module)
                : String(localized: "home.status.paused", bundle: .module)
            accessibilityNotificationPoster.postAnnouncement(message: message)
            showSavedFeedback()
        }
        // Announce snooze activate/cancel to VoiceOver (#406).
        .onChangeCompat(of: settings.snoozedUntil) { newValue in
            let message: String = newValue != nil
                ? String(localized: "settings.snooze.activated.announcement", bundle: .module)
                : String(localized: "settings.snooze.cancelled.announcement", bundle: .module)
            accessibilityNotificationPoster.postAnnouncement(message: message)
            showSavedFeedback()
        }
        // Analytics instrumentation for per-reminder settings (#297, #386).
        // SwiftUI mutates the store before onChange fires, so old values are captured here.
        // Note: old/new values are logged with `privacy: .private` (redacted in Console).
        .onChangeCompat(of: settings.eyesEnabled) { newValue in
            viewModel?.notifySettingChanged(
                .eyesEnabled,
                old: String(!newValue),
                new: String(newValue)
            )
            showSavedFeedback()
        }
        .onChangeCompat(of: settings.eyesInterval) { newValue in
            viewModel?.notifySettingChanged(
                .eyesInterval,
                old: String(prevEyesInterval),
                new: String(newValue)
            )
            prevEyesInterval = newValue
            showSavedFeedback()
        }
        .onChangeCompat(of: settings.eyesBreakDuration) { newValue in
            viewModel?.notifySettingChanged(
                .eyesBreakDuration,
                old: String(prevEyesBreakDuration),
                new: String(newValue)
            )
            prevEyesBreakDuration = newValue
            showSavedFeedback()
        }
        .onChangeCompat(of: settings.postureEnabled) { newValue in
            viewModel?.notifySettingChanged(
                .postureEnabled,
                old: String(!newValue),
                new: String(newValue)
            )
            showSavedFeedback()
        }
        .onChangeCompat(of: settings.postureInterval) { newValue in
            viewModel?.notifySettingChanged(
                .postureInterval,
                old: String(prevPostureInterval),
                new: String(newValue)
            )
            prevPostureInterval = newValue
            showSavedFeedback()
        }
        .onChangeCompat(of: settings.postureBreakDuration) { newValue in
            viewModel?.notifySettingChanged(
                .postureBreakDuration,
                old: String(prevPostureBreakDuration),
                new: String(newValue)
            )
            prevPostureBreakDuration = newValue
            showSavedFeedback()
        }
        // #434: Surface saved banner for Smart Pause toggles.
        .onChangeCompat(of: settings.pauseDuringFocus) { _ in showSavedFeedback() }
        .onChangeCompat(of: settings.pauseWhileDriving) { _ in showSavedFeedback() }
        // #434: Surface saved banner for preferences.
        .onChangeCompat(of: settings.hapticsEnabled) { _ in showSavedFeedback() }
        .onChangeCompat(of: settings.notificationFallbackEnabled) { _ in showSavedFeedback() }
    }

    // MARK: - Saved Banner (#434)

    /// Shows the "Settings saved" toast for 1.5 s, debounced against rapid successive changes.
    private func showSavedFeedback() {
        savedBannerTask?.cancel()
        showSavedBanner = true
        let msg = String(localized: "settings.savedBanner", bundle: .module)
        accessibilityNotificationPoster.postAnnouncement(message: msg)
        savedBannerTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            showSavedBanner = false
        }
    }
}

// MARK: - Saved Banner (#434)

/// Pill-shaped transient confirmation shown for 1.5 s after any setting change.
private struct SettingsSavedBanner: View {
    var body: some View {
        Label(
            String(localized: "settings.savedBanner", bundle: .module),
            systemImage: "checkmark.circle.fill"
        )
        .font(AppFont.bodyEmphasized)
        .foregroundStyle(AppColor.textPrimary)
        .accessibilityIdentifier("settings.savedBanner")
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColor.surface, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .accessibilityAddTraits(.isStaticText)
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

    private func animatedAction(_ action: @escaping () -> Void) {
        withMotionSafe(reduceMotion, animation: AppAnimation.settingsExpandCurve, action: action)
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
                    action: { animatedAction { viewModel?.cancelSnooze() } },
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
                    action: { animatedAction { viewModel?.snooze(option: .fiveMinutes) } },
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
                    action: { animatedAction { viewModel?.snooze(option: .oneHour) } },
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
                    action: { animatedAction { viewModel?.snooze(option: .restOfDay) } },
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
                    onChange: { newValue in
                        viewModel?.notifySettingChanged(
                            .pauseDuringFocus,
                            old: String(!newValue),
                            new: String(newValue)
                        )
                    },
                    label: {
                        Label(
                            String(localized: "settings.smartPause.pauseDuringFocus", bundle: .module),
                            systemImage: AppSymbol.pauseDuringFocus
                        )
                        .foregroundStyle(AppColor.textPrimary)
                    }
                )
            .listRowBackground(AppColor.surface)
            .listRowSeparatorTint(AppColor.separatorSoft)

            AccessibleToggle(
                isOn: $settings.pauseWhileDriving,
                tint: AppColor.primaryRest,
                    accessibilityIdentifier: "settings.smartPause.pauseWhileDriving",
                    accessibilityHint: Text("settings.smartPause.pauseWhileDriving.hint", bundle: .module),
                    onChange: { newValue in
                        viewModel?.notifySettingChanged(
                            .pauseWhileDriving,
                            old: String(!newValue),
                            new: String(newValue)
                        )
                    },
                    label: {
                        Label(
                            String(localized: "settings.smartPause.pauseWhileDriving", bundle: .module),
                            systemImage: AppSymbol.pauseWhileDriving
                        )
                        .foregroundStyle(AppColor.textPrimary)
                    }
                )
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

// MARK: - True Interrupt Mode Section

/// Settings section presenting True Interrupt Mode authorization status and
/// a "Configure App Break Access" button that launches `AppCategoryPickerView`.
/// Shows an inline denied-recovery warning (#252) and a status-aware footer (#250).
private struct SettingsTrueInterruptSection: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var selectedAppsState = SelectedAppsState()
    @State private var showPicker = false

    private var authStatus: ScreenTimeAuthorizationStatus {
        coordinator.screenTimeAuthorization.authorizationStatus
    }

    var body: some View {
        Section {
            // Status row
            HStack(spacing: AppSpacing.sm) {
                SettingsRowIcon(systemName: AppSymbol.trueInterrupt, tint: AppColor.primaryRest)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("settings.trueInterrupt.statusLabel", bundle: .module)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(LocalizedStringKey(authStatus.localizedStatusKey), bundle: .module)
                        .font(AppFont.caption)
                        .foregroundStyle(
                            authStatus == .approved ? AppColor.primaryRest : AppColor.textSecondary
                        )
                }
                Spacer()
            }
            .listRowBackground(AppColor.surface)
            .listRowSeparatorTint(AppColor.separatorSoft)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.trueInterrupt.statusRow")

            // Denied recovery: warning card + direct Settings link (#252)
            if authStatus == .denied {
                HStack(spacing: AppSpacing.sm) {
                    IconContainer(icon: AppSymbol.warning, color: AppColor.accentWarm, size: 36)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("settings.trueInterrupt.denied.title", bundle: .module)
                            .font(AppFont.bodyEmphasized)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("settings.trueInterrupt.denied.body", bundle: .module)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                .padding(.vertical, AppSpacing.xs)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("settings.trueInterrupt.denied.label", bundle: .module))
                .listRowBackground(AppColor.accentWarm.opacity(AppOpacity.warningBackground))
                .listRowSeparatorTint(AppColor.accentWarm.opacity(AppOpacity.warningSeparator))
                Button(
                    action: openApplicationSettings,
                    label: { Text("settings.trueInterrupt.openSettings", bundle: .module) }
                )
                .font(AppFont.body)
                .foregroundStyle(AppColor.accentWarm)
                .accessibilityHint(Text("settings.trueInterrupt.openSettings.hint", bundle: .module))
                .accessibilityIdentifier("settings.trueInterrupt.openSettings")
                .listRowBackground(AppColor.accentWarm.opacity(AppOpacity.warningBackground))
                .listRowSeparatorTint(AppColor.accentWarm.opacity(AppOpacity.warningSeparator))
            }

            // Configure button (disabled when entitlement is unavailable — #250)
            Button {
                showPicker = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Text("settings.trueInterrupt.configure", bundle: .module)
                        .font(AppFont.body)
                        .foregroundStyle(
                            authStatus == .unavailable
                                ? AppColor.textSecondary
                                : AppColor.primaryRest
                        )
                    Spacer()
                    Image(systemName: AppSymbol.chevronTrailing)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .disabled(authStatus == .unavailable)
            .listRowBackground(AppColor.surface)
            .listRowSeparatorTint(AppColor.separatorSoft)
            .accessibilityHint(authStatus == .unavailable
                ? Text("settings.trueInterrupt.configure.unavailable.hint", bundle: .module)
                : Text("settings.trueInterrupt.configure.hint", bundle: .module))
            .accessibilityIdentifier("settings.trueInterrupt.configureButton")
        } header: {
            SettingsSectionHeader(
                titleKey: "settings.section.trueInterrupt",
                iconName: AppSymbol.trueInterrupt,
                iconTint: AppColor.primaryRest
            )
        } footer: {
            // Pending-approval explanation when unavailable (#250); standard copy otherwise.
            Text(LocalizedStringKey(authStatus == .unavailable
                ? "settings.trueInterrupt.footer.unavailable"
                : "settings.trueInterrupt.footer"), bundle: .module)
            .font(AppFont.caption)
            .foregroundStyle(AppColor.textSecondary)
        }
        .sheet(isPresented: $showPicker) {
            AppCategoryPickerView(
                appsState: selectedAppsState,
                authorizationStatus: authStatus,
                onRequestAuthorization: {
                    Task { _ = await coordinator.screenTimeAuthorization.requestAuthorization() }
                },
                onOpenSettings: openApplicationSettings,
                onDone: { showPicker = false }
            )
        }
    }
}

// MARK: - Notification Warning Section

private struct SettingsNotificationWarningSection: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        if coordinator.notificationAuthStatus == .denied,
           coordinator.settings.notificationFallbackEnabled {
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
                .listRowBackground(AppColor.accentWarm.opacity(AppOpacity.warningBackground))
                .listRowSeparatorTint(AppColor.accentWarm.opacity(AppOpacity.warningSeparator))

                Button(
                    action: openApplicationSettings,
                    label: { Text("settings.notifications.openSettings", bundle: .module) }
                )
                .font(AppFont.body)
                .foregroundStyle(AppColor.accentWarm)
                .accessibilityHint(Text("settings.notifications.openSettings.hint", bundle: .module))
                .accessibilityIdentifier("settings.notifications.openSettings")
                .listRowBackground(AppColor.accentWarm.opacity(AppOpacity.warningBackground))
                .listRowSeparatorTint(AppColor.accentWarm.opacity(AppOpacity.warningSeparator))
            }
        }
    }
}

private func openApplicationSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        SettingsView(isPresented: .constant(true))
            .environmentObject(SettingsStore())
            .environmentObject(AppCoordinator())
    }
}
