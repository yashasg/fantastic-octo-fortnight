// OnboardingWelcomeView.swift
// kshana
//
// Onboarding Screen 1 — Welcome. Establishes context and sets a warm tone.

import SwiftUI

struct OnboardingWelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Spacer(minLength: AppSpacing.xl)

                    YinYangEyeView()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("onboarding.welcome.illustrationLabel", bundle: .module))

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
                    .buttonStyle(.primary)
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
            .calmingEntrance()
    }
}

#Preview {
    OnboardingWelcomeView(onNext: { })
}
