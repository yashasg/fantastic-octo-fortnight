// OnboardingView.swift
// Eye & Posture Reminder
//
// Main onboarding container — 3-screen TabView with page indicator.

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var currentPage = 0

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
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: AppStorageKey.hasSeenOnboarding)
    }

    private func finishOnboardingAndCustomize() {
        UserDefaults.standard.set(true, forKey: AppStorageKey.openSettingsOnLaunch)
        UserDefaults.standard.set(true, forKey: AppStorageKey.hasSeenOnboarding)
    }
}

// MARK: - Animation Helper

/// Wraps any onboarding screen content with a fade + slide-up entrance animation.
/// Respects `accessibilityReduceMotion` — when enabled, only a quick fade is used.
struct OnboardingScreenWrapper<Content: View>: View {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .opacity(appeared ? 1 : 0)
            .onAppear {
                let animation: Animation = reduceMotion
                    ? .linear(duration: 0.15)
                    : .easeOut(duration: 0.4).delay(0.1)
                withAnimation(animation) {
                    appeared = true
                }
            }
            .onDisappear {
                appeared = false
            }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppCoordinator())
}
