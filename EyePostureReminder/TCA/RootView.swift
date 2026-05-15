import ComposableArchitecture
import SwiftUI

/// Canonical TCA root surface for the Eye & Posture Reminder app.
///
/// `#755` Phase D wires this view into `EyePostureReminderApp.swift` (via the
/// thin `ContentView` wrapper retained for test compatibility) so the
/// onboarding gate, sheet presentations, and overlay cover are all owned by
/// the `AppFeature` store rather than by an `@EnvironmentObject AppCoordinator`
/// graph.
///
/// Responsibilities split:
/// - **Gate**: branches between `OnboardingView` and `HomeView` off of
///   `store.hasSeenOnboarding`. The `@AppStorage` bridge mirrors the
///   `UserDefaults` write `OnboardingView.finishOnboarding()` still performs
///   into a `hasSeenOnboardingChanged` action so the TCA state flips even
///   though the persistence path doesn't yet route through the reducer.
/// - **Destinations**: the `@Presents var destination` slot on
///   `AppFeature.State` (`settingsSheet` / `appCategoryPicker`) is scoped
///   here as scaffolding. No production code path currently assigns
///   `state.destination` — `HomeView` / `SettingsView` still own their local
///   sheet presentations — so these covers render `EmptyView()` until a
///   follow-up issue migrates the local presentations onto the destination
///   graph. Keeping the scaffolding live (rather than deleted) preserves the
///   contract `AppFeature` already documents for the slot.
/// - **Overlay**: same scaffolding pattern as destinations. `OverlayManager`
///   still owns the `UIWindow`-hosted overlay presentation; `state.overlay`
///   is currently only used as a teardown sink (`#738`'s two-phase dismiss).
///   A follow-up issue will swap the UIKit path for the SwiftUI
///   `.fullScreenCover` once `OverlayView` accepts `StoreOf<OverlayFeature>`.
struct RootView: View {
    @Perception.Bindable var store: StoreOf<AppFeature>
    @AppStorage(AppStorageKey.hasSeenOnboarding) private var persistedHasSeenOnboarding = false
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
            .onChangeCompat(of: persistedHasSeenOnboarding) { newValue in
                if store.hasSeenOnboarding != newValue {
                    store.send(.hasSeenOnboardingChanged(newValue))
                }
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.settingsSheet,
                    action: \.destination.settingsSheet
                )
            ) { _ in
                EmptyView()
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
}

#Preview {
    RootView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
