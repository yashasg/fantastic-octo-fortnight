// OnboardingView.swift
// Eye & Posture Reminder
//
// Main onboarding container — 3-screen TabView with page indicator.

import SwiftUI
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var currentPage = 0

    init() {
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(AppColor.primaryRest)
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(AppColor.separatorSoft)
    }

    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingWelcomeView { currentPage = 1 }
                .tag(0)
            // Inject the coordinator's notification center so the permission
            // request can be driven by a mock in UI tests without swizzling.
            OnboardingPermissionView(
                notificationCenter: coordinator.notificationCenter
            ) { currentPage = 2 }
                .tag(1)
            OnboardingSetupView(
                onGetStarted: finishOnboarding,
                onCustomize: finishOnboardingAndCustomize
            )
            .tag(2)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        .background(AppColor.background.ignoresSafeArea())
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: AppStorageKey.hasSeenOnboarding)
    }

    private func finishOnboardingAndCustomize() {
        UserDefaults.standard.set(true, forKey: AppStorageKey.openSettingsOnLaunch)
        UserDefaults.standard.set(true, forKey: AppStorageKey.hasSeenOnboarding)
    }
}

// MARK: - Shared Onboarding Styles

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.bodyEmphasized)
            .foregroundStyle(AppColor.background)
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.lg)
            .frame(minHeight: AppLayout.minTapTarget)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.radiusPill, style: .continuous)
                    .fill(AppColor.primaryRest)
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.secondaryAction)
            .foregroundStyle(AppColor.textSecondary)
            .frame(minHeight: AppLayout.minTapTarget)
            .padding(.horizontal, AppSpacing.md)
            .opacity(configuration.isPressed ? 0.68 : 1)
    }
}

// MARK: - Animation Helper

/// Wraps any onboarding screen content with a fade-in entrance animation.
/// Respects `accessibilityReduceMotion` — when enabled, sets opacity immediately without animation.
struct OnboardingScreenWrapper<Content: View>: View {
    @State private var appeared = false
    @State private var hasEverAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .opacity(appeared ? 1 : 0)
            .onAppear {
                guard !hasEverAppeared else { appeared = true; return }
                hasEverAppeared = true
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(AppAnimation.onboardingFadeInCurve) {
                        appeared = true
                    }
                }
            }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppCoordinator())
}
