// OnboardingView.swift
// kshana
//
// Main onboarding container — 4-screen TabView with page indicator.
//
// The view consumes a scoped `StoreOf<OnboardingFeature>` (TCA migration
// landed in `#755` Phase C, originally tracked as `#702` Phase 5). The
// `finishOnboarding()` / `finishOnboardingAndCustomize()` instance
// methods are button-handler entry points that emit the
// `.onboardingCompleted` analytics event directly via `AnalyticsLogger`
// to keep the #324 single-event invariant cleanly testable from
// unit-test processes without bootstrapping a TCA `TestStore`. Status
// fields (notification + Screen Time authorisation) are sourced from
// `OnboardingFeature.State`, refreshed via `.onAppear` and the injected
// `NotificationClient` / `ScreenTimeAuthorizationClient` dependency
// clients.

import ComposableArchitecture
import SwiftUI
import UIKit

struct OnboardingView: View {
    typealias AccessibilityNotificationPosterFactory = () -> AccessibilityNotificationPosting

    @Perception.Bindable var store: StoreOf<OnboardingFeature>
    @State private var showAppCategoryPicker = false

    private let accessibilityNotificationPoster: AccessibilityNotificationPosting

    init(
        store: StoreOf<OnboardingFeature> = Store(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        },
        accessibilityNotificationPoster: AccessibilityNotificationPosting? = nil,
        makeAccessibilityNotificationPoster: @escaping AccessibilityNotificationPosterFactory = {
            LiveAccessibilityNotificationPoster()
        }
    ) {
        self.store = store
        self.accessibilityNotificationPoster =
            accessibilityNotificationPoster ?? makeAccessibilityNotificationPoster()
    }

    private static let configurePageControl: Void = {
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(AppColor.primaryRest)
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(AppColor.separatorSoft)
    }()

    var body: some View {
        WithPerceptionTracking {
            TabView(selection: pageBinding) {
                OnboardingWelcomeView(onNext: { store.send(.nextTapped) })
                    .tag(0)
                // Notification permission flows through the reducer's
                // `.requestNotificationPermission` effect (which uses the
                // injected `NotificationClient`), so the view does not
                // thread a `UNUserNotificationCenter` instance through.
                OnboardingPermissionView(
                    onNext: { store.send(.nextTapped) },
                    requestPermission: {
                        store.send(.requestNotificationPermission)
                    }
                )
                    .tag(1)
                // Picker bindings inside `OnboardingSetupView` now write
                // directly to `@AppStorage(SettingsStore.Keys.*)` — no
                // `SettingsStore` environment object required.
                OnboardingSetupView(onGetStarted: { store.send(.nextTapped) })
                    .tag(2)
                // True Interrupt Mode introduction. The pre-permission copy
                // and the disabled-button gating are driven by the reducer's
                // `screenTimeStatus`, which is seeded on `.onAppear` via
                // `ScreenTimeAuthorizationClient`.
                OnboardingInterruptModeView(
                    onGetStarted: finishOnboarding,
                    onSetUp: onboardingSetUpAction,
                    onCustomize: finishOnboardingAndCustomize,
                    authorizationStatus: store.screenTimeStatus
                )
                    .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .background(AppColor.background.ignoresSafeArea())
            .onAppear {
                _ = Self.configurePageControl
                store.send(.onAppear)
            }
            .onChangeCompat(of: store.currentPage) { _ in
                accessibilityNotificationPoster.postScreenChanged()
            }
            .sheet(isPresented: $showAppCategoryPicker) {
                OnboardingAppCategoryPickerSheet(onSelectApps: {})
            }
        }
    }

    /// Two-way binding to `OnboardingFeature.State.currentPage`.
    ///
    /// Reads pull the latest reducer-owned value (so `.nextTapped` driven
    /// transitions reflect immediately); writes round-trip through
    /// `.pageChanged` so swipe-driven page changes mutate state through the
    /// same reducer pathway as tap-driven navigation.
    private var pageBinding: Binding<Int> {
        Binding(
            get: { store.currentPage },
            set: { store.send(.pageChanged($0)) }
        )
    }

    private var onboardingSetUpAction: (() -> Void)? {
        store.screenTimeStatus == .unavailable
            ? nil
            : { showAppCategoryPicker = true }
    }

    func finishOnboarding() {
        // Direct AnalyticsLogger emit preserves the synchronous test-handler
        // contract (#324 single-event invariant). Reducer-side TCA tests
        // continue to drive `.finishTapped` for the same emission; Phase D
        // collapses both paths once `RootView` owns the button wiring.
        AnalyticsLogger.log(.onboardingCompleted(cta: .getStarted))
        accessibilityNotificationPoster.postScreenChanged()
        markOnboardingComplete()
    }

    /// Completes onboarding and signals HomeView to open the Settings sheet immediately.
    /// Sets `openSettingsOnLaunch` so HomeView auto-opens Settings on first appear.
    func finishOnboardingAndCustomize() {
        // Direct AnalyticsLogger emit — see `finishOnboarding()` for the
        // single-event invariant note (#324).
        AnalyticsLogger.log(.onboardingCompleted(cta: .customize))
        UserDefaults.standard.set(true, forKey: AppStorageKey.openSettingsOnLaunch)
        accessibilityNotificationPoster.postScreenChanged()
        markOnboardingComplete()
    }

    /// Shared persistence step: marks onboarding done without emitting an analytics event.
    /// Both `finishOnboarding()` and `finishOnboardingAndCustomize()` call this so each
    /// path emits exactly one `.onboardingCompleted` event with the correct CTA.
    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: AppStorageKey.hasSeenOnboarding)
    }
}

// MARK: - AppCategoryPicker Sheet Wrapper

/// Owns a local `Store` for `AppCategoryPickerView` while the onboarding
/// flow's app-category picker presentation is still view-owned. When
/// `#755` Phase D wires `RootView` as the destination owner, this wrapper
/// is removed and the picker is presented via `$store.scope(...)` against
/// `AppFeature.Destination.appCategoryPicker`.
private struct OnboardingAppCategoryPickerSheet: View {
    let onSelectApps: () -> Void

    @State private var store = Store(
        initialState: AppCategoryPickerFeature.State()
    ) { AppCategoryPickerFeature() }

    var body: some View {
        AppCategoryPickerView(store: store, onSelectApps: onSelectApps)
    }
}

// MARK: - Shared Onboarding Styles

// OnboardingSecondaryButtonStyle moved to Components.swift

// MARK: - Animation Helper

// OnboardingScreenWrapper replaced by .calmingEntrance() from Components.swift

#Preview {
    OnboardingView()
}
