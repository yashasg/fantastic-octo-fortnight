// OnboardingInterruptModeView.swift
// kshana
//
// Onboarding Screen 4 — True Interrupt Mode.
// Educates the user about Screen Time access before the feature is available,
// sets honest expectations while #201 (FamilyControls entitlement) is pending,
// and lets users skip without affecting core reminder functionality.

import SwiftUI

/// Fourth onboarding screen — introduces True Interrupt Mode.
///
/// In the pre-entitlement state (`authorizationStatus == .unavailable`):
/// - Shows informational copy about what True Interrupt Mode will do.
/// - The "Set Up" button is replaced with "Coming Soon" and is disabled.
/// - Users can skip directly to the main app, or tap "Customize Settings" to
///   open Settings immediately on arrival (sets `openSettingsOnLaunch`).
///
/// Once #201 is resolved and the project gains the FamilyControls entitlement,
/// the "Set Up" button will call `onSetUp` which presents `AppCategoryPickerView`.
struct OnboardingInterruptModeView: View {
    let onGetStarted: () -> Void
    let onSetUp: (() -> Void)?
    /// Called when the user taps "Customize Settings". The caller is responsible
    /// for setting `openSettingsOnLaunch = true` before invoking `finishOnboarding()`.
    let onCustomize: (() -> Void)?
    let authorizationStatus: ScreenTimeAuthorizationStatus
    private let accessibilityEnabledOverride: Bool?

    @Environment(\.accessibilityEnabled) private var accessibilityEnabled

    init(
        onGetStarted: @escaping () -> Void,
        onSetUp: (() -> Void)? = nil,
        onCustomize: (() -> Void)? = nil,
        authorizationStatus: ScreenTimeAuthorizationStatus = .unavailable,
        accessibilityEnabledOverride: Bool? = nil
    ) {
        self.onGetStarted = onGetStarted
        self.onSetUp = onSetUp
        self.onCustomize = onCustomize
        self.authorizationStatus = authorizationStatus
        self.accessibilityEnabledOverride = accessibilityEnabledOverride
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: AppSpacing.xl)

                // Hero illustration — decorative; title conveys the screen purpose.
                Image(systemName: AppSymbol.trueInterrupt)
                    .font(AppFont.trueInterruptIcon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppColor.primaryRest)
                    .frame(
                        width: AppLayout.onboardingIllustrationSize,
                        height: AppLayout.onboardingIllustrationSize
                    )
                    .background(Circle().fill(AppColor.surfaceTint))
                    .accessibilityHidden(true)

                // Headline
                Text("onboarding.interrupt.title", bundle: .module)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)

                // Body copy
                VStack(spacing: AppSpacing.md) {
                    Text("onboarding.interrupt.body1", bundle: .module)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("onboarding.interrupt.body2", bundle: .module)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.sm)

                InterruptPrivacySummaryCard()

                // Pre-entitlement pending notice
                if authorizationStatus == .unavailable {
                    PendingApprovalBadge()
                }

                Spacer(minLength: AppSpacing.lg)

                // Primary CTA — disabled until entitlement is provisioned
                Button(
                    action: { onSetUp?() ?? onGetStarted() },
                    label: {
                        Text(primaryButtonKey, bundle: .module)
                            .frame(maxWidth: .infinity)
                    }
                )
                .buttonStyle(.primary)
                .disabled(isPrimaryButtonDisabled)
                .padding(.horizontal, AppSpacing.xl)
                .accessibilityLabel(Text(primaryButtonKey, bundle: .module))
                .accessibilityHint(
                    Text(primaryButtonHintKey, bundle: .module)
                )
                .accessibilityIdentifier("onboarding.interrupt.enableButton")

                // Skip / "Get Started without True Interrupt"
                Button(action: onGetStarted) {
                    Text("onboarding.interrupt.skipButton", bundle: .module)
                }
                .buttonStyle(.secondary)
                .accessibilityLabel(
                    Text("onboarding.interrupt.skipButton", bundle: .module)
                )
                .accessibilityHint(
                    Text("onboarding.interrupt.skipButton.hint", bundle: .module)
                )
                .accessibilityIdentifier("onboarding.interrupt.skipButton")

                // Tertiary CTA — skip and immediately open Settings for deeper customization
                if let onCustomize {
                    Button(action: onCustomize) {
                        Text("onboarding.interrupt.customizeButton", bundle: .module)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(minHeight: AppLayout.minTapTarget)
                    .contentShape(Rectangle())
                    .accessibilityLabel(
                        Text("onboarding.interrupt.customizeButton", bundle: .module)
                    )
                    .accessibilityHint(
                        Text("onboarding.interrupt.customizeButton.hint", bundle: .module)
                    )
                    .accessibilityIdentifier("onboarding.interrupt.customizeButton")
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: AppLayout.onboardingMaxContentWidth)
            .frame(maxWidth: .infinity)
            .highPriorityGesture(
                DragGesture(minimumDistance: shouldUseAccessibilityGestures ? .infinity : 10)
                    .onChanged { _ in }
            )
        }
        .background(AppColor.background.ignoresSafeArea())
        .calmingEntrance()
    }

    // MARK: - Helpers

    private var primaryButtonKey: LocalizedStringKey {
        authorizationStatus == .unavailable
            ? "onboarding.interrupt.previewButton"
            : "onboarding.interrupt.enableButton"
    }

    private var primaryButtonHintKey: LocalizedStringKey {
        authorizationStatus == .unavailable
            ? "onboarding.interrupt.previewButton.hint"
            : "onboarding.interrupt.enableButton.hint"
    }

    private var isPrimaryButtonDisabled: Bool {
        authorizationStatus == .unavailable && onSetUp == nil
    }

    private var shouldUseAccessibilityGestures: Bool {
        accessibilityEnabledOverride ?? accessibilityEnabled
    }
}

// MARK: - Privacy Summary Card

private struct InterruptPrivacySummaryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label {
                Text("onboarding.interrupt.summary.selectApps", bundle: .module)
            } icon: {
                Image(systemName: AppSymbol.checkmark)
                    .accessibilityHidden(true)
            }
            Label {
                Text("onboarding.interrupt.summary.localOnly", bundle: .module)
            } icon: {
                Image(systemName: AppSymbol.lock)
                    .accessibilityHidden(true)
            }
            Label {
                Text("onboarding.interrupt.summary.fallback", bundle: .module)
            } icon: {
                Image(systemName: AppSymbol.bell)
                    .accessibilityHidden(true)
            }
        }
        .font(AppFont.caption)
        .foregroundStyle(AppColor.textSecondary)
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wellnessCard(elevated: true)
        .padding(.horizontal, AppSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.interrupt.summaryCard")
    }
}

// MARK: - Pending Approval Badge

/// Small inline banner communicating that the feature requires pending approval.
private struct PendingApprovalBadge: View {
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: AppSymbol.clock)
                .foregroundStyle(AppColor.textSecondary)
                .accessibilityHidden(true)
            Text("onboarding.interrupt.pendingNote", bundle: .module)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wellnessCard(elevated: false)
        .padding(.horizontal, AppSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.interrupt.pendingBadge")
    }
}

#Preview {
    OnboardingInterruptModeView(onGetStarted: {})
}
