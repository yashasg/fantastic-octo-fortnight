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
                            .foregroundStyle(.indigo)
                            .accessibilityHidden(true)
                        Image(systemName: AppSymbol.postureCheck)
                            .font(.system(size: 72))
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                    }
                    .padding(AppSpacing.xl)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Eye break and posture check icons")

                    // Headline + Subheadline
                    VStack(spacing: AppSpacing.sm) {
                        Text("Welcome to Eye & Posture Reminder")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("Small, helpful nudges to rest your eyes and sit up straight.")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Value proposition body
                    Text("Takes less than a minute to set up. Works quietly in the background — you'll barely know it's there.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.sm)

                    Spacer(minLength: AppSpacing.lg)

                    // Next CTA
                    Button(action: onNext) {
                        Text("Next")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.indigo)
                    .padding(.horizontal, AppSpacing.xl)
                    .accessibilityLabel("Next")
                    .accessibilityHint("Go to notifications screen")
                }
                .padding()
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    OnboardingWelcomeView(onNext: {})
}
