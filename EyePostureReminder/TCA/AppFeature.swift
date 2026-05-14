import ComposableArchitecture
import Foundation
import SwiftUI

/// Root reducer composing every feature in the TCA migration of the Eye &
/// Posture Reminder app.
///
/// Phase 0 (`p0-tca-3` / #666) deliberately leaves the body almost empty:
/// the goal is to nail down the *surface* — state shape, action vocabulary,
/// scopes, and presentation wiring — so that Phase 1 issues can fill in each
/// individual feature reducer in any order, without merge collisions on this
/// root file.
///
/// Wiring into `EyePostureReminderApp.swift` is intentionally deferred to
/// Phase 2 issue `p0-tca-11` (#674) — the legacy MVVM app-coordinator stack
/// remains the production runtime until then.
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
    }

    @Reducer
    enum Destination {
        case settingsSheet(SettingsFeature)
        case appCategoryPicker(AppCategoryPickerFeature)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) { HomeFeature() }
        Scope(state: \.settings, action: \.settings) { SettingsFeature() }
        Scope(state: \.onboarding, action: \.onboarding) { OnboardingFeature() }
        Scope(state: \.scheduling, action: \.scheduling) { SchedulingFeature() }

        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.scheduling(.start))
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
            case .home, .settings, .onboarding, .scheduling, .overlay, .destination:
                return .none
            }
        }
        .ifLet(\.$overlay, action: \.overlay) { OverlayFeature() }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension AppFeature.Destination.State: Equatable {}
