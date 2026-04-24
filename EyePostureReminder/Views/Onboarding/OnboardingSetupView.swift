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
                        Text("You're all set.")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("Here's how we've set things up for you:")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Default settings preview cards
                    VStack(spacing: AppSpacing.md) {
                        SetupPreviewCard(
                            icon: AppSymbol.eyeBreak,
                            color: .indigo,
                            title: "Eye Breaks",
                            interval: "20 min",
                            duration: "20 seconds"
                        )
                        SetupPreviewCard(
                            icon: AppSymbol.postureCheck,
                            color: .green,
                            title: "Posture Checks",
                            interval: "30 min",
                            duration: "10 seconds"
                        )
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Reassurance copy
                    Text("You'll get a gentle reminder to look away and sit up straight — no effort required from you.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.sm)

                    Spacer(minLength: AppSpacing.lg)

                    // Primary CTA
                    Button(action: onGetStarted) {
                        Text("Get Started")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.indigo)
                    .padding(.horizontal, AppSpacing.xl)
                    .accessibilityLabel("Get Started")
                    .accessibilityHint("Dismiss setup and begin using the app")

                    // Secondary option
                    Button("Customize settings", action: onCustomize)
                        .foregroundStyle(.indigo)
                        .font(.subheadline)
                        .accessibilityLabel("Customize settings")
                        .accessibilityHint("Go to settings to adjust reminder intervals")
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
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack(spacing: AppSpacing.sm) {
                    Label(interval, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(duration, systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): every \(interval), \(duration) break")
    }
}

#Preview {
    OnboardingSetupView(onGetStarted: {}, onCustomize: {})
}
