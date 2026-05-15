import ComposableArchitecture
import UserNotifications
import XCTest

@testable import EyePostureReminder

/// `TestStore` baseline coverage for `OnboardingFeature` (Phase 1 reducer
/// `p0-tca-7` / #670). Behavioural parity with `OnboardingView` /
/// `OnboardingCoordinator` lives under Phase 3 issue `p0-tca-19` (#682).
@MainActor
final class OnboardingFeatureTests: XCTestCase {

    // MARK: - Default state

    func test_state_init_documentedDefaults() {
        let state = OnboardingFeature.State()

        XCTAssertEqual(state.currentPage, 0)
        XCTAssertEqual(state.screenTimeStatus, .unavailable)
        XCTAssertEqual(state.notificationAuthStatus, .notDetermined)
        XCTAssertFalse(state.showAppCategoryPicker)
    }

    // MARK: - Static configuration

    func test_lastPageIndex_isThree() {
        XCTAssertEqual(OnboardingFeature.lastPageIndex, 3,
                       "Onboarding TabView has 4 pages indexed 0…3")
    }

    func test_notificationOptions_includeAlertSoundBadge() {
        XCTAssertTrue(OnboardingFeature.notificationOptions.contains(.alert))
        XCTAssertTrue(OnboardingFeature.notificationOptions.contains(.sound))
        XCTAssertTrue(OnboardingFeature.notificationOptions.contains(.badge))
    }

    // MARK: - .onAppear

    func test_onAppear_pollsBothAuthorisationsAndUpdatesState() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .denied
            )
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient(
                status: { .approved },
                statusChanges: { .finished },
                requestAuthorization: { .approved }
            )
            $0.analyticsClient = AnalyticsClient(log: { _ in })
        }

        await store.send(.onAppear)
        await store.receive(\.notificationStatusChanged) {
            $0.notificationAuthStatus = .denied
        }
        await store.receive(\.screenTimeStatusChanged) {
            $0.screenTimeStatus = .approved
        }
    }

    // MARK: - .nextTapped

    func test_nextTapped_incrementsCurrentPage() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.nextTapped) {
            $0.currentPage = 1
        }
    }

    func test_nextTapped_clampsAtLastPageIndex() async {
        var initial = OnboardingFeature.State()
        initial.currentPage = OnboardingFeature.lastPageIndex
        let store = TestStore(initialState: initial) {
            OnboardingFeature()
        }

        await store.send(.nextTapped)
    }

    // MARK: - .skipTapped / .finishTapped

    func test_skipTapped_logsCompletedAndEmitsCompletedOnboarding() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.analyticsClient = AnalyticsClient(log: { _ in })
        }

        await store.send(.skipTapped)
        await store.receive(\.completedOnboarding)
    }

    func test_finishTapped_logsCompletedAndEmitsCompletedOnboarding() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.analyticsClient = AnalyticsClient(log: { _ in })
        }

        await store.send(.finishTapped)
        await store.receive(\.completedOnboarding)
    }

    // MARK: - .finishAndCustomizeTapped

    func test_finishAndCustomizeTapped_emitsCompletedAndOpenPicker() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.analyticsClient = AnalyticsClient(log: { _ in })
        }

        await store.send(.finishAndCustomizeTapped)
        await store.receive(\.completedOnboarding)
        await store.receive(\.openAppCategoryPicker) {
            $0.showAppCategoryPicker = true
        }
    }

    // MARK: - .requestNotificationPermission

    func test_requestNotificationPermission_swallowsThrowAndUpdatesStatus() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.notificationClient = NotificationClient(
                requestAuthorization: { _ in
                    throw NSError(domain: "test", code: 1)
                },
                authorizationStatus: { .authorized },
                add: { _ in },
                removePending: { _ in },
                removeAllPending: {},
                pendingRequests: { [] },
                deliveredNotifications: { [] }
            )
            $0.analyticsClient = AnalyticsClient(log: { _ in })
        }

        await store.send(.requestNotificationPermission)
        await store.receive(\.notificationStatusChanged) {
            $0.notificationAuthStatus = .authorized
        }
    }

    func test_requestNotificationPermission_grantedRoutesAuthorizedStatus() async {
        let requestCalls = LockIsolated<[UNAuthorizationOptions]>([])
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.notificationClient = NotificationClient(
                requestAuthorization: { options in
                    requestCalls.withValue { $0.append(options) }
                    return true
                },
                authorizationStatus: { .authorized },
                add: { _ in },
                removePending: { _ in },
                removeAllPending: {},
                pendingRequests: { [] },
                deliveredNotifications: { [] }
            )
            $0.analyticsClient = AnalyticsClient(log: { _ in })
        }

        await store.send(.requestNotificationPermission)
        await store.receive(\.notificationStatusChanged) {
            $0.notificationAuthStatus = .authorized
        }

        requestCalls.withValue { calls in
            XCTAssertEqual(calls.count, 1, "Must request permission exactly once")
            XCTAssertEqual(calls.first, OnboardingFeature.notificationOptions,
                           "Must request the documented .alert/.sound/.badge bundle")
        }
    }

    func test_requestNotificationPermission_deniedRoutesDeniedStatus() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.notificationClient = NotificationClient(
                requestAuthorization: { _ in false },
                authorizationStatus: { .denied },
                add: { _ in },
                removePending: { _ in },
                removeAllPending: {},
                pendingRequests: { [] },
                deliveredNotifications: { [] }
            )
            $0.analyticsClient = AnalyticsClient(log: { _ in })
        }

        await store.send(.requestNotificationPermission)
        await store.receive(\.notificationStatusChanged) {
            $0.notificationAuthStatus = .denied
        }
    }

    // MARK: - .requestScreenTimeAuthorization

    func test_requestScreenTimeAuthorization_routesThroughClient() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient(
                status: { .approved },
                statusChanges: { .finished },
                requestAuthorization: { .approved }
            )
            $0.analyticsClient = AnalyticsClient(log: { _ in })
        }

        await store.send(.requestScreenTimeAuthorization)
        await store.receive(\.screenTimeStatusChanged) {
            $0.screenTimeStatus = .approved
        }
    }

    // MARK: - status-change actions

    func test_notificationStatusChanged_writesToState() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.notificationStatusChanged(.authorized)) {
            $0.notificationAuthStatus = .authorized
        }
    }

    func test_screenTimeStatusChanged_writesToState() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.screenTimeStatusChanged(.denied)) {
            $0.screenTimeStatus = .denied
        }
    }

    // MARK: - picker presentation gates

    func test_openAppCategoryPicker_setsFlag() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.openAppCategoryPicker) {
            $0.showAppCategoryPicker = true
        }
    }

    func test_dismissAppCategoryPicker_clearsFlag() async {
        var initial = OnboardingFeature.State()
        initial.showAppCategoryPicker = true
        let store = TestStore(initialState: initial) {
            OnboardingFeature()
        }

        await store.send(.dismissAppCategoryPicker) {
            $0.showAppCategoryPicker = false
        }
    }

    // MARK: - .completedOnboarding

    func test_completedOnboarding_isLocalNoOp_parentObservesIt() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.completedOnboarding)
    }

    // MARK: - .pageChanged

    /// `.pageChanged` writes the new index into state, mirroring the
    /// swipe-driven `TabView` selection.
    func test_pageChanged_writesValueIntoState() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.pageChanged(2)) {
            $0.currentPage = 2
        }
    }

    /// `.pageChanged` clamps values above `lastPageIndex` so swipe noise
    /// can't move the reducer into an invalid page.
    func test_pageChanged_clampsAboveLastPageIndex() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }

        await store.send(.pageChanged(99)) {
            $0.currentPage = OnboardingFeature.lastPageIndex
        }
    }

    /// `.pageChanged` clamps negative values to zero.
    func test_pageChanged_clampsNegativeValuesToZero() async {
        var initial = OnboardingFeature.State()
        initial.currentPage = 2
        let store = TestStore(initialState: initial) {
            OnboardingFeature()
        }

        await store.send(.pageChanged(-5)) {
            $0.currentPage = 0
        }
    }
}
