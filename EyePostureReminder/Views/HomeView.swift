import SwiftUI
import UIKit
import UserNotifications

struct HomeView: View {
    typealias LaunchArgumentsProvider = () -> [String]
    typealias ProcessEnvironmentProvider = () -> [String: String]

    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: AppCoordinator

    @State private var showSettings = false
    @AppStorage(AppStorageKey.openSettingsOnLaunch) private var openSettingsOnLaunch = false
    @AppStorage(AppStorageKey.trueInterruptSkippedBannerDismissed) private var trueInterruptBannerDismissed = false
#if DEBUG
    @AppStorage(AppStorageKey.uiTestScreenTimeStatus) private var uiTestScreenTimeStatusRaw = ""
#endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accessibilityNotificationPoster: AccessibilityNotificationPosting
    private let launchArguments: [String]?
    private let launchArgumentsProvider: LaunchArgumentsProvider
    private let processEnvironment: [String: String]?
    private let processEnvironmentProvider: ProcessEnvironmentProvider

    init(
        accessibilityNotificationPoster: AccessibilityNotificationPosting = LiveAccessibilityNotificationPoster(),
        launchArguments: [String]? = nil,
        launchArgumentsProvider: @escaping LaunchArgumentsProvider = { CommandLine.arguments },
        processEnvironment: [String: String]? = nil,
        processEnvironmentProvider: @escaping ProcessEnvironmentProvider = { ProcessInfo.processInfo.environment }
    ) {
        self.accessibilityNotificationPoster = accessibilityNotificationPoster
        self.launchArguments = launchArguments
        self.launchArgumentsProvider = launchArgumentsProvider
        self.processEnvironment = processEnvironment
        self.processEnvironmentProvider = processEnvironmentProvider
    }

    private var statusLabel: String {
        let key = Self.statusLocalizationKey(
            globalEnabled: settings.globalEnabled,
            eyesEnabled: settings.eyesEnabled,
            postureEnabled: settings.postureEnabled,
            notificationAuthStatus: coordinator.notificationAuthStatus
        )
        return String(localized: String.LocalizationValue(key), bundle: .module)
    }

    private var shouldShowNotificationRecovery: Bool {
        Self.shouldShowNotificationRecovery(
            globalEnabled: settings.globalEnabled,
            notificationAuthStatus: coordinator.notificationAuthStatus
        )
    }

    private var shouldShowNoRemindersConfigured: Bool {
        Self.shouldShowNoRemindersConfigured(
            globalEnabled: settings.globalEnabled,
            eyesEnabled: settings.eyesEnabled,
            postureEnabled: settings.postureEnabled
        )
    }

    static func statusLocalizationKey(
        globalEnabled: Bool,
        eyesEnabled: Bool,
        postureEnabled: Bool,
        notificationAuthStatus: UNAuthorizationStatus
    ) -> String {
        if !globalEnabled {
            return "home.status.paused"
        }
        if shouldShowNoRemindersConfigured(
            globalEnabled: globalEnabled,
            eyesEnabled: eyesEnabled,
            postureEnabled: postureEnabled
        ) {
            return "home.status.noReminders"
        }
        if shouldShowNotificationRecovery(
            globalEnabled: globalEnabled,
            notificationAuthStatus: notificationAuthStatus
        ) {
            return "home.status.notificationsOff"
        }
        return "home.status.active"
    }

    static func shouldShowNotificationRecovery(
        globalEnabled: Bool,
        notificationAuthStatus: UNAuthorizationStatus
    ) -> Bool {
        globalEnabled && notificationAuthStatus == .denied
    }

    static func shouldShowNoRemindersConfigured(
        globalEnabled: Bool,
        eyesEnabled: Bool,
        postureEnabled: Bool
    ) -> Bool {
        globalEnabled && !eyesEnabled && !postureEnabled
    }

    private var shouldShowTrueInterruptPrompts: Bool {
        if coordinator.screenTimeAuthorization.authorizationStatus == .notDetermined {
            return true
        }
#if DEBUG
        if uiTestScreenTimeStatusRaw == ScreenTimeAuthorizationStatus.notDetermined.rawValue {
            return true
        }
        if Self.resolveShouldShowUITestScreenTimePrompt(
            launchArguments: launchArguments,
            launchArgumentsProvider: launchArgumentsProvider,
            processEnvironment: processEnvironment,
            processEnvironmentProvider: processEnvironmentProvider
        ) {
            return true
        }
#endif
        return false
    }

    private var effectiveTrueInterruptBannerDismissed: Bool {
#if DEBUG
        if let uiTestDismissed = Self.resolveUITestTrueInterruptBannerDismissed(
            processEnvironment: processEnvironment,
            processEnvironmentProvider: processEnvironmentProvider
        ) {
            return uiTestDismissed
        }
#endif
        return trueInterruptBannerDismissed
    }

#if DEBUG
    static func resolveUITestTrueInterruptBannerDismissed(
        launchArguments: [String]? = nil,
        launchArgumentsProvider: LaunchArgumentsProvider = { CommandLine.arguments },
        processEnvironment: [String: String]? = nil,
        processEnvironmentProvider: ProcessEnvironmentProvider = { ProcessInfo.processInfo.environment }
    ) -> Bool? {
        let resolvedLaunchArguments = launchArguments ?? launchArgumentsProvider()
        if resolvedLaunchArguments.contains("--show-true-interrupt-banner") {
            return false
        }
        if resolvedLaunchArguments.contains("--dismiss-true-interrupt-banner") {
            return true
        }

        let resolvedProcessEnvironment = processEnvironment ?? processEnvironmentProvider()
        switch resolvedProcessEnvironment["UITEST_TRUE_INTERRUPT_BANNER_DISMISSED"] {
        case "true":
            return true
        case "false":
            return false
        default:
            return nil
        }
    }

    static func resolveShouldShowUITestScreenTimePrompt(
        launchArguments: [String]? = nil,
        launchArgumentsProvider: LaunchArgumentsProvider = { CommandLine.arguments },
        processEnvironment: [String: String]? = nil,
        processEnvironmentProvider: ProcessEnvironmentProvider = { ProcessInfo.processInfo.environment }
    ) -> Bool {
        let resolvedLaunchArguments = launchArguments ?? launchArgumentsProvider()
        if resolvedLaunchArguments.contains("--simulate-screen-time-not-determined") {
            return true
        }
        let resolvedProcessEnvironment = processEnvironment ?? processEnvironmentProvider()
        return resolvedProcessEnvironment["UITEST_SCREEN_TIME_STATUS"] == "notDetermined"
    }
#endif

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            VStack(spacing: AppSpacing.lg) {
                YinYangEyeView()

                // Status copy crossfades as a unit when globalEnabled changes.
                ZStack {
                    VStack(spacing: AppSpacing.sm) {
                        Text("home.title", bundle: .module)
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("home.title")

                        Text(statusLabel)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("home.statusLabel")
                    }
                    .id(settings.globalEnabled)
                    .transition(.opacity)
                }
                .animation(reduceMotion ? nil : AppAnimation.statusCrossfadeCurve, value: settings.globalEnabled)
            }

            Spacer()

            // Post-onboarding True Interrupt discoverability banner (#258).
            // Shown only when setup was skipped (notDetermined) and not yet dismissed.
            if shouldShowTrueInterruptPrompts,
               !effectiveTrueInterruptBannerDismissed {
                TrueInterruptSkippedBanner(
                    onSetUp: {
                        trueInterruptBannerDismissed = true
                        showSettings = true
                    },
                    onDismiss: {
                        trueInterruptBannerDismissed = true
                    }
                )
            }

            // Persistent low-noise rediscovery affordance (#280).
            // Shown after the banner is dismissed while setup is still pending.
            if shouldShowTrueInterruptPrompts,
               effectiveTrueInterruptBannerDismissed {
                TrueInterruptSetupPill(onTap: { showSettings = true })
            }

            if shouldShowNotificationRecovery && !shouldShowNoRemindersConfigured {
                HomeNotificationWarningBanner(onOpenSettings: openApplicationSettings)
            }

            if shouldShowNoRemindersConfigured {
                HomeNoRemindersConfiguredBanner(onOpenSettings: { showSettings = true })
            }
        }
        .padding(.horizontal, AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(Text("home.navTitle", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: AppSymbol.settings)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppColor.primaryRest)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(Text("home.settingsButton", bundle: .module))
                .accessibilityHint(Text("home.settingsButton.hint", bundle: .module))
                .accessibilityIdentifier("home.settingsButton")
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(isPresented: $showSettings)
                    .environmentObject(settings)
                    .environmentObject(coordinator)
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .onAppear {
            if openSettingsOnLaunch {
                openSettingsOnLaunch = false
                showSettings = true
            }
        }
        .task {
            await coordinator.refreshAuthStatus()
        }
        .onChangeCompat(of: openSettingsOnLaunch) { newValue in
            if newValue {
                openSettingsOnLaunch = false
                showSettings = true
            }
        }
        // Announce master-toggle state changes to VoiceOver (#287).
        // Guard prevents double-announcement while SettingsView sheet is open.
        .onChangeCompat(of: settings.globalEnabled) { _ in
            guard !showSettings else { return }
            accessibilityNotificationPoster.postAnnouncement(message: statusLabel)
        }
    }

    private func openApplicationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Notification Warning Banner

struct HomeNotificationWarningBanner: View {
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                IconContainer(icon: AppSymbol.warning, color: AppColor.accentWarm, size: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("home.notifications.disabledTitle", bundle: .module)
                        .font(AppFont.bodyEmphasized)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("home.notifications.disabledBody", bundle: .module)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: onOpenSettings) {
                Text("settings.notifications.openSettings", bundle: .module)
                    .font(AppFont.captionEmphasized)
            }
            .frame(minHeight: AppLayout.minTapTarget)
            .contentShape(Rectangle())
            .foregroundStyle(AppColor.accentWarm)
            .accessibilityHint(Text("settings.notifications.openSettings.hint", bundle: .module))
            .accessibilityIdentifier("home.notifications.openSettings")
        }
        .padding(AppSpacing.sm)
        .background(AppColor.accentWarm.opacity(AppOpacity.warningBackground),
                    in: RoundedRectangle(cornerRadius: AppLayout.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.radiusSmall)
                .strokeBorder(AppColor.accentWarm.opacity(AppOpacity.warningSeparator),
                              lineWidth: AppLayout.borderHair)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.notifications.disabledBanner")
    }
}

// MARK: - No Reminders Configured Banner

struct HomeNoRemindersConfiguredBanner: View {
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                IconContainer(icon: AppSymbol.warning, color: AppColor.accentWarm, size: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("home.noReminders.title", bundle: .module)
                        .font(AppFont.bodyEmphasized)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("home.noReminders.body", bundle: .module)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: onOpenSettings) {
                Text("home.noReminders.openSettings", bundle: .module)
                    .font(AppFont.captionEmphasized)
            }
            .frame(minHeight: AppLayout.minTapTarget)
            .contentShape(Rectangle())
            .foregroundStyle(AppColor.accentWarm)
            .accessibilityHint(Text("home.noReminders.openSettings.hint", bundle: .module))
            .accessibilityIdentifier("home.noReminders.openSettings")
        }
        .padding(AppSpacing.sm)
        .background(AppColor.accentWarm.opacity(AppOpacity.warningBackground),
                    in: RoundedRectangle(cornerRadius: AppLayout.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.radiusSmall)
                .strokeBorder(AppColor.accentWarm.opacity(AppOpacity.warningSeparator),
                              lineWidth: AppLayout.borderHair)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.noReminders.configuredBanner")
    }
}

// MARK: - True Interrupt Setup Pill

/// Persistent, low-noise rediscovery affordance shown on Home after the
/// `TrueInterruptSkippedBanner` is dismissed while True Interrupt setup
/// is still pending (#280). Tapping opens Settings.
struct TrueInterruptSetupPill: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: AppSymbol.trueInterrupt)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.primaryRest)
                    .accessibilityHidden(true)
                Text("home.trueInterrupt.setupPill", bundle: .module)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.primaryRest)
                Image(systemName: AppSymbol.chevronTrailing)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.primaryRest)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColor.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(AppColor.separatorSoft, lineWidth: AppLayout.borderHair))
        }
        .frame(minHeight: AppLayout.minTapTarget)
        .contentShape(Rectangle())
        .accessibilityLabel(Text("home.trueInterrupt.setupPill", bundle: .module))
        .accessibilityHint(Text("home.trueInterrupt.setupPill.hint", bundle: .module))
        .accessibilityIdentifier("home.trueInterrupt.setupPill")
    }
}

// MARK: - True Interrupt Skipped Banner

/// Non-blocking callout shown on Home when the user skipped True Interrupt setup
/// during onboarding and the feature is in the notDetermined state (#258).
///
/// The banner is dismiss-safe: tapping "Dismiss" persists the choice via
/// `@AppStorage` so it never reappears. Tapping "Set Up True Interrupt" opens
/// Settings where the user can configure the feature at any time.
///
/// Accepts plain callbacks so the struct has no `@EnvironmentObject` dependency
/// and can be instantiated directly in unit tests.
struct TrueInterruptSkippedBanner: View {
    let onSetUp: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: AppSymbol.trueInterrupt)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.primaryRest)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("home.trueInterrupt.skippedBanner.body", bundle: .module)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppSpacing.sm) {
                    Button(action: onSetUp) {
                        Text("home.trueInterrupt.skippedBanner.setUp", bundle: .module)
                            .font(AppFont.captionEmphasized)
                    }
                    .frame(minHeight: AppLayout.minTapTarget)
                    .contentShape(Rectangle())
                    .foregroundStyle(AppColor.primaryRest)
                    .accessibilityHint(Text("home.trueInterrupt.skippedBanner.setUp.hint", bundle: .module))
                    .accessibilityIdentifier("home.trueInterrupt.skippedBanner.setUp")

                    Button(action: onDismiss) {
                        Text("home.trueInterrupt.skippedBanner.dismiss", bundle: .module)
                            .font(AppFont.caption)
                    }
                    .frame(minHeight: AppLayout.minTapTarget)
                    .contentShape(Rectangle())
                    .foregroundStyle(AppColor.textSecondary)
                    .accessibilityHint(Text("home.trueInterrupt.skippedBanner.dismiss.hint", bundle: .module))
                    .accessibilityIdentifier("home.trueInterrupt.skippedBanner.dismiss")
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppLayout.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.radiusSmall)
                .strokeBorder(AppColor.separatorSoft, lineWidth: AppLayout.borderHair)
        )
    }
}

#Preview {
    let coordinator = AppCoordinator()
    NavigationStack {
        HomeView()
            .environmentObject(coordinator.settings)
            .environmentObject(coordinator)
    }
}
