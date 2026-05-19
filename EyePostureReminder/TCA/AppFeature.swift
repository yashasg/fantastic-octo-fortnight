import ComposableArchitecture
import Foundation
import SwiftUI

/// Root reducer composing every feature in the Eye & Posture Reminder app.
///
/// `AppFeature` is the production runtime entry point: `EyePostureReminderApp`
/// owns a `StoreOf<AppFeature>` and the reducer body:
///
/// - `Scope`s `HomeFeature`, `SettingsFeature`, `OnboardingFeature`, and
///   `SchedulingFeature` under their respective state slices.
/// - Bridges `scenePhaseChanged(.active)` to `scheduling`'s foreground
///   transition + expired-snooze sweep, and `.background` to its background
///   transition.
/// - Forwards `notificationRouted(...)` events from `AppDelegate` into
///   `SchedulingFeature`.
/// - Subscribes to `OverlayClient.lifecycleEvents` on `.onAppear` so the
///   overlay's "Settings" CTA round-trips through
///   `overlaySettingsRequested(type)` and flips the `openSettingsOnLaunch`
///   handoff (regression coverage: #786).
/// - Owns the two-phase overlay dismiss (#738) by clearing the `@Presents`
///   slot once `OverlayFeature` finishes its dismiss animation.
///
/// The surface — state shape, action vocabulary, scopes, and presentation
/// wiring — was nailed down in Phase 0 (`p0-tca-3` / #666); the full
/// composition and `EyePostureReminderApp` wiring were completed by Phase 2
/// (`p0-tca-11` / #674) and #755 Phase E (PR #760).
@Reducer
struct AppFeature {
    /// Re-exposes `AppDelegate.NotificationRoute` at the AppFeature scope so
    /// the action vocabulary can refer to it without a leading
    /// `AppDelegate.` qualifier and without modifying `AppDelegate.swift`.
    typealias NotificationRoute = AppDelegate.NotificationRoute

    @ObservableState
    struct State: Equatable {
        var hasSeenOnboarding: Bool = false
        var home: HomeFeature.State = .init()
        var settings: SettingsFeature.State = .init()
        var onboarding: OnboardingFeature.State = .init()
        var scheduling: SchedulingFeature.State = .init()
        @Presents var overlay: OverlayFeature.State?
        @Presents var destination: Destination.State?
    }

    enum Action {
        case onAppear
        case scenePhaseChanged(ScenePhase)
        case hasSeenOnboardingChanged(Bool)
        case home(HomeFeature.Action)
        case settings(SettingsFeature.Action)
        case onboarding(OnboardingFeature.Action)
        case scheduling(SchedulingFeature.Action)
        case overlay(PresentationAction<OverlayFeature.Action>)
        case destination(PresentationAction<Destination.Action>)
        case notificationRouted(NotificationRoute)
        /// Fired when `OverlayClient.lifecycleEvents` emits
        /// `.settingsTapped(type)` while the break overlay is on screen.
        /// Sets the shared `openSettingsOnLaunch` UserDefaults flag so
        /// `RootView` opens Settings on the next layout pass; see #786
        /// for the regression report that re-plumbed this handoff after
        /// the TCA migration.
        case overlaySettingsRequested(ReminderType)
        /// Presents the canonical Settings destination
        /// (`Destination.settingsSheet`) on behalf of a non-`HomeView`
        /// trigger — currently `RootView`'s `@AppStorage(openSettingsOnLaunch)`
        /// observer (#814), which routes the legacy UserDefaults handoff
        /// written by `OnboardingView.finishOnboardingAndCustomize()` and the
        /// `.overlaySettingsRequested` effect into a TCA action instead of a
        /// SwiftUI `@State` bridge inside `HomeView`. `HomeView`'s own gear
        /// button dispatches `.home(.settingsTapped)`, which the parent
        /// reducer collapses onto the same destination write.
        case openSettingsSheetRequested
    }

    @Reducer
    enum Destination {
        case settingsSheet(SettingsFeature)
        case appCategoryPicker(AppCategoryPickerFeature)
    }

    @Dependency(\.overlayClient) var overlayClient: OverlayClient

    private enum CancelID: Hashable {
        case overlayLifecycle
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) { HomeFeature() }
        Scope(state: \.settings, action: \.settings) { SettingsFeature() }
        Scope(state: \.onboarding, action: \.onboarding) { OnboardingFeature() }
        Scope(state: \.scheduling, action: \.scheduling) { SchedulingFeature() }

        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .send(.scheduling(.start)),
                    .run { [overlayClient] send in
                        for await event in overlayClient.lifecycleEvents() {
                            if case let .settingsTapped(type) = event {
                                await send(.overlaySettingsRequested(type))
                            }
                        }
                    }
                    .cancellable(id: CancelID.overlayLifecycle, cancelInFlight: true)
                )
            case .scenePhaseChanged(.active):
                return .merge(
                    .send(.scheduling(.foregroundTransition)),
                    .send(.scheduling(.clearExpiredSnoozeIfNeeded))
                )
            case .scenePhaseChanged(.background):
                return .send(.scheduling(.backgroundTransition))
            case .scenePhaseChanged:
                return .none
            case .hasSeenOnboardingChanged(let value):
                state.hasSeenOnboarding = value
                return .none
            case let .notificationRouted(route):
                return .send(.scheduling(.notificationRouted(route)))
            case .overlay(.presented(.dismissed)):
                // Two-phase dismiss (#738): once `OverlayFeature` finishes
                // its `dismissAnimationCompleted` → `overlayClient.dismiss`
                // → `dismissed` chain, the presentation slot in the root
                // store must be cleared so `RootView`'s
                // `.fullScreenCover(item: $store.scope(state: \.$overlay, …))`
                // tears down the cover. The `@Presents` machinery does not
                // auto-clear on a child action; the parent reducer owns the
                // nil write.
                state.overlay = nil
                return .none
            case .overlaySettingsRequested:
                // Setting the shared `openSettingsOnLaunch` flag is what
                // `RootView`'s `.onChangeCompat(of: openSettingsOnLaunch)`
                // watches to dispatch `.openSettingsSheetRequested` after
                // the overlay slide-out animation finishes. Matches
                // `OnboardingView`'s existing direct-write pattern for
                // the same key. Tracked as #786 (write) and #814
                // (read → destination handoff).
                return .run { _ in
                    UserDefaults.standard.set(
                        true, forKey: AppStorageKey.openSettingsOnLaunch
                    )
                }
            case .home(.settingsTapped):
                // #814: HomeView's gear button (and the in-screen banners that
                // also call it) dispatch `.home(.settingsTapped)`. The parent
                // owns presentation: write the canonical destination and
                // mirror the active flag into HomeFeature.State so the view's
                // VoiceOver master-toggle announcement guard (#287) can read
                // it without keeping a SwiftUI `@State` bridge.
                state.destination = .settingsSheet(SettingsFeature.State())
                state.home.settingsSheetActive = true
                return .none
            case .onboarding(.openAppCategoryPicker):
                // #918: OnboardingView's "Set Up" CTA on the True Interrupt
                // Mode page dispatches `.onboarding(.openAppCategoryPicker)`.
                // The parent owns presentation: write the canonical
                // destination so `RootView`'s `.fullScreenCover(item:
                // $store.scope(state: \.destination?.appCategoryPicker, ...))`
                // presents the picker from a single store, retiring the
                // previous `OnboardingView.@State showAppCategoryPicker`
                // mirror + local-store `OnboardingAppCategoryPickerSheet`
                // wrapper. Dismissal flows back through SwiftUI's
                // `@Environment(\.dismiss)` on the picker's Done button,
                // which the `@Presents` machinery converts into
                // `.destination(.dismiss)`.
                state.destination = .appCategoryPicker(AppCategoryPickerFeature.State())
                return .none
            case .openSettingsSheetRequested:
                // #814: RootView's `@AppStorage(openSettingsOnLaunch)`
                // observer routes the legacy UserDefaults handoff
                // (`OnboardingView.finishOnboardingAndCustomize()` and
                // `.overlaySettingsRequested`) through this action so the
                // destination write goes through the reducer, not via a
                // SwiftUI `@State` bridge inside `HomeView`.
                state.destination = .settingsSheet(SettingsFeature.State())
                state.home.settingsSheetActive = true
                return .none
            case .destination(.dismiss):
                // Keep the HomeFeature mirror in sync with the canonical
                // destination presence — see `.home(.settingsTapped)` above
                // for the announcement-guard rationale (#287 / #814). Fires
                // when SwiftUI dismisses the sheet via `RootView`'s
                // `$store.scope(state: \.destination?.settingsSheet, …)`
                // binding being set to nil (Done button / swipe-down).
                state.home.settingsSheetActive = false
                return .none
            case .home, .settings, .onboarding, .scheduling, .overlay, .destination:
                return .none
            }
        }
        .ifLet(\.$overlay, action: \.overlay) { OverlayFeature() }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension AppFeature.Destination.State: Equatable {}
