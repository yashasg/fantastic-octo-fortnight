import ComposableArchitecture
import SwiftUI

/// Canonical TCA root surface for the Eye & Posture Reminder app.
///
/// Wired into `EyePostureReminderApp.swift` by `#755` Phase D so the
/// onboarding gate, sheet presentations, and overlay cover are all owned
/// by the `AppFeature` store.
///
/// Responsibilities split:
/// - **Gate**: branches between `OnboardingView` and `HomeView` off of
///   `store.hasSeenOnboarding`. The `@AppStorage` bridge mirrors the
///   `UserDefaults` write `OnboardingView.finishOnboarding()` still performs
///   into a `hasSeenOnboardingChanged` action so the TCA state flips even
///   though the persistence path doesn't yet route through the reducer.
/// - **Destinations**: the `@Presents var destination` slot on
///   `AppFeature.State` is the canonical owner of the Settings sheet
///   (`#814`). `HomeView`'s gear button dispatches
///   `.home(.settingsTapped)` and `RootView`'s
///   `@AppStorage(openSettingsOnLaunch)` observer dispatches
///   `.openSettingsSheetRequested` for the `OnboardingView` /
///   `.overlaySettingsRequested` handoffs — both collapse to
///   `state.destination = .settingsSheet(...)` so the sheet store lifetime
///   tracks the destination slot. The `appCategoryPicker` cover stays as
///   scaffolding (`EmptyView()`) until #918 migrates the onboarding-owned
///   picker presentation into the destination's
///   `StoreOf<AppCategoryPickerFeature>`.
/// - **Overlay**: same scaffolding pattern as `appCategoryPicker`.
///   `OverlayManager` still owns the `UIWindow`-hosted overlay
///   presentation; `state.overlay` is currently only used as a teardown
///   sink (`#738`'s two-phase dismiss). #919 tracks swapping the UIKit
///   path for the SwiftUI `.fullScreenCover` once `OverlayView` accepts
///   `StoreOf<OverlayFeature>`.
struct RootView: View {
    @Perception.Bindable var store: StoreOf<AppFeature>
    @AppStorage(AppStorageKey.hasSeenOnboarding) private var persistedHasSeenOnboarding = false
    @AppStorage(AppStorageKey.openSettingsOnLaunch) private var persistedOpenSettingsOnLaunch = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WithPerceptionTracking {
            ZStack {
                if store.hasSeenOnboarding {
                    NavigationStack {
                        HomeView(store: store.scope(state: \.home, action: \.home))
                    }
                    .transition(.opacity)
                } else {
                    OnboardingView(
                        store: store.scope(state: \.onboarding, action: \.onboarding)
                    )
                        .transition(.opacity)
                }
            }
            .animation(
                reduceMotion ? nil : AppAnimation.onboardingTransition,
                value: store.hasSeenOnboarding
            )
            .onAppear {
                // #814: drain a stale `openSettingsOnLaunch = true` left in
                // `UserDefaults` by a prior session (Onboarding "Customize"
                // → app killed before `HomeView` consumed the flag, or an
                // `.overlaySettingsRequested` effect that ran while the app
                // was backgrounded). `onChangeCompat` only fires on
                // transitions, so the initial-pass check has to be explicit.
                consumeOpenSettingsOnLaunchIfNeeded()
            }
            .onChangeCompat(of: persistedHasSeenOnboarding) { newValue in
                if store.hasSeenOnboarding != newValue {
                    store.send(.hasSeenOnboardingChanged(newValue))
                }
            }
            .onChangeCompat(of: persistedOpenSettingsOnLaunch) { _ in
                consumeOpenSettingsOnLaunchIfNeeded()
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.settingsSheet,
                    action: \.destination.settingsSheet
                )
            ) { settingsStore in
                NavigationStack {
                    SettingsView(
                        store: settingsStore,
                        isPresented: settingsSheetPresentedBinding
                    )
                }
            }
            .fullScreenCover(
                item: $store.scope(
                    state: \.destination?.appCategoryPicker,
                    action: \.destination.appCategoryPicker
                )
            ) { _ in
                EmptyView()
            }
            .fullScreenCover(
                item: $store.scope(state: \.$overlay, action: \.overlay)
            ) { _ in
                EmptyView()
            }
        }
    }

    /// Bridges `SettingsView`'s `isPresented` API (which the Done button
    /// writes `false` to — see `SettingsDismissRegressionTests`) onto the
    /// canonical destination slot. Reads as `true` while the sheet is
    /// presented; writing `false` dispatches `.destination(.dismiss)` so the
    /// `@Presents` machinery tears the sheet down through the reducer
    /// instead of through a separate `@State` mirror (#814).
    private var settingsSheetPresentedBinding: Binding<Bool> {
        Binding(
            get: { store.destination?.settingsSheet != nil },
            set: { newValue in
                if !newValue {
                    store.send(.destination(.dismiss))
                }
            }
        )
    }

    /// Consumes the legacy `openSettingsOnLaunch` UserDefaults flag written
    /// by `OnboardingView.finishOnboardingAndCustomize()` and the
    /// `AppFeature.overlaySettingsRequested` effect (#786). Gated on
    /// `hasSeenOnboarding` so the sheet never races on top of the
    /// onboarding flow; clears the flag synchronously so a re-render
    /// doesn't loop. Dispatches `.openSettingsSheetRequested` so the
    /// destination write goes through the reducer (#814 acceptance).
    private func consumeOpenSettingsOnLaunchIfNeeded() {
        guard persistedOpenSettingsOnLaunch, store.hasSeenOnboarding else { return }
        persistedOpenSettingsOnLaunch = false
        store.send(.openSettingsSheetRequested)
    }
}

#Preview {
    RootView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
