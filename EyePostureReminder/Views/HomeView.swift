import ComposableArchitecture
import SwiftUI
import UIKit
import UserNotifications

/// Home screen, wired to `HomeFeature` as part of `#755` Phase A.
///
/// The legacy `@EnvironmentObject SettingsStore` / `AppCoordinator` graph has
/// been removed from this view: every per-type enable flag, master toggle, and
/// notification auth status is now read from `StoreOf<HomeFeature>`. Local
/// `@AppStorage`-backed state (`openSettingsOnLaunch`,
/// `trueInterruptSkippedBannerDismissed`) stays in the view because
/// `HomeFeature` doesn't persist those yet; the sheet still hands off to the
/// MVVM `SettingsView`, which receives `SettingsStore` / `AppCoordinator` via
/// SwiftUI environment inheritance from `EyePostureReminderApp` until
/// `#755` Phase B migrates that surface as well.
struct HomeView: View {
    typealias LaunchArgumentsProvider = () -> [String]
    typealias ProcessEnvironmentProvider = () -> [String: String]

    @Perception.Bindable var store: StoreOf<HomeFeature>

    @State private var showSettings = false
    @AppStorage(AppStorageKey.openSettingsOnLaunch) private var openSettingsOnLaunch = false
    @AppStorage(AppStorageKey.trueInterruptSkippedBannerDismissed)
    private var trueInterruptBannerDismissed = false
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
        store: StoreOf<HomeFeature>,
        accessibilityNotificationPoster: AccessibilityNotificationPosting
            = LiveAccessibilityNotificationPoster(),
        launchArguments: [String]? = nil,
        launchArgumentsProvider: @escaping LaunchArgumentsProvider = { CommandLine.arguments },
        processEnvironment: [String: String]? = nil,
        processEnvironmentProvider: @escaping ProcessEnvironmentProvider
            = { ProcessInfo.processInfo.environment }
    ) {
        self.store = store
        self.accessibilityNotificationPoster = accessibilityNotificationPoster
        self.launchArguments = launchArguments
        self.launchArgumentsProvider = launchArgumentsProvider
        self.processEnvironment = processEnvironment
        self.processEnvironmentProvider = processEnvironmentProvider
    }

    private var statusLabel: String {
        let key = Self.statusLocalizationKey(
            globalEnabled: store.globalEnabled,
            eyesEnabled: store.eyesEnabled,
            postureEnabled: store.postureEnabled,
            notificationAuthStatus: store.notificationAuthStatus
        )
        return String(localized: String.LocalizationValue(key), bundle: .module)
    }

    private var shouldShowNotificationRecovery: Bool {
        Self.shouldShowNotificationRecovery(
            globalEnabled: store.globalEnabled,
            notificationAuthStatus: store.notificationAuthStatus
        )
    }

    private var shouldShowNoRemindersConfigured: Bool {
        Self.shouldShowNoRemindersConfigured(
            globalEnabled: store.globalEnabled,
            eyesEnabled: store.eyesEnabled,
            postureEnabled: store.postureEnabled
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
        // Pre-entitlement production builds always resolve Screen Time
        // authorization to `.unavailable` via `ScreenTimeAuthorizationNoop`,
        // so the legacy `coordinator.screenTimeAuthorization` check never
        // returned `true` outside DEBUG launch-arg overrides (#201). The
        // DEBUG paths below preserve UI-test backdoor parity until Phase 2
        // wires a real `screenTimeAuthorizationClient` observation into
        // `HomeFeature.State`.
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
        processEnvironmentProvider: ProcessEnvironmentProvider
            = { ProcessInfo.processInfo.environment }
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
        processEnvironmentProvider: ProcessEnvironmentProvider
            = { ProcessInfo.processInfo.environment }
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
        WithPerceptionTracking {
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
                        .id(store.globalEnabled)
                        .transition(.opacity)
                    }
                    .animation(
                        reduceMotion ? nil : AppAnimation.statusCrossfadeCurve,
                        value: store.globalEnabled
                    )
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
                // `SettingsView` still consumes `@EnvironmentObject
                // SettingsStore` / `AppCoordinator`; SwiftUI's automatic
                // sheet-environment inheritance from
                // `EyePostureReminderApp`'s WindowGroup-level
                // `.environmentObject(...)` chain provides them. The explicit
                // re-injection used by the pre-#755 MVVM HomeView is no
                // longer needed and would also force this view to keep its
                // own `@EnvironmentObject` declarations.
                NavigationStack {
                    SettingsView(isPresented: $showSettings)
                }
            }
            .background(AppColor.background.ignoresSafeArea())
            .onAppear {
                store.send(.onAppear)
                if openSettingsOnLaunch {
                    openSettingsOnLaunch = false
                    showSettings = true
                }
            }
            .task {
                await store.send(.task).finish()
            }
            .onChangeCompat(of: openSettingsOnLaunch) { newValue in
                if newValue {
                    openSettingsOnLaunch = false
                    showSettings = true
                }
            }
            // Announce master-toggle state changes to VoiceOver (#287).
            // Guard prevents double-announcement while SettingsView sheet is open.
            .onChangeCompat(of: store.globalEnabled) { _ in
                guard !showSettings else { return }
                accessibilityNotificationPoster.postAnnouncement(message: statusLabel)
            }
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
            .overlay(
                Capsule().strokeBorder(AppColor.separatorSoft, lineWidth: AppLayout.borderHair)
            )
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
                    .accessibilityHint(
                        Text("home.trueInterrupt.skippedBanner.setUp.hint", bundle: .module)
                    )
                    .accessibilityIdentifier("home.trueInterrupt.skippedBanner.setUp")

                    Button(action: onDismiss) {
                        Text("home.trueInterrupt.skippedBanner.dismiss", bundle: .module)
                            .font(AppFont.caption)
                    }
                    .frame(minHeight: AppLayout.minTapTarget)
                    .contentShape(Rectangle())
                    .foregroundStyle(AppColor.textSecondary)
                    .accessibilityHint(
                        Text("home.trueInterrupt.skippedBanner.dismiss.hint", bundle: .module)
                    )
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
    NavigationStack {
        HomeView(
            store: Store(initialState: HomeFeature.State()) {
                HomeFeature()
            }
        )
    }
}
