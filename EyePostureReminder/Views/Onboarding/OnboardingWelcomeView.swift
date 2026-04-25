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

                    // Illustration
                    HStack(spacing: AppSpacing.lg) {
                        Image(systemName: AppSymbol.eyeBreak)
                            .font(.system(size: 72))
                            .foregroundStyle(AppColor.reminderBlue)
                            .accessibilityHidden(true)
                        Image(systemName: AppSymbol.postureCheck)
                            .font(.system(size: 72))
                            .foregroundStyle(AppColor.reminderGreen)
                            .accessibilityHidden(true)
                    }
                    .padding(AppSpacing.xl)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("onboarding.welcome.illustrationLabel", bundle: .module))

                    // Headline + Subheadline
                    VStack(spacing: AppSpacing.sm) {
                        Text("onboarding.welcome.title", bundle: .module)
                            .font(AppFont.headline)
                            .multilineTextAlignment(.center)

                        Text("onboarding.welcome.subtitle", bundle: .module)
                            .font(AppFont.bodyEmphasized)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Value proposition body
                    Text("onboarding.welcome.body", bundle: .module)
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.sm)

                    Spacer(minLength: AppSpacing.lg)

                    // Next CTA
                    Button(action: onNext) {
                        Text("onboarding.welcome.nextButton", bundle: .module)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppColor.reminderBlue)
                    .padding(.horizontal, AppSpacing.xl)
                    .accessibilityLabel(Text("onboarding.welcome.nextButton", bundle: .module))
                    .accessibilityHint(Text("onboarding.welcome.nextButton.hint", bundle: .module))
                }
                .padding()
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    OnboardingWelcomeView { }
}
