import ComposableArchitecture
import SwiftUI
import XCTest

@testable import EyePostureReminder

/// `TestStore` coverage for `AppFeature` introduced by Phase 2 issue
/// `p0-tca-11` (#674) — the wiring step that gives `EyePostureReminderApp`
/// a real root `Store`.
///
/// Phase-1 child reducers (`HomeFeature`, `SettingsFeature`,
/// `OnboardingFeature`, `SchedulingFeature`) are scoped into the body but
/// none of their actions are exercised here — those reducers are covered by
/// the dedicated `*FeatureTests` rewrites tracked under `p0-tca-17` … `-20`.
/// Every dependency client used by Phase-1 reducers is still overridden so
/// `liveValue` factories that touch `UNUserNotificationCenter.current()` /
/// `UIApplication` are never evaluated when the test bundle constructs the
/// store.
@MainActor
final class AppFeatureTests: XCTestCase {

    // MARK: - Test helpers

    /// Builds a `TestStore` with every dependency client stubbed to a no-op
    /// so child-reducer effects (when accidentally triggered) cannot reach
    /// production singletons or fail with a `liveValue` crash inside the
    /// SwiftPM xctest bundle.
    private func makeStore(
        initialState: AppFeature.State = AppFeature.State()
    ) -> TestStoreOf<AppFeature> {
        TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.settingsClient = SettingsClient(
                snapshot: { ReminderSettings(interval: 0, breakDuration: 0) },
                stream: { .finished },
                updateGlobalEnabled: { _ in },
                updateEyesEnabled: { _ in },
                updatePostureEnabled: { _ in },
                updateEyesInterval: { _ in },
                updatePostureInterval: { _ in },
                updateEyesBreakDuration: { _ in },
                updatePostureBreakDuration: { _ in },
                updatePauseMediaDuringBreaks: { _ in },
                updateHapticsEnabled: { _ in },
                updatePauseDuringFocus: { _ in },
                updatePauseWhileDriving: { _ in },
                updateNotificationFallbackEnabled: { _ in },
                setSnoozedUntil: { _ in },
                setSnoozeCount: { _ in },
                resetToDefaults: {}
            )
            $0.notificationClient = NotificationClient(
                requestAuthorization: { _ in false },
                authorizationStatus: { .notDetermined },
                add: { _ in },
                removePending: { _ in },
                removeAllPending: {},
                pendingRequests: { [] },
                deliveredNotifications: { [] }
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _ in },
                rescheduleReminder: { _, _ in },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
            $0.overlayClient = OverlayClient(
                show: { _, _, _, _ in },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { .finished }
            )
            $0.screenTimeTrackerClient = ScreenTimeTrackerClient(
                setThreshold: { _, _ in },
                enableTracking: { _ in },
                disableTracking: { _ in },
                pauseAll: {},
                resumeAll: {},
                reset: { _ in },
                thresholdReached: { .finished }
            )
            $0.pauseConditionClient = PauseConditionClient(
                isPaused: { false },
                pauseChanges: { .finished },
                startMonitoring: {},
                stopMonitoring: {}
            )
            $0.ipcClient = IPCClient(
                isTrueInterruptEnabled: { false },
                record: { _, _ in },
                trueInterruptChanges: { .finished }
            )
            $0.deviceActivityMonitorClient = DeviceActivityMonitorClient(
                schedule: { _, _ in },
                cancel: { _ in }
            )
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient()
            $0.analyticsClient = AnalyticsClient(log: { _ in })
        }
    }

    // MARK: - Default state

    /// `AppFeature.State()` must match the persistence-free defaults
    /// `EyePostureReminderApp.init` overlays its `UserDefaults` bridge on.
    func test_initialState_matchesDocumentedDefaults() {
        let state = AppFeature.State()

        XCTAssertFalse(state.hasSeenOnboarding,
                       "hasSeenOnboarding must default to false so first launch shows onboarding")
        XCTAssertNil(state.overlay,
                     "overlay presentation must default to nil")
        XCTAssertNil(state.destination,
                     "destination presentation must default to nil")
    }

    // MARK: - hasSeenOnboardingChanged (introduced by #674)

    /// Sending `.hasSeenOnboardingChanged(true)` toggles `state.hasSeenOnboarding`
    /// without producing a follow-up effect — the bridge from
    /// `@AppStorage(AppStorageKey.hasSeenOnboarding)` written by
    /// `OnboardingView.markOnboardingComplete` relies on this exact pure write
    /// so `ContentView` flips from `OnboardingView` → `HomeView`.
    func test_hasSeenOnboardingChanged_true_setsStateAndProducesNoEffect() async {
        let store = makeStore()

        await store.send(.hasSeenOnboardingChanged(true)) {
            $0.hasSeenOnboarding = true
        }
    }

    /// Sending `.hasSeenOnboardingChanged(false)` reverses the gate so a UI
    /// test reset / "factory reset" path can drop the user back into onboarding
    /// without a launch.
    func test_hasSeenOnboardingChanged_false_clearsState() async {
        var initial = AppFeature.State()
        initial.hasSeenOnboarding = true
        let store = makeStore(initialState: initial)

        await store.send(.hasSeenOnboardingChanged(false)) {
            $0.hasSeenOnboarding = false
        }
    }

    /// Sending the same value as the current state is still applied (the
    /// reducer does not early-return) — `ContentView` guards against a
    /// redundant dispatch but the reducer itself stays idempotent.
    func test_hasSeenOnboardingChanged_idempotent_keepsValueStable() async {
        var initial = AppFeature.State()
        initial.hasSeenOnboarding = true
        let store = makeStore(initialState: initial)

        // Same value: no state delta; no effect.
        await store.send(.hasSeenOnboardingChanged(true))
    }

    // MARK: - scenePhaseChanged (Phase-2 deferred to #676)

    /// `.scenePhaseChanged` must remain a pure no-op until `p0-tca-13`
    /// (#676) wires scenePhase observation through the store.
    func test_scenePhaseChanged_active_isNoOp() async {
        let store = makeStore()
        await store.send(.scenePhaseChanged(.active))
    }

    func test_scenePhaseChanged_background_isNoOp() async {
        let store = makeStore()
        await store.send(.scenePhaseChanged(.background))
    }

    func test_scenePhaseChanged_inactive_isNoOp() async {
        let store = makeStore()
        await store.send(.scenePhaseChanged(.inactive))
    }

    // MARK: - notificationRouted (Phase-2 deferred to #675)

    /// `.notificationRouted` must remain a pure no-op at the AppFeature level
    /// until `p0-tca-12` (#675) bridges AppDelegate routes to the
    /// `SchedulingFeature` reducer. The forwarding reducer change happens in
    /// the #675 PR; here we only assert the Phase-1 contract that the action
    /// is accepted without state mutation or effect.
    func test_notificationRouted_reminder_isNoOpAtAppLevel() async {
        let store = makeStore()
        await store.send(.notificationRouted(.reminder(.eyes)))
    }

    func test_notificationRouted_snoozeWake_isNoOpAtAppLevel() async {
        let store = makeStore()
        await store.send(.notificationRouted(.snoozeWake))
    }

    func test_notificationRouted_ignore_isNoOpAtAppLevel() async {
        let store = makeStore()
        await store.send(.notificationRouted(.ignore))
    }

    // MARK: - Destination state Equatable conformance

    /// `AppFeature.Destination.State` synthesised `Equatable` is required by
    /// `@Presents` / `ifLet(\.$destination, action: \.destination)` to detect
    /// presentation changes. Verifies both cases compare correctly.
    func test_destinationState_equatable_settingsSheetCases_areEqual() {
        let lhs: AppFeature.Destination.State = .settingsSheet(SettingsFeature.State())
        let rhs: AppFeature.Destination.State = .settingsSheet(SettingsFeature.State())

        XCTAssertEqual(lhs, rhs,
                       "Two .settingsSheet destinations with equal payloads must compare equal")
    }

    func test_destinationState_equatable_appCategoryPickerCases_areEqual() {
        let lhs: AppFeature.Destination.State = .appCategoryPicker(AppCategoryPickerFeature.State())
        let rhs: AppFeature.Destination.State = .appCategoryPicker(AppCategoryPickerFeature.State())

        XCTAssertEqual(lhs, rhs,
                       "Two .appCategoryPicker destinations with equal payloads must compare equal")
    }

    func test_destinationState_equatable_differentCases_areUnequal() {
        let lhs: AppFeature.Destination.State = .settingsSheet(SettingsFeature.State())
        let rhs: AppFeature.Destination.State = .appCategoryPicker(AppCategoryPickerFeature.State())

        XCTAssertNotEqual(lhs, rhs,
                          ".settingsSheet and .appCategoryPicker must compare unequal")
    }

    // MARK: - NotificationRoute typealias re-export

    /// `AppFeature.NotificationRoute` is re-exported from
    /// `AppDelegate.NotificationRoute` — verify the typealias resolves
    /// transparently so callers can refer to it without the `AppDelegate.`
    /// qualifier.
    func test_notificationRouteTypealias_resolvesToAppDelegateRoute() {
        let route: AppFeature.NotificationRoute = .reminder(.eyes)
        let delegateRoute: AppDelegate.NotificationRoute = route

        XCTAssertEqual(route, delegateRoute,
                       "AppFeature.NotificationRoute must be an alias of AppDelegate.NotificationRoute")
    }
}
