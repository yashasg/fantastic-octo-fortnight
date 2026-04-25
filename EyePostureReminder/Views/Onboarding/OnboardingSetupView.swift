// OnboardingSetupView.swift
// Eye & Posture Reminder
//
// Onboarding Screen 3 — Quick Setup Preview.
// Shows the default configuration and lets the user get started or go straight to Settings.

import SwiftUI

struct OnboardingSetupView: View {
    let onGetStarted: () -> Void
    let onCustomize: () -> Void

    var body: some View {
        OnboardingScreenWrapper {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Spacer(minLength: AppSpacing.xl)

                    // Headline + subheadline
                    VStack(spacing: AppSpacing.sm) {
                        Text("onboarding.setup.title", bundle: .module)
                            .font(AppFont.headline)
                            .multilineTextAlignment(.center)

                        Text("onboarding.setup.subtitle", bundle: .module)
                            .font(AppFont.bodyEmphasized)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Default settings preview cards
                    VStack(spacing: AppSpacing.md) {
                        SetupPreviewCard(
                            icon: AppSymbol.eyeBreak,
                            color: AppColor.reminderBlue,
                            title: String(localized: "onboarding.setup.eyeBreaks.title", bundle: .module),
                            interval: String(localized: "onboarding.setup.eyeBreaks.interval", bundle: .module),
                            duration: String(localized: "onboarding.setup.eyeBreaks.duration", bundle: .module)
                        )
                        SetupPreviewCard(
                            icon: AppSymbol.postureCheck,
                            color: AppColor.reminderGreen,
                            title: String(localized: "onboarding.setup.postureChecks.title", bundle: .module),
                            interval: String(localized: "onboarding.setup.postureChecks.interval", bundle: .module),
                            duration: String(localized: "onboarding.setup.postureChecks.duration", bundle: .module)
                        )
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Reassurance copy
                    Text("onboarding.setup.body", bundle: .module)
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.sm)

                    Spacer(minLength: AppSpacing.lg)

                    // Primary CTA
                    Button(action: onGetStarted) {
                        Text("onboarding.setup.getStartedButton", bundle: .module)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppColor.reminderBlue)
                    .padding(.horizontal, AppSpacing.xl)
                    .accessibilityLabel(Text("onboarding.setup.getStartedButton", bundle: .module))
                    .accessibilityHint(Text("onboarding.setup.getStartedButton.hint", bundle: .module))
                    .accessibilityIdentifier("onboarding.setup.getStartedButton")

                    // Secondary option
                    Button(action: onCustomize) {
                        Text("onboarding.setup.customizeButton", bundle: .module)
                            .frame(minHeight: 44)
                    }
                        .foregroundStyle(AppColor.reminderBlue)
                        .font(.subheadline)
                        .accessibilityLabel(Text("onboarding.setup.customizeButton", bundle: .module))
                        .accessibilityHint(Text("onboarding.setup.customizeButton.hint", bundle: .module))
                }
                .padding()
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Setup Preview Card

/// Read-only display card showing a reminder type's default configuration.
struct SetupPreviewCard: View {
    let icon: String
    let color: Color
    let title: String
    let interval: String
    let duration: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppFont.bodyEmphasized)
                HStack(spacing: AppSpacing.sm) {
                    Label(interval, systemImage: "clock")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                    Label(duration, systemImage: "timer")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: String(localized: "onboarding.setup.card.label", bundle: .module),
                title,
                interval,
                duration
            )
        )
    }
}

#Preview {
    OnboardingSetupView(onGetStarted: {}, onCustomize: {})
}
