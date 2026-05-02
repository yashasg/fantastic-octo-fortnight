import SwiftUI

struct HomeView: View {

    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: AppCoordinator

    @State private var showSettings = false
    @AppStorage(AppStorageKey.openSettingsOnLaunch) private var openSettingsOnLaunch = false
    @AppStorage(AppStorageKey.trueInterruptSkippedBannerDismissed) private var trueInterruptBannerDismissed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accessibilityNotificationPoster: AccessibilityNotificationPosting

    init(accessibilityNotificationPoster: AccessibilityNotificationPosting = LiveAccessibilityNotificationPoster()) {
        self.accessibilityNotificationPoster = accessibilityNotificationPoster
    }

    private var statusLabel: String {
        if settings.globalEnabled {
            return String(localized: "home.status.active", bundle: .module)
        } else {
            return String(localized: "home.status.paused", bundle: .module)
        }
    }

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
            if coordinator.screenTimeAuthorization.authorizationStatus == .notDetermined,
               !trueInterruptBannerDismissed {
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
            if coordinator.screenTimeAuthorization.authorizationStatus == .notDetermined,
               trueInterruptBannerDismissed {
                TrueInterruptSetupPill(onTap: { showSettings = true })
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
        .accessibilityIdentifier("home.trueInterrupt.skippedBanner")
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
