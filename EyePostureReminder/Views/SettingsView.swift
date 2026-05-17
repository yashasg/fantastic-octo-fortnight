import ComposableArchitecture
import SwiftUI
import UIKit
import UserNotifications
// swiftlint:disable file_length

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

/// Settings sheet, wired to `SettingsFeature` as part of `#755` Phase B.
///
/// The legacy `@EnvironmentObject SettingsStore` / `AppCoordinator` graph
/// (and the `SettingsViewModelBox` that bridged them) is gone:
///
/// - `eyesInterval` / `eyesBreakDuration` flow through the bindable surface
///   of `SettingsFeature`, so debounced reschedules and the saved-banner
///   effect run inside the reducer.
/// - Every other setting binds directly to its persisted UserDefaults key
///   via `@AppStorage(SettingsStore.Keys.*)`. `SettingsClient.liveValue`
///   observes the same `SettingsStore` instance and rebroadcasts changes
///   into the wider TCA graph, so removing the in-view `SettingsStore`
///   reference does not break the scheduler.
/// - Notification + Screen Time authorisation status now come from
///   `SettingsFeature.State`, refreshed via the same `NotificationClient`
///   poll + `ScreenTimeAuthorizationClient` stream used by `HomeFeature`.
///
/// The `setting_changed` analytics emissions that lived on the legacy
/// `SettingsViewModel.notifySettingChanged(...)` callbacks are restored by
/// #777 via `prev*` `@State` mirrors and `.onChangeCompat` watchers that
/// forward each change to `SettingsFeature.Action.settingToggleChanged`.
/// `eyesInterval` / `eyesBreakDuration` keep emitting directly from the
/// reducer's bindable surface.
struct SettingsView: View {
    @Perception.Bindable var store: StoreOf<SettingsFeature>

    @AppStorage(SettingsStore.Keys.globalEnabled) private var globalEnabled = true
    @AppStorage(SettingsStore.Keys.eyesEnabled) private var eyesEnabled = true
    @AppStorage(SettingsStore.Keys.postureEnabled) private var postureEnabled = true
    @AppStorage(SettingsStore.Keys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(SettingsStore.Keys.pauseMediaDuringBreaks)
    private var pauseMediaDuringBreaks = false
    @AppStorage(SettingsStore.Keys.pauseDuringFocus) private var pauseDuringFocus = true
    @AppStorage(SettingsStore.Keys.pauseWhileDriving) private var pauseWhileDriving = true
    @AppStorage(SettingsStore.Keys.notificationFallbackEnabled)
    private var notificationFallbackEnabled = true
    @AppStorage(SettingsStore.Keys.snoozedUntil) private var snoozedUntilEpoch: Double = 0
    @AppStorage(SettingsStore.Keys.snoozeCount) private var snoozeCount: Int = 0

    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showDisclaimer = false

    private let accessibilityNotificationPoster: AccessibilityNotificationPosting

    init(
        store: StoreOf<SettingsFeature>,
        isPresented: Binding<Bool>,
        accessibilityNotificationPoster: AccessibilityNotificationPosting = LiveAccessibilityNotificationPoster()
    ) {
        self.store = store
        self._isPresented = isPresented
        self.accessibilityNotificationPoster = accessibilityNotificationPoster
    }

    var body: some View {
        WithPerceptionTracking {
            Form {
                masterToggleSection

                if globalEnabled {
                    eyesSection
                    postureSection
                    SettingsSnoozeSection(
                        store: store,
                        snoozedUntilEpoch: snoozedUntilEpoch,
                        canSnooze: canSnooze,
                        reduceMotion: reduceMotion
                    )
                }

                preferencesSection
                SettingsSmartPauseSection(
                    pauseDuringFocus: $pauseDuringFocus,
                    pauseWhileDriving: $pauseWhileDriving
                )
                SettingsTrueInterruptSection(screenTimeAuthStatus: store.screenTimeAuthStatus)
                SettingsNotificationWarningSection(notificationAuthStatus: store.notificationAuthStatus)
                legalSection
                advancedSection
                aboutSection
            }
            // #434: "Settings saved" transient feedback banner at bottom.
            // Use `.overlay(alignment: .bottom)` rather than
            // `.safeAreaInset(edge: .bottom)`: conditionally-inserted
            // children of `.safeAreaInset` do not surface in the XCUI
            // accessibility tree on iOS 26+ (the inset's host view absorbs
            // them), causing `SettingsFlowTests
            // .test_settings_savedBanner_appearsOnToggle` to fail even
            // though the banner renders visually. Tracked as #787 / #434.
            .overlay(alignment: .bottom) {
                if store.showSavedBanner {
                    SettingsSavedBanner()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, AppSpacing.md)
                        .accessibilityIdentifier("settings.savedBanner")
                }
            }
            .animation(.easeInOut(duration: 0.25), value: store.showSavedBanner)
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
                store.send(.onAppear)
            }
            .task { await store.send(.task).finish() }
            // Announce master-toggle state changes to VoiceOver (#287).
            .onChangeCompat(of: globalEnabled) { newValue in
                let message = newValue
                    ? String(localized: "home.status.active", bundle: .module)
                    : String(localized: "home.status.paused", bundle: .module)
                accessibilityNotificationPoster.postAnnouncement(message: message)
            }
            // Announce snooze activate/cancel to VoiceOver (#406).
            .onChangeCompat(of: snoozedUntilEpoch) { newValue in
                let message: String = newValue > 0
                    ? String(localized: "settings.snooze.activated.announcement", bundle: .module)
                    : String(localized: "settings.snooze.cancelled.announcement", bundle: .module)
                accessibilityNotificationPoster.postAnnouncement(message: message)
            }
            // `setting_changed` emissions for the seven non-bindable
            // Settings rows (#777). `eyesInterval` / `eyesBreakDuration` and
            // (post-#805) `postureInterval` / `postureBreakDuration` all
            // emit from the reducer's bindable surface.
            .modifier(SettingsAnalyticsForwarder(store: store))
        }
    }

    // MARK: - Sections

    // swiftlint:disable:next inclusive_language
    private var masterToggleSection: some View {
        Section {
            AccessibleToggle(
                isOn: $globalEnabled,
                tint: AppColor.primaryRest,
                accessibilityIdentifier: "settings.masterToggle",
                accessibilityHint: Text("settings.masterToggle.hint", bundle: .module),
                // Analytics and VoiceOver announcements both fire from the
                // `.onChangeCompat(of: globalEnabled)` modifiers on the
                // enclosing `Form` so the toggle stays a pure rendering of
                // the persisted `@AppStorage` value.
                onChange: { _ in },
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
                if globalEnabled {
                    Text("settings.masterToggle.footer", bundle: .module)
                } else {
                    Text("settings.pausedBanner", bundle: .module)
                }
            }
            .font(AppFont.caption)
            .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var eyesSection: some View {
        Section {
            ReminderRowView(
                type: .eyes,
                isEnabled: $eyesEnabled,
                interval: $store.eyesInterval,
                breakDuration: $store.eyesBreakDuration
            ) {
                // Eyes-side reschedule + `setting_changed` analytics are
                // reducer-owned: `$store.eyesInterval` /
                // `$store.eyesBreakDuration` flow through `SettingsFeature`'s
                // bindable surface, which debounces and dispatches the
                // reschedule effect. No view-level callback needed here.
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
            if eyesEnabled {
                Text("settings.reminder.section.footer", bundle: .module)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    private var postureSection: some View {
        Section {
            ReminderRowView(
                type: .posture,
                isEnabled: $postureEnabled,
                interval: $store.postureInterval,
                breakDuration: $store.postureBreakDuration
            ) {
                // Posture-side reschedule + `setting_changed` analytics are
                // reducer-owned after #805: `$store.postureInterval` /
                // `$store.postureBreakDuration` flow through
                // `SettingsFeature`'s bindable surface, which debounces and
                // dispatches the per-type reschedule effect. Mirrors the
                // eyes-side flow above; no view-level callback needed here.
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
            if postureEnabled {
                Text("settings.reminder.section.footer", bundle: .module)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    private var preferencesSection: some View {
        Section {
            AccessibleToggle(
                isOn: $hapticsEnabled,
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
                isOn: $notificationFallbackEnabled,
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
    }

    private var legalSection: some View {
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

            Button {
                guard let hostedPrivacyPolicyURL = LegalLinks.hostedPrivacyPolicyURL else { return }
                openURL(hostedPrivacyPolicyURL)
            } label: {
                Text("settings.legal.privacyHosted", bundle: .module)
            }
            .font(AppFont.body)
            .foregroundStyle(AppColor.primaryRest)
            .accessibilityHint(Text("settings.legal.privacyHosted.hint", bundle: .module))
            .accessibilityIdentifier("settings.legal.privacyHosted")
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
    }

    private var advancedSection: some View {
        Section {
            Button(role: .destructive) {
                store.showResetConfirm = true
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
            isPresented: $store.showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                store.send(.resetConfirmed)
            } label: {
                Text("settings.resetToDefaults.confirmAction", bundle: .module)
            }
            Button(role: .cancel) {
                store.showResetConfirm = false
            } label: {
                Text("settings.resetToDefaults.cancel", bundle: .module)
            }
        } message: {
            Text("settings.resetToDefaults.confirmMessage", bundle: .module)
        }
    }

    private var aboutSection: some View {
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

    // MARK: - Helpers

    /// Max consecutive snoozes allowed before snooze CTAs disable, mirroring
    /// the constant `SettingsViewModel` captured from
    /// `AppConfig.features.maxSnoozeCount` at init time. The value is read
    /// fresh on each evaluation so a `defaults.json` swap during preview /
    /// snapshot tests is observable without rebuilding the view.
    private var canSnooze: Bool {
        snoozeCount < AppConfig.load().features.maxSnoozeCount
    }
}

// MARK: - Saved Banner (#434)

/// Pill-shaped transient confirmation shown for 1.5 s after any setting change.
struct SettingsSavedBanner: View {
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColor.primaryRest)
                .accessibilityHidden(true)

            Text(String(localized: "settings.savedBanner", bundle: .module))
        }
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
    let store: StoreOf<SettingsFeature>
    let snoozedUntilEpoch: Double
    let canSnooze: Bool
    let reduceMotion: Bool

    private var snoozedUntil: Date? {
        snoozedUntilEpoch > 0 ? Date(timeIntervalSince1970: snoozedUntilEpoch) : nil
    }

    private var isSnoozed: Bool {
        guard let until = snoozedUntil else { return false }
        return until > Date()
    }

    private var snoozeUntilFormatted: String {
        guard let until = snoozedUntil, until > Date() else { return "" }
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
                    action: { animatedAction { store.send(.cancelSnooze) } },
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
                snoozeButton(.fiveMinutes, titleKey: "settings.snooze.5min",
                             labelKey: "settings.snooze.5min.label",
                             hintKey: "settings.snooze.5min.hint",
                             identifier: "settings.snooze.5min",
                             tint: AppColor.primaryRest)
                snoozeButton(.oneHour, titleKey: "settings.snooze.1hour",
                             labelKey: "settings.snooze.1hour.label",
                             hintKey: "settings.snooze.1hour.hint",
                             identifier: "settings.snooze.1hour",
                             tint: AppColor.primaryRest)
                snoozeButton(.restOfDay, titleKey: "settings.snooze.restOfDay",
                             labelKey: "settings.snooze.restOfDay.label",
                             hintKey: "settings.snooze.restOfDay.hint",
                             identifier: "settings.snooze.restOfDay",
                             tint: AppColor.warningText)
            }
        } header: {
            SettingsSectionHeader(
                titleKey: "settings.section.snooze",
                iconName: AppSymbol.snoozed,
                iconTint: AppColor.accentWarm
            )
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func snoozeButton(
        _ option: SettingsFeature.SnoozeOption,
        titleKey: String.LocalizationValue,
        labelKey: String.LocalizationValue,
        hintKey: String.LocalizationValue,
        identifier: String,
        tint: Color
    ) -> some View {
        Button(
            action: { animatedAction { store.send(.snoozeTapped(option)) } },
            label: { Text(String(localized: titleKey, bundle: .module)) }
        )
        .font(AppFont.body)
        .foregroundStyle(tint)
        .disabled(!canSnooze)
        .accessibilityLabel(Text(String(localized: labelKey, bundle: .module)))
        .accessibilityHint(canSnooze
            ? Text(String(localized: hintKey, bundle: .module))
            : Text("settings.snooze.limitReached.hint", bundle: .module))
        .accessibilityIdentifier(identifier)
        .listRowBackground(AppColor.surface)
        .listRowSeparatorTint(AppColor.separatorSoft)
    }
}

// MARK: - Smart Pause Section

private struct SettingsSmartPauseSection: View {
    @Binding var pauseDuringFocus: Bool
    @Binding var pauseWhileDriving: Bool

    var body: some View {
        Section {
            AccessibleToggle(
                isOn: $pauseDuringFocus,
                tint: AppColor.primaryRest,
                accessibilityIdentifier: "settings.smartPause.pauseDuringFocus",
                accessibilityHint: Text("settings.smartPause.pauseDuringFocus.hint", bundle: .module),
                // `setting_changed` emission is owned by `SettingsView`'s
                // `.onChangeCompat(of: pauseDuringFocus)` watcher (#777).
                onChange: { _ in },
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
                isOn: $pauseWhileDriving,
                tint: AppColor.primaryRest,
                accessibilityIdentifier: "settings.smartPause.pauseWhileDriving",
                accessibilityHint: Text("settings.smartPause.pauseWhileDriving.hint", bundle: .module),
                // `setting_changed` emission is owned by `SettingsView`'s
                // `.onChangeCompat(of: pauseWhileDriving)` watcher (#777).
                onChange: { _ in },
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
    let screenTimeAuthStatus: ScreenTimeAuthorizationStatus
    @State private var showPicker = false

    var body: some View {
        Section {
            // Status row
            HStack(spacing: AppSpacing.sm) {
                SettingsRowIcon(systemName: AppSymbol.trueInterrupt, tint: AppColor.primaryRest)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("settings.trueInterrupt.statusLabel", bundle: .module)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(LocalizedStringKey(screenTimeAuthStatus.localizedStatusKey), bundle: .module)
                        .font(AppFont.caption)
                        .foregroundStyle(
                            screenTimeAuthStatus == .approved ? AppColor.primaryRest : AppColor.textSecondary
                        )
                }
                Spacer()
            }
            .listRowBackground(AppColor.surface)
            .listRowSeparatorTint(AppColor.separatorSoft)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.trueInterrupt.statusRow")

            // Denied recovery: warning card + direct Settings link (#252)
            if screenTimeAuthStatus == .denied {
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
                            screenTimeAuthStatus == .unavailable
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
            .disabled(screenTimeAuthStatus == .unavailable)
            .listRowBackground(AppColor.surface)
            .listRowSeparatorTint(AppColor.separatorSoft)
            .accessibilityHint(screenTimeAuthStatus == .unavailable
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
            Text(LocalizedStringKey(screenTimeAuthStatus == .unavailable
                ? "settings.trueInterrupt.footer.unavailable"
                : "settings.trueInterrupt.footer"), bundle: .module)
            .font(AppFont.caption)
            .foregroundStyle(AppColor.textSecondary)
        }
        .sheet(isPresented: $showPicker) {
            AppCategoryPickerSheet(onSelectApps: {})
        }
    }
}

// MARK: - AppCategoryPicker Sheet Wrapper

/// Owns a local `Store` for `AppCategoryPickerView` while the picker is still
/// presented from MVVM-era parents (`SettingsView`, `OnboardingView`). When
/// Phase D of #755 wires `RootView` as the destination owner, both call sites
/// can drop this wrapper and present via `$store.scope`.
private struct AppCategoryPickerSheet: View {
    let onSelectApps: () -> Void

    @State private var store = Store(
        initialState: AppCategoryPickerFeature.State()
    ) { AppCategoryPickerFeature() }

    var body: some View {
        AppCategoryPickerView(store: store, onSelectApps: onSelectApps)
    }
}

// MARK: - Notification Warning Section

private struct SettingsNotificationWarningSection: View {
    let notificationAuthStatus: UNAuthorizationStatus

    var body: some View {
        if notificationAuthStatus == .denied {
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

// MARK: - Setting-change analytics forwarder

/// Forwards every change to a non-bindable `SettingsView` row into
/// `SettingsFeature.Action.settingToggleChanged` so the post-TCA
/// `setting_changed` analytics emission gap is closed without growing
/// `SettingsView`'s body past SwiftLint's `type_body_length` cap.
///
/// The view owns the `@AppStorage` mirrors as well; this modifier observes
/// the same UserDefaults keys so the prev-value snapshot stays in sync with
/// the row even when the value mutates outside the View (e.g. via reset).
/// Eyes interval/duration and posture interval/duration emissions are
/// owned by `SettingsFeature`'s bindable surface (#777, #805) so they do
/// not appear here.
private struct SettingsAnalyticsForwarder: ViewModifier {
    let store: StoreOf<SettingsFeature>

    @AppStorage(SettingsStore.Keys.globalEnabled) private var globalEnabled = true
    @AppStorage(SettingsStore.Keys.eyesEnabled) private var eyesEnabled = true
    @AppStorage(SettingsStore.Keys.postureEnabled) private var postureEnabled = true
    @AppStorage(SettingsStore.Keys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(SettingsStore.Keys.pauseDuringFocus) private var pauseDuringFocus = true
    @AppStorage(SettingsStore.Keys.pauseWhileDriving) private var pauseWhileDriving = true
    @AppStorage(SettingsStore.Keys.notificationFallbackEnabled)
    private var notificationFallbackEnabled = true

    // Pre-change snapshots used to compute the `oldValue` carried by each
    // `.settingToggleChanged` emission. `@AppStorage.onChange` fires with the
    // post-change value only, so we capture the prior value on appearance and
    // refresh it after every successful emit. Mirrors the `prev*` pattern in
    // `OnboardingSetupView`.
    @State private var prevGlobalEnabled = true
    @State private var prevEyesEnabled = true
    @State private var prevPostureEnabled = true
    @State private var prevHapticsEnabled = true
    @State private var prevPauseDuringFocus = true
    @State private var prevPauseWhileDriving = true
    @State private var prevNotificationFallbackEnabled = true

    func body(content: Content) -> some View {
        content
            .onAppear { primeSnapshots() }
            .onChangeCompat(of: globalEnabled) { newValue in
                emit(.globalEnabled, prev: &prevGlobalEnabled, newValue: newValue)
            }
            .onChangeCompat(of: eyesEnabled) { newValue in
                emit(.eyesEnabled, prev: &prevEyesEnabled, newValue: newValue)
            }
            .onChangeCompat(of: postureEnabled) { newValue in
                emit(.postureEnabled, prev: &prevPostureEnabled, newValue: newValue)
            }
            .onChangeCompat(of: hapticsEnabled) { newValue in
                emit(.hapticsEnabled, prev: &prevHapticsEnabled, newValue: newValue)
            }
            .onChangeCompat(of: notificationFallbackEnabled) { newValue in
                emit(
                    .notificationFallbackEnabled,
                    prev: &prevNotificationFallbackEnabled,
                    newValue: newValue
                )
            }
            .onChangeCompat(of: pauseDuringFocus) { newValue in
                emit(.pauseDuringFocus, prev: &prevPauseDuringFocus, newValue: newValue)
            }
            .onChangeCompat(of: pauseWhileDriving) { newValue in
                emit(.pauseWhileDriving, prev: &prevPauseWhileDriving, newValue: newValue)
            }
    }

    private func primeSnapshots() {
        prevGlobalEnabled = globalEnabled
        prevEyesEnabled = eyesEnabled
        prevPostureEnabled = postureEnabled
        prevHapticsEnabled = hapticsEnabled
        prevPauseDuringFocus = pauseDuringFocus
        prevPauseWhileDriving = pauseWhileDriving
        prevNotificationFallbackEnabled = notificationFallbackEnabled
    }

    private func emit<Value: Equatable & CustomStringConvertible>(
        _ key: AnalyticsEvent.SettingKey,
        prev: inout Value,
        newValue: Value
    ) {
        guard prev != newValue else { return }
        let oldValue = prev
        prev = newValue
        store.send(.settingToggleChanged(
            setting: key,
            oldValue: String(describing: oldValue),
            newValue: String(describing: newValue)
        ))
    }
}

#Preview {
    NavigationStack {
        SettingsView(
            store: Store(initialState: SettingsFeature.State()) { SettingsFeature() },
            isPresented: .constant(true)
        )
    }
}
