// OnboardingPermissionView.swift
// Eye & Posture Reminder
//
// Onboarding Screen 2 — Notification Permission.
// Educates the user about WHY notifications are needed before triggering the system prompt.

import SwiftUI
import UserNotifications

struct OnboardingPermissionView: View {
    let onNext: () -> Void
    private let notificationCenter: NotificationScheduling

    init(onNext: @escaping () -> Void,
         notificationCenter: NotificationScheduling = UNUserNotificationCenter.current()) {
        self.onNext = onNext
        self.notificationCenter = notificationCenter
    }

    var body: some View {
        OnboardingScreenWrapper {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Spacer(minLength: AppSpacing.xl)

                    // Mock notification preview card
                    NotificationPreviewCard()

                    // Headline
                    Text("onboarding.permission.title", bundle: .module)
                        .font(AppFont.headline)
                        .multilineTextAlignment(.center)

                    // Explanation + reassurance copy
                    VStack(spacing: AppSpacing.md) {
                        Text("onboarding.permission.body1", bundle: .module)
                            .font(AppFont.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Text("onboarding.permission.body2", bundle: .module)
                            .font(AppFont.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, AppSpacing.sm)

                    Spacer(minLength: AppSpacing.lg)

                    // Primary CTA — triggers system permission prompt
                    Button(action: requestNotificationPermission) {
                        Text("onboarding.permission.enableButton", bundle: .module)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppColor.reminderBlue)
                    .padding(.horizontal, AppSpacing.xl)
                    .accessibilityLabel(Text("onboarding.permission.enableButton", bundle: .module))
                    .accessibilityHint(Text("onboarding.permission.enableButton.hint", bundle: .module))

                    // Secondary option — no system prompt, just advance
                    Button(action: onNext) {
                        Text("onboarding.permission.skipButton", bundle: .module)
                            .frame(minHeight: 44)
                    }
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .accessibilityLabel(Text("onboarding.permission.skipButton", bundle: .module))
                        .accessibilityHint(Text("onboarding.permission.skipButton.hint", bundle: .module))
                        .accessibilityIdentifier("onboarding.permission.nextButton")
                }
                .padding()
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
                // Use simultaneousGesture so the parent TabView cannot be
                // swiped past this screen while the ScrollView remains scrollable.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { _ in }
                )
            }
        }
    }

    private func requestNotificationPermission() {
        Task {
            _ = try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { onNext() }
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
                    .foregroundStyle(AppColor.reminderBlue)
                    .font(AppFont.caption)
                Text("onboarding.permission.notificationCard.appName", bundle: .module)
                    .font(AppFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("onboarding.permission.notificationCard.now", bundle: .module)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text("onboarding.permission.notificationCard.title", bundle: .module)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("onboarding.permission.notificationCard.body", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, AppSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("onboarding.permission.notificationCard.label", bundle: .module))
    }
}

#Preview {
    OnboardingPermissionView { }
}
