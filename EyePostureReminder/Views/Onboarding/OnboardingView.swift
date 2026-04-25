// OnboardingView.swift
// Eye & Posture Reminder
//
// Main onboarding container — 3-screen TabView with page indicator.

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingWelcomeView { currentPage = 1 }
                .tag(0)
            OnboardingPermissionView { currentPage = 2 }
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
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
    }

    private func finishOnboardingAndCustomize() {
        UserDefaults.standard.set(true, forKey: "openSettingsOnLaunch")
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
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
            .offset(y: (appeared || reduceMotion) ? 0 : 20)
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
}
