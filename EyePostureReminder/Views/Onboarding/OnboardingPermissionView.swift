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
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)

                    // Explanation + reassurance copy
                    VStack(spacing: AppSpacing.md) {
                        Text("onboarding.permission.body1", bundle: .module)
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.textSecondary)
                            .multilineTextAlignment(.center)

                        Text("onboarding.permission.body2", bundle: .module)
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, AppSpacing.sm)

                    Spacer(minLength: AppSpacing.lg)

                    // Primary CTA — triggers system permission prompt
                    Button(action: requestNotificationPermission) {
                        Text("onboarding.permission.enableButton", bundle: .module)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                    .padding(.horizontal, AppSpacing.xl)
                    .accessibilityLabel(Text("onboarding.permission.enableButton", bundle: .module))
                    .accessibilityHint(Text("onboarding.permission.enableButton.hint", bundle: .module))

                    // Secondary option — no system prompt, just advance
                    Button(action: onNext) {
                        Text("onboarding.permission.skipButton", bundle: .module)
                    }
                        .buttonStyle(OnboardingSecondaryButtonStyle())
                        .accessibilityLabel(Text("onboarding.permission.skipButton", bundle: .module))
                        .accessibilityHint(Text("onboarding.permission.skipButton.hint", bundle: .module))
                        .accessibilityIdentifier("onboarding.permission.nextButton")
                }
                .padding()
                .frame(maxWidth: AppLayout.onboardingMaxContentWidth)
                .frame(maxWidth: .infinity)
                // Use highPriorityGesture so this view consumes horizontal drags
                // before the parent TabView sees them, preventing accidental swipe
                // past the permission screen.
                .highPriorityGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { _ in }
                )
            }
            .background(AppColor.background.ignoresSafeArea())
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
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: AppSymbol.eyeBreak)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.primaryRest)
                    .frame(width: AppLayout.minTapTarget, height: AppLayout.minTapTarget)
                    .background(
                        RoundedRectangle(cornerRadius: AppLayout.radiusSmall, style: .continuous)
                            .fill(AppColor.surfaceTint)
                    )
                    .accessibilityHidden(true)
                Text("onboarding.permission.notificationCard.appName", bundle: .module)
                    .font(AppFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text("onboarding.permission.notificationCard.now", bundle: .module)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.textSecondary.opacity(0.72))
            }
            Text("onboarding.permission.notificationCard.title", bundle: .module)
                .font(AppFont.bodyEmphasized)
                .foregroundStyle(AppColor.textPrimary)
            Text("onboarding.permission.notificationCard.body", bundle: .module)
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(AppSpacing.lg)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppLayout.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.radiusCard, style: .continuous)
                .strokeBorder(AppColor.separatorSoft, lineWidth: 1)
        )
        .softElevation()
        .padding(.horizontal, AppSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("onboarding.permission.notificationCard.label", bundle: .module))
    }
}

#Preview {
    OnboardingPermissionView { }
}
