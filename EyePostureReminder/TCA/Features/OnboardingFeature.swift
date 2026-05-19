import ComposableArchitecture
import Foundation
import UserNotifications

/// TCA reducer (`p0-tca-7` / #670) backing the onboarding flow.
///
/// Owns the observable behaviour for the onboarding tab carousel:
/// `currentPage` navigation and the notification + Screen Time
/// authorisation status (sourced from `NotificationClient` and
/// `ScreenTimeAuthorizationClient`). The onboarding views read from this
/// store directly.
///
/// ## Persistence and parent wiring
///
/// `.completedOnboarding` is emitted but never acted on locally; the parent
/// (`AppFeature`) listens for it to flip
/// `@AppStorage(AppStorageKey.hasSeenOnboarding)` and dismiss the
/// onboarding flow. `.openAppCategoryPicker` follows the same
/// parent-observed-signal contract: this reducer emits the action with no
/// local state mutation, and the parent intercepts it to write
/// `state.destination = .appCategoryPicker(...)` so `RootView`'s
/// `.fullScreenCover` presents the canonical picker store (#918, replacing
/// the previous `OnboardingView.@State` mirror + local-store sheet
/// wrapper). Dismissal flows back through SwiftUI's `@Environment(\.dismiss)`
/// on the picker's Done button, which clears the destination via the
/// standard `@Presents` teardown.
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
        /// Parent-observed signal — `AppFeature` intercepts this action to
        /// present the canonical `AppCategoryPickerFeature` destination
        /// (#918). The reducer itself performs no local state mutation;
        /// dismissal is handled via the picker's Done button, which calls
        /// `@Environment(\.dismiss)` and flows through `@Presents` teardown.
        case openAppCategoryPicker
        case completedOnboarding
        /// Writes the current `TabView` page index back into the reducer.
        /// `nextTapped` covers tap-based navigation; this case covers
        /// swipe-driven page changes so the reducer remains the single source
        /// of truth for `currentPage`. Values outside `0...lastPageIndex` are
        /// clamped.
        case pageChanged(Int)
    }

    @Dependency(\.notificationClient) var notification: NotificationClient
    @Dependency(\.screenTimeAuthorizationClient) var screenTimeAuth: ScreenTimeAuthorizationClient
    @Dependency(\.analyticsClient) var analytics: AnalyticsClient

    /// Final page index in the 4-page onboarding `TabView`.
    static let lastPageIndex: Int = 3

    /// Notification authorisation options requested by the onboarding
    /// permission page. Stable across releases so the system prompt copy
    /// shown to existing users does not change.
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
                    // The boolean returned by `requestAuthorization(_:)` records
                    // the user's response to the system prompt; we forward it
                    // to analytics as `.notificationPermissionResponded(granted:)`
                    // (#896). Throws are still swallowed — the subsequent
                    // `authorizationStatus()` read remains the single source of
                    // truth for UI, and we deliberately skip the analytics
                    // emission on throw so the stream only carries real
                    // user-driven responses.
                    let granted = try? await notification.requestAuthorization(Self.notificationOptions)
                    if let granted {
                        analytics.log(.notificationPermissionResponded(granted: granted))
                    }
                    let status = await notification.authorizationStatus()
                    await send(.notificationStatusChanged(status))
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
                // Parent-observed signal — `AppFeature` intercepts to write
                // `state.destination = .appCategoryPicker(...)` (#918).
                return .none

            case .completedOnboarding:
                // Parent (`AppFeature`) intercepts to flip
                // `hasSeenOnboarding` and dismiss onboarding (Phase 2,
                // `p0-tca-11`); the reducer itself has no local effect.
                return .none

            case let .pageChanged(page):
                state.currentPage = max(0, min(page, Self.lastPageIndex))
                return .none
            }
        }
    }
}
