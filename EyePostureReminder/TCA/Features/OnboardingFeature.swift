import ComposableArchitecture
import Foundation
import UserNotifications

/// Phase 1 reducer (`p0-tca-7` / #670) backing the onboarding flow.
///
/// Mirrors the observable behaviour of `OnboardingView` and the
/// `OnboardingCoordinator`-style hooks routed through `AppCoordinator`
/// today, so a later Phase 2 issue (`p0-tca-14` / #677) can swap the
/// onboarding views to read from this store and the legacy
/// `AppCoordinator` plumbing can be retired.
///
/// ## Persistence and parent wiring
///
/// `.completedOnboarding` is emitted but never acted on locally; the parent
/// (`AppFeature`) listens for it to flip
/// `@AppStorage(AppStorageKey.hasSeenOnboarding)` and dismiss the
/// onboarding flow. `showAppCategoryPicker` follows the same parent-driven
/// presentation contract: this reducer only flips the flag while the parent
/// presents `Destination.appCategoryPicker` (Phase 2 wiring lives in
/// `p0-tca-11` / #674).
@Reducer
struct OnboardingFeature {
    @ObservableState
    struct State: Equatable {
        /// Index of the visible page (0 … 3) inside the onboarding `TabView`.
        var currentPage: Int = 0

        /// Latest `ScreenTimeAuthorizationStatus` observed via
        /// `ScreenTimeAuthorizationClient`. Defaults to `.unavailable` until
        /// the FamilyControls entitlement is provisioned (#201).
        var screenTimeStatus: ScreenTimeAuthorizationStatus = .unavailable

        /// Latest `UNAuthorizationStatus` observed via `NotificationClient`.
        var notificationAuthStatus: UNAuthorizationStatus = .notDetermined

        /// Drives parent-side presentation of `AppCategoryPickerView`.
        var showAppCategoryPicker: Bool = false
    }

    enum Action: Equatable {
        case onAppear
        case nextTapped
        case skipTapped
        case finishTapped
        case finishAndCustomizeTapped
        case requestNotificationPermission
        case requestScreenTimeAuthorization
        case notificationStatusChanged(UNAuthorizationStatus)
        case screenTimeStatusChanged(ScreenTimeAuthorizationStatus)
        case openAppCategoryPicker
        case dismissAppCategoryPicker
        case completedOnboarding
    }

    @Dependency(\.notificationClient) var notification: NotificationClient
    @Dependency(\.screenTimeAuthorizationClient) var screenTimeAuth: ScreenTimeAuthorizationClient
    @Dependency(\.analyticsClient) var analytics: AnalyticsClient

    /// Final page index in the 4-page onboarding `TabView`.
    static let lastPageIndex: Int = 3

    /// Notification authorisation options requested by the onboarding
    /// permission page. Mirrors the set used by `AppCoordinator` so the
    /// system prompt copy stays identical across the migration.
    static let notificationOptions: UNAuthorizationOptions = [.alert, .sound, .badge]

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let notificationStatus = await notification.authorizationStatus()
                    await send(.notificationStatusChanged(notificationStatus))
                    let screenTime = await screenTimeAuth.status()
                    await send(.screenTimeStatusChanged(screenTime))
                }

            case .nextTapped:
                state.currentPage = min(state.currentPage + 1, Self.lastPageIndex)
                return .none

            case .skipTapped, .finishTapped:
                analytics.log(.onboardingCompleted(cta: .getStarted))
                return .send(.completedOnboarding)

            case .finishAndCustomizeTapped:
                analytics.log(.onboardingCompleted(cta: .customize))
                return .merge(
                    .send(.completedOnboarding),
                    .send(.openAppCategoryPicker)
                )

            case .requestNotificationPermission:
                return .run { send in
                    // Permission grant outcome (granted / denied) is reflected
                    // in the subsequent authorisation status read; the boolean
                    // result and any throws are intentionally swallowed here
                    // because `notificationStatusChanged` is the single
                    // source of truth for downstream UI.
                    _ = try? await notification.requestAuthorization(Self.notificationOptions)
                    let status = await notification.authorizationStatus()
                    await send(.notificationStatusChanged(status))
                    // Spec calls for `.notificationPermissionResponded(...)` here;
                    // that case is not present in the current `AnalyticsEvent`
                    // surface and adding it would violate the "own this file
                    // only" constraint, so the analytics call is deferred to
                    // the AnalyticsLogger surface extension that owns it.
                }

            case .requestScreenTimeAuthorization:
                return .run { send in
                    let status = await screenTimeAuth.requestAuthorization()
                    await send(.screenTimeStatusChanged(status))
                }

            case let .notificationStatusChanged(status):
                state.notificationAuthStatus = status
                return .none

            case let .screenTimeStatusChanged(status):
                state.screenTimeStatus = status
                return .none

            case .openAppCategoryPicker:
                state.showAppCategoryPicker = true
                return .none

            case .dismissAppCategoryPicker:
                state.showAppCategoryPicker = false
                return .none

            case .completedOnboarding:
                // Parent (`AppFeature`) intercepts to flip
                // `hasSeenOnboarding` and dismiss onboarding (Phase 2,
                // `p0-tca-11`); the reducer itself has no local effect.
                return .none
            }
        }
    }
}
