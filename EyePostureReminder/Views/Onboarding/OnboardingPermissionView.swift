// OnboardingPermissionView.swift
// Eye & Posture Reminder
//
// Onboarding Screen 2 — Notification Permission.
// Educates the user about WHY notifications are needed before triggering the system prompt.

import SwiftUI
import UserNotifications

struct OnboardingPermissionView: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingScreenWrapper {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Spacer(minLength: AppSpacing.xl)

                    // Mock notification preview card
                    NotificationPreviewCard()

                    // Headline
                    Text("Stay on track,\neffortlessly.")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    // Explanation + reassurance copy
                    VStack(spacing: AppSpacing.md) {
                        Text("Reminders arrive as notifications — so the app works even when you're not looking at it.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Text("No spam. Just the breaks you asked for, when you need them.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, AppSpacing.sm)

                    Spacer(minLength: AppSpacing.lg)

                    // Primary CTA — triggers system permission prompt
                    Button(action: requestNotificationPermission) {
                        Text("Enable Notifications")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.indigo)
                    .padding(.horizontal, AppSpacing.xl)
                    .accessibilityLabel("Enable Notifications")
                    .accessibilityHint("Opens system notification permission prompt")

                    // Secondary option — no system prompt, just advance
                    Button("Maybe Later", action: onNext)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .accessibilityLabel("Maybe Later")
                        .accessibilityHint("Skip for now, you can enable notifications later in Settings")
                }
                .padding()
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in
            DispatchQueue.main.async {
                onNext()
            }
        }
    }
}

// MARK: - Notification Preview Card

/// A styled visual mock of an iOS notification to set user expectations.
private struct NotificationPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: AppSymbol.eyeBreak)
                    .foregroundStyle(.indigo)
                    .font(.caption)
                Text("Eye & Posture Reminder")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("now")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text("Eye Break")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("Time to rest your eyes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, AppSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example notification: Eye Break — Time to rest your eyes.")
    }
}

#Preview {
    OnboardingPermissionView(onNext: {})
}
