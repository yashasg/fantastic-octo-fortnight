// OnboardingWelcomeView.swift
// Eye & Posture Reminder
//
// Onboarding Screen 1 — Welcome. Establishes context and sets a warm tone.

import SwiftUI

struct OnboardingWelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingScreenWrapper {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Spacer(minLength: AppSpacing.xl)

                    WelcomeHeroCard()

                    // Headline + Subheadline
                    VStack(spacing: AppSpacing.sm) {
                        Text("onboarding.welcome.title", bundle: .module)
                            .font(AppFont.headline)
                            .foregroundStyle(AppColor.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("onboarding.welcome.subtitle", bundle: .module)
                            .font(AppFont.bodyEmphasized)
                            .foregroundStyle(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Value proposition body
                    Text("onboarding.welcome.body", bundle: .module)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.sm)

                    // Legal disclaimer
                    Text("onboarding.welcome.disclaimer", bundle: .module)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            AppColor.surfaceTint,
                            in: RoundedRectangle(cornerRadius: AppLayout.radiusCard, style: .continuous)
                        )
                        .accessibilityIdentifier("onboarding.welcome.disclaimer")

                    Spacer(minLength: AppSpacing.lg)

                    // Next CTA
                    Button(action: onNext) {
                        Text("onboarding.welcome.nextButton", bundle: .module)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                    .padding(.horizontal, AppSpacing.xl)
                    .accessibilityLabel(Text("onboarding.welcome.nextButton", bundle: .module))
                    .accessibilityHint(Text("onboarding.welcome.nextButton.hint", bundle: .module))
                    .accessibilityIdentifier("onboarding.welcome.nextButton")
                }
                .padding()
                .frame(maxWidth: AppLayout.onboardingMaxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .background(AppColor.background.ignoresSafeArea())
        }
    }
}

// MARK: - Welcome Hero Card

private struct WelcomeHeroCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppLayout.radiusLarge, style: .continuous)
                .fill(AppColor.surface)

            Circle()
                .fill(AppColor.accentWarm.opacity(0.16))
                .frame(width: 86, height: 86)
                .offset(x: 94, y: -48)
                .accessibilityHidden(true)

            Circle()
                .fill(AppColor.surfaceTint)
                .frame(width: 64, height: 64)
                .offset(x: -104, y: 52)
                .accessibilityHidden(true)

            HStack(spacing: AppSpacing.lg) {
                HeroIcon(
                    systemName: AppSymbol.eyeBreak,
                    tint: AppColor.primaryRest,
                    yOffset: -AppSpacing.xs
                )
                HeroIcon(
                    systemName: AppSymbol.postureCheck,
                    tint: AppColor.secondaryCalm,
                    yOffset: AppSpacing.xs
                )
            }
            .padding(AppSpacing.xl)
        }
        .frame(maxWidth: 320, minHeight: 188)
        .softElevation()
        .padding(.horizontal, AppSpacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("onboarding.welcome.illustrationLabel", bundle: .module))
    }
}

private struct HeroIcon: View {
    let systemName: String
    let tint: Color
    let yOffset: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: AppLayout.onboardingIllustrationSize, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 108, height: 108)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.radiusLarge, style: .continuous)
                    .fill(AppColor.surfaceTint)
            )
            .offset(y: yOffset)
            .accessibilityHidden(true)
    }
}

#Preview {
    OnboardingWelcomeView { }
}
