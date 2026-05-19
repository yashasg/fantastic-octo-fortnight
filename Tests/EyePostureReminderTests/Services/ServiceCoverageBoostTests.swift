import ComposableArchitecture
import MetricKit
import XCTest

@testable import EyePostureReminder

/// Additional service and model tests targeting coverage gaps in partially-covered
/// production files: PauseConditionManager, MetricKitSubscriber, AppDelegate, and
/// related service helpers. Overlay tests previously hosted here were retired by
/// `#920` along with the `OverlayManager` UIWindow path.
@MainActor
final class ServiceCoverageBoostTests: XCTestCase {

    // MARK: - PauseConditionManager — Additional Edge Cases

    func test_pauseConditionManager_doubleStartMonitoring_doesNotDuplicate() {
        let settings = SettingsStore(store: MockSettingsPersisting())
        let focus = MockFocusStatusDetector()
        let carPlay = MockCarPlayDetector()
        let driving = MockDrivingActivityDetector()
        let mgr = PauseConditionManager(
            settings: settings, focusDetector: focus,
            carPlayDetector: carPlay, drivingDetector: driving)
        mgr.startMonitoring()
        mgr.startMonitoring() // second call should tear down and re-register
        XCTAssertEqual(focus.startMonitoringCallCount, 2)
        mgr.stopMonitoring()
    }

    func test_pauseConditionManager_stopMonitoring_clearsAllConditions() {
        let settings = SettingsStore(store: MockSettingsPersisting())
        settings.pauseDuringFocus = true
        let focus = MockFocusStatusDetector()
        let carPlay = MockCarPlayDetector()
        let driving = MockDrivingActivityDetector()
        let mgr = PauseConditionManager(
            settings: settings, focusDetector: focus,
            carPlayDetector: carPlay, drivingDetector: driving)
        mgr.startMonitoring()
        focus.simulateFocusChange(true)
        XCTAssertTrue(mgr.isPaused)
        mgr.stopMonitoring()
        XCTAssertFalse(mgr.isPaused)
    }

    func test_pauseConditionManager_allThreeConditionsActive() {
        let settings = SettingsStore(store: MockSettingsPersisting())
        settings.pauseDuringFocus = true
        settings.pauseWhileDriving = true
        let focus = MockFocusStatusDetector()
        let carPlay = MockCarPlayDetector()
        let driving = MockDrivingActivityDetector()
        let mgr = PauseConditionManager(
            settings: settings, focusDetector: focus,
            carPlayDetector: carPlay, drivingDetector: driving)
        mgr.startMonitoring()
        focus.simulateFocusChange(true)
        carPlay.simulateCarPlayChange(true)
        driving.simulateDrivingChange(true)
        XCTAssertTrue(mgr.isPaused)
        // Remove one — should stay paused
        focus.simulateFocusChange(false)
        XCTAssertTrue(mgr.isPaused)
        // Remove second — still paused (driving active)
        carPlay.simulateCarPlayChange(false)
        XCTAssertTrue(mgr.isPaused)
        // Remove last — now unpaused
        driving.simulateDrivingChange(false)
        XCTAssertFalse(mgr.isPaused)
        mgr.stopMonitoring()
    }

    func test_pauseConditionManager_settingsToggle_reevaluatesConditions() {
        let persistence = MockSettingsPersisting()
        let settings = SettingsStore(store: persistence)
        settings.pauseDuringFocus = true
        let focus = MockFocusStatusDetector()
        let mgr = PauseConditionManager(
            settings: settings, focusDetector: focus,
            carPlayDetector: MockCarPlayDetector(),
            drivingDetector: MockDrivingActivityDetector())
        mgr.startMonitoring()
        focus.simulateFocusChange(true)
        XCTAssertTrue(mgr.isPaused)
        // Disable pauseDuringFocus — should unpause
        settings.pauseDuringFocus = false
        XCTAssertFalse(mgr.isPaused)
        mgr.stopMonitoring()
    }

    func test_pauseConditionManager_drivingSettingsToggle_reevaluatesBoth() {
        let persistence = MockSettingsPersisting()
        let settings = SettingsStore(store: persistence)
        settings.pauseWhileDriving = true
        let carPlay = MockCarPlayDetector()
        let driving = MockDrivingActivityDetector()
        let mgr = PauseConditionManager(
            settings: settings, focusDetector: MockFocusStatusDetector(),
            carPlayDetector: carPlay, drivingDetector: driving)
        mgr.startMonitoring()
        carPlay.simulateCarPlayChange(true)
        driving.simulateDrivingChange(true)
        XCTAssertTrue(mgr.isPaused)
        // Disable pauseWhileDriving — both carPlay and driving should clear
        settings.pauseWhileDriving = false
        XCTAssertFalse(mgr.isPaused)
        mgr.stopMonitoring()
    }

    func test_pauseConditionManager_onPauseStateChanged_fires() {
        let settings = SettingsStore(store: MockSettingsPersisting())
        settings.pauseDuringFocus = true
        let focus = MockFocusStatusDetector()
        let mgr = PauseConditionManager(
            settings: settings, focusDetector: focus,
            carPlayDetector: MockCarPlayDetector(),
            drivingDetector: MockDrivingActivityDetector())
        var stateChanges: [Bool] = []
        mgr.onPauseStateChanged = { stateChanges.append($0) }
        mgr.startMonitoring()
        focus.simulateFocusChange(true)
        focus.simulateFocusChange(false)
        XCTAssertEqual(stateChanges, [true, false])
        mgr.stopMonitoring()
    }

    func test_pauseConditionManager_initialState_propagated() {
        let settings = SettingsStore(store: MockSettingsPersisting())
        settings.pauseDuringFocus = true
        let focus = MockFocusStatusDetector()
        // Pre-set focus state before starting monitoring
        focus.simulateFocusChange(true)
        let mgr = PauseConditionManager(
            settings: settings, focusDetector: focus,
            carPlayDetector: MockCarPlayDetector(),
            drivingDetector: MockDrivingActivityDetector())
        mgr.startMonitoring()
        // Initial state should be propagated
        XCTAssertTrue(mgr.isPaused)
        mgr.stopMonitoring()
    }

    // MARK: - MetricKitSubscriber

    func test_metricKitSubscriber_shared_isNotNil() {
        XCTAssertNotNil(MetricKitSubscriber.shared)
    }

    func test_metricKitSubscriber_register_doesNotCrash() {
        MetricKitSubscriber.shared.register()
    }

    func test_metricKitSubscriber_didReceiveMetricPayloads_emptyArray() {
        let emptyMetrics: [MXMetricPayload] = []
        MetricKitSubscriber.shared.didReceive(emptyMetrics)
    }

    func test_metricKitSubscriber_didReceiveDiagnosticPayloads_emptyArray() {
        let emptyDiagnostics: [MXDiagnosticPayload] = []
        MetricKitSubscriber.shared.didReceive(emptyDiagnostics)
    }

    // MARK: - AppDelegate

    func test_appDelegate_initAndSetStore() {
        let delegate = AppDelegate()
        let store = Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.notificationClient = NotificationClient(
                requestAuthorization: { _ in false },
                authorizationStatus: { .notDetermined },
                add: { _ in },
                removePending: { _ in },
                removeAllPending: {},
                pendingRequests: { [] },
                deliveredNotifications: { [] }
            )
        }
        delegate.store = store
        XCTAssertNotNil(delegate.store)
    }

    func test_appDelegate_applicationDidBecomeActive_withNilStore() {
        let delegate = AppDelegate()
        delegate.store = nil
        delegate.applicationDidBecomeActive(UIApplication.shared)
        // Should not crash — store?.send(...) silently exits when store is nil.
    }

    func test_appDelegate_applicationDidBecomeActive_withStore() {
        let delegate = AppDelegate()
        delegate.store = Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.analyticsClient = AnalyticsClient(log: { _ in })
        }
        delegate.applicationDidBecomeActive(UIApplication.shared)
    }

}

// MARK: - Additional Service Coverage (split to stay under type_body_length)
@MainActor
final class ServiceCoverageBoostTests2: XCTestCase {

    // MARK: - AudioInterruptionManager

    func test_audioInterruptionManager_pauseAndResume() {
        let mgr = AudioInterruptionManager()
        mgr.pauseExternalAudio()
        mgr.resumeExternalAudio()
    }

    func test_audioInterruptionManager_resumeWithoutPause() {
        let mgr = AudioInterruptionManager()
        mgr.resumeExternalAudio()
    }

    func test_audioInterruptionManager_doublePause() {
        let mgr = AudioInterruptionManager()
        mgr.pauseExternalAudio()
        mgr.pauseExternalAudio()
        mgr.resumeExternalAudio()
    }

    // MARK: - MockMediaControlling

    func test_mockMediaControlling_reset() {
        let mock = MockMediaControlling()
        mock.pauseExternalAudio()
        mock.resumeExternalAudio()
        XCTAssertEqual(mock.pauseCallCount, 1)
        XCTAssertEqual(mock.resumeCallCount, 1)
        mock.reset()
        XCTAssertEqual(mock.pauseCallCount, 0)
        XCTAssertEqual(mock.resumeCallCount, 0)
    }

    // MARK: - ReminderType — Additional Coverage

    func test_reminderType_categoryIdentifier_eyes() {
        let type = ReminderType(categoryIdentifier: ReminderType.eyes.categoryIdentifier)
        XCTAssertEqual(type, .eyes)
    }

    func test_reminderType_categoryIdentifier_posture() {
        let type = ReminderType(categoryIdentifier: ReminderType.posture.categoryIdentifier)
        XCTAssertEqual(type, .posture)
    }

    func test_reminderType_categoryIdentifier_invalid() {
        let type = ReminderType(categoryIdentifier: "unknown.category")
        XCTAssertNil(type)
    }

    func test_reminderType_overlayTitle_nonEmpty() {
        XCTAssertFalse(ReminderType.eyes.overlayTitle.isEmpty)
        XCTAssertFalse(ReminderType.posture.overlayTitle.isEmpty)
    }

    func test_reminderType_overlaySupportiveText_nonEmpty() {
        XCTAssertFalse(ReminderType.eyes.overlaySupportiveText.isEmpty)
        XCTAssertFalse(ReminderType.posture.overlaySupportiveText.isEmpty)
    }

    func test_reminderType_symbolName_nonEmpty() {
        XCTAssertFalse(ReminderType.eyes.symbolName.isEmpty)
        XCTAssertFalse(ReminderType.posture.symbolName.isEmpty)
    }

    func test_reminderType_title_nonEmpty() {
        XCTAssertFalse(ReminderType.eyes.title.isEmpty)
        XCTAssertFalse(ReminderType.posture.title.isEmpty)
    }

    // MARK: - AppConfig

    func test_appConfig_fallbackValues() {
        let config = AppConfig.fallback
        XCTAssertGreaterThan(config.defaults.eyeInterval, 0)
        XCTAssertGreaterThan(config.defaults.postureInterval, 0)
        XCTAssertGreaterThan(config.defaults.eyeBreakDuration, 0)
        XCTAssertGreaterThan(config.defaults.postureBreakDuration, 0)
        XCTAssertGreaterThan(config.features.maxSnoozeCount, 0)
    }

    func test_appConfig_loadFromBundle() {
        let config = AppConfig.load()
        XCTAssertGreaterThan(config.defaults.eyeInterval, 0)
    }

    // MARK: - AnalyticsLogger

    func test_analyticsLogger_logEvent_doesNotCrash() {
        AnalyticsLogger.log(.overlayDismissed(type: .eyes, method: .button, elapsedS: 5))
        AnalyticsLogger.log(.overlayDismissed(type: .posture, method: .swipe, elapsedS: 3))
        AnalyticsLogger.log(.overlayAutoDismissed(type: .eyes, durationS: 20))
        AnalyticsLogger.log(.overlayAutoDismissed(type: .posture, durationS: 10))
    }

    // MARK: - PauseConditionSource

    func test_pauseConditionSource_hashable() {
        let sources: Set<PauseConditionSource> = [.focusMode, .carPlay, .driving]
        XCTAssertEqual(sources.count, 3)
    }

    func test_pauseConditionSource_equality() {
        XCTAssertEqual(PauseConditionSource.focusMode, .focusMode)
        XCTAssertNotEqual(PauseConditionSource.focusMode, .carPlay)
        XCTAssertNotEqual(PauseConditionSource.carPlay, .driving)
    }

    // MARK: - LegalDocument Additional

    func test_legalDocument_allCases() {
        let terms = LegalDocument.terms
        let privacy = LegalDocument.privacy
        XCTAssertTrue(terms != privacy)
    }

    // MARK: - MockPauseConditionProvider

    func test_mockPauseConditionProvider_fullLifecycle() {
        let mock = MockPauseConditionProvider()
        XCTAssertFalse(mock.isPaused)
        mock.startMonitoring()
        mock.simulatePauseStateChange(true)
        XCTAssertTrue(mock.isPaused)
        mock.stopMonitoring()
    }

    func test_mockPauseConditionProvider_callback() {
        let mock = MockPauseConditionProvider()
        var changes: [Bool] = []
        mock.onPauseStateChanged = { changes.append($0) }
        mock.simulatePauseStateChange(true)
        mock.simulatePauseStateChange(false)
        XCTAssertEqual(changes, [true, false])
    }

    // MARK: - MockScreenTimeTracker

    func test_mockScreenTimeTracker_lifecycle() {
        let mock = MockScreenTimeTracker()
        mock.startMonitoring()
        mock.stopMonitoring()
        XCTAssertEqual(mock.startMonitoringCallCount, 1)
        XCTAssertEqual(mock.stopMonitoringCallCount, 1)
    }

    // MARK: - MockReminderScheduler

    func test_mockReminderScheduler_schedule() async {
        let mock = MockReminderScheduler()
        await mock.scheduleReminders(using: SettingsStore(store: MockSettingsPersisting()))
        XCTAssertEqual(mock.scheduleRemindersCallCount, 1)
    }

    func test_mockReminderScheduler_cancelAll() {
        let mock = MockReminderScheduler()
        mock.cancelAllReminders()
        XCTAssertEqual(mock.cancelAllCallCount, 1)
    }
}
