import ComposableArchitecture
import UserNotifications
import XCTest

@testable import EyePostureReminder

/// `TestStore` baseline coverage for `HomeFeature` (Phase 1 reducer
/// `p0-tca-5` / #668). Behavioural parity with `HomeView` lives under Phase
/// 3 issue `p0-tca-18` (#681).
@MainActor
final class HomeFeatureTests: XCTestCase {

    // MARK: - Default state

    func test_state_init_documentedDefaults() {
        let state = HomeFeature.State()

        XCTAssertEqual(state.settings, ReminderSettings(interval: 0, breakDuration: 0))
        XCTAssertTrue(state.globalEnabled)
        XCTAssertTrue(state.eyesEnabled)
        XCTAssertTrue(state.postureEnabled)
        XCTAssertEqual(state.notificationAuthStatus, .notDetermined)
        XCTAssertFalse(state.trueInterruptBannerDismissed)
        XCTAssertFalse(state.openSettingsOnLaunch)
    }

    // MARK: - .onAppear

    func test_onAppear_seedsSettingsAndPollsAuthStatus() async {
        let snapshot = ReminderSettings(interval: 1200, breakDuration: 20)
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.settingsClient = SettingsClient(
                snapshot: { snapshot },
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
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .authorized
            )
        }

        await store.send(.onAppear) {
            $0.settings = snapshot
        }
        await store.receive(\.notificationAuthStatusChanged) {
            $0.notificationAuthStatus = .authorized
        }
    }

    // MARK: - .settingsTapped

    func test_settingsTapped_isParentInterceptedNoOp() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        await store.send(.settingsTapped)
    }

    // MARK: - .dismissTrueInterruptBanner

    func test_dismissTrueInterruptBanner_setsFlag() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        await store.send(.dismissTrueInterruptBanner) {
            $0.trueInterruptBannerDismissed = true
        }
    }

    // MARK: - .settingsChanged

    func test_settingsChanged_writesSnapshotToState() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }
        let snapshot = ReminderSettings(interval: 600, breakDuration: 15)

        await store.send(.settingsChanged(snapshot)) {
            $0.settings = snapshot
        }
    }

    // MARK: - .notificationAuthStatusChanged

    func test_notificationAuthStatusChanged_writesStatusToState() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        await store.send(.notificationAuthStatusChanged(.denied)) {
            $0.notificationAuthStatus = .denied
        }
    }

    // MARK: - Computed view-model state

    func test_state_statusKey_paused_whenGlobalDisabled() {
        var state = HomeFeature.State()
        state.globalEnabled = false

        XCTAssertEqual(state.statusLocalizationKey, "home.status.paused")
    }

    func test_state_statusKey_noReminders_whenEyesAndPostureDisabled() {
        var state = HomeFeature.State()
        state.eyesEnabled = false
        state.postureEnabled = false

        XCTAssertEqual(state.statusLocalizationKey, "home.status.noReminders")
    }

    func test_state_statusKey_notificationsOff_whenAuthDenied() {
        var state = HomeFeature.State()
        state.notificationAuthStatus = .denied

        XCTAssertEqual(state.statusLocalizationKey, "home.status.notificationsOff")
    }

    func test_state_statusKey_active_whenAuthorisedAndEnabled() {
        var state = HomeFeature.State()
        state.notificationAuthStatus = .authorized

        XCTAssertEqual(state.statusLocalizationKey, "home.status.active")
    }

    func test_state_shouldShowNotificationRecovery_trueWhenGlobalEnabledAndDenied() {
        var state = HomeFeature.State()
        state.notificationAuthStatus = .denied

        XCTAssertTrue(state.shouldShowNotificationRecovery)
    }

    func test_state_shouldShowNotificationRecovery_falseWhenGlobalDisabled() {
        var state = HomeFeature.State()
        state.globalEnabled = false
        state.notificationAuthStatus = .denied

        XCTAssertFalse(state.shouldShowNotificationRecovery)
    }

    func test_state_shouldShowNoRemindersConfigured_trueWhenBothDisabled() {
        var state = HomeFeature.State()
        state.eyesEnabled = false
        state.postureEnabled = false

        XCTAssertTrue(state.shouldShowNoRemindersConfigured)
    }

    func test_state_shouldShowNoRemindersConfigured_falseWhenEyesEnabled() {
        var state = HomeFeature.State()
        state.eyesEnabled = true
        state.postureEnabled = false

        XCTAssertFalse(state.shouldShowNoRemindersConfigured)
    }

    func test_state_shouldShowNoRemindersConfigured_falseWhenGlobalDisabled() {
        var state = HomeFeature.State()
        state.globalEnabled = false
        state.eyesEnabled = false
        state.postureEnabled = false

        XCTAssertFalse(state.shouldShowNoRemindersConfigured,
                       "Global disabled takes precedence over per-type disablement")
    }

    // MARK: - .task — settings stream subscription (#681)

    func test_task_streamsSettingsSnapshotsIntoState() async {
        let (stream, continuation) = AsyncStream<ReminderSettings>.makeStream()
        var settings = TCATestDependencies.silentSettingsClient()
        settings.stream = { stream }

        let clock = TestClock()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.settingsClient = settings
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .authorized
            )
            $0.continuousClock = clock
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        let task = await store.send(.task)

        let firstSnapshot = ReminderSettings(interval: 1200, breakDuration: 20)
        continuation.yield(firstSnapshot)
        await store.receive(\.settingsChanged) {
            $0.settings = firstSnapshot
        }

        let secondSnapshot = ReminderSettings(interval: 600, breakDuration: 30)
        continuation.yield(secondSnapshot)
        await store.receive(\.settingsChanged) {
            $0.settings = secondSnapshot
        }

        continuation.finish()
        await task.cancel()
    }

    // MARK: - Static helpers

    func test_static_statusLocalizationKey_paused() {
        let key = HomeFeature.statusLocalizationKey(
            globalEnabled: false,
            eyesEnabled: true,
            postureEnabled: true,
            notificationAuthStatus: .authorized
        )

        XCTAssertEqual(key, "home.status.paused")
    }

    func test_static_statusLocalizationKey_noReminders() {
        let key = HomeFeature.statusLocalizationKey(
            globalEnabled: true,
            eyesEnabled: false,
            postureEnabled: false,
            notificationAuthStatus: .authorized
        )

        XCTAssertEqual(key, "home.status.noReminders")
    }

    func test_static_statusLocalizationKey_notificationsOff() {
        let key = HomeFeature.statusLocalizationKey(
            globalEnabled: true,
            eyesEnabled: true,
            postureEnabled: true,
            notificationAuthStatus: .denied
        )

        XCTAssertEqual(key, "home.status.notificationsOff")
    }

    func test_static_statusLocalizationKey_active() {
        let key = HomeFeature.statusLocalizationKey(
            globalEnabled: true,
            eyesEnabled: true,
            postureEnabled: true,
            notificationAuthStatus: .authorized
        )

        XCTAssertEqual(key, "home.status.active")
    }

    func test_static_shouldShowNotificationRecovery_truthTable() {
        XCTAssertTrue(HomeFeature.shouldShowNotificationRecovery(
            globalEnabled: true, notificationAuthStatus: .denied
        ))
        XCTAssertFalse(HomeFeature.shouldShowNotificationRecovery(
            globalEnabled: false, notificationAuthStatus: .denied
        ))
        XCTAssertFalse(HomeFeature.shouldShowNotificationRecovery(
            globalEnabled: true, notificationAuthStatus: .authorized
        ))
        XCTAssertFalse(HomeFeature.shouldShowNotificationRecovery(
            globalEnabled: true, notificationAuthStatus: .notDetermined
        ))
    }

    func test_static_shouldShowNoRemindersConfigured_truthTable() {
        XCTAssertTrue(HomeFeature.shouldShowNoRemindersConfigured(
            globalEnabled: true, eyesEnabled: false, postureEnabled: false
        ))
        XCTAssertFalse(HomeFeature.shouldShowNoRemindersConfigured(
            globalEnabled: true, eyesEnabled: true, postureEnabled: false
        ))
        XCTAssertFalse(HomeFeature.shouldShowNoRemindersConfigured(
            globalEnabled: true, eyesEnabled: false, postureEnabled: true
        ))
        XCTAssertFalse(HomeFeature.shouldShowNoRemindersConfigured(
            globalEnabled: false, eyesEnabled: false, postureEnabled: false
        ))
    }
}
