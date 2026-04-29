// OnboardingView.swift
// kshana
//
// Main onboarding container — 3-screen TabView with page indicator.

import SwiftUI
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var selectedAppsState = SelectedAppsState()
    @State private var currentPage = 0
    @State private var showAppCategoryPicker = false

    private static let configurePageControl: Void = {
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(AppColor.primaryRest)
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(AppColor.separatorSoft)
    }()

    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingWelcomeView { currentPage = 1 }
                .tag(0)
            // Inject the coordinator's notification center so the permission
            // request can be driven by a mock in UI tests without swizzling.
            OnboardingPermissionView(
                onNext: { currentPage = 2 },
                notificationCenter: coordinator.notificationCenter
            )
                .tag(1)
            // Settings store is forwarded so picker bindings write directly to
            // persisted values — no separate sync step needed before first use.
            OnboardingSetupView(onGetStarted: { currentPage = 3 })
                .environmentObject(settings)
                .tag(2)
            // True Interrupt Mode introduction — shows pre-permission copy and
            // sets honest expectations while #201 (FamilyControls entitlement)
            // is pending. Users can skip without losing core reminder functionality.
            OnboardingInterruptModeView(
                onGetStarted: finishOnboarding,
                onSetUp: { showAppCategoryPicker = true },
                authorizationStatus: coordinator.screenTimeAuthorization.authorizationStatus
            )
                .tag(3)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        .background(AppColor.background.ignoresSafeArea())
        .onAppear { _ = Self.configurePageControl }
        .sheet(isPresented: $showAppCategoryPicker) {
            AppCategoryPickerView(
                appsState: selectedAppsState,
                authorizationStatus: coordinator.screenTimeAuthorization.authorizationStatus,
                onRequestAuthorization: {
                    Task { _ = await coordinator.screenTimeAuthorization.requestAuthorization() }
                },
                onOpenSettings: openApplicationSettings,
                onDone: { showAppCategoryPicker = false }
            )
        }
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: AppStorageKey.hasSeenOnboarding)
    }

    private func openApplicationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Shared Onboarding Styles

// OnboardingSecondaryButtonStyle moved to Components.swift

// MARK: - Animation Helper

// OnboardingScreenWrapper replaced by .calmingEntrance() from Components.swift

#Preview {
    OnboardingView()
        .environmentObject(AppCoordinator())
        .environmentObject(SettingsStore())
}
