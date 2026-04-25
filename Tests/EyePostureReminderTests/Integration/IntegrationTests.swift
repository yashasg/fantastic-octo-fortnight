import Combine
@testable import EyePostureReminder
import XCTest

// MARK: - SettingsStore ↔ SettingsViewModel Integration

/// Verifies that real `SettingsStore` and real `SettingsViewModel` share state
/// correctly. Uses a real `UserDefaults` suite (isolated per test) instead of
/// `MockSettingsPersisting` to validate the full persistence round-trip.
@MainActor
final class SettingsStoreViewModelIntegrationTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var store: SettingsStore!
    private var viewModel: SettingsViewModel!
    private var scheduler: MockReminderScheduler!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "com.epr.integration.storevm.\(UUID().uuidString)"
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        store = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        scheduler = MockReminderScheduler()
        viewModel = SettingsViewModel(settings: store, scheduler: scheduler)
        cancellables = []
    }

    override func tearDown() async throws {
        cancellables = nil
        viewModel = nil
        scheduler = nil
        store = nil
        userDefaults.removeSuite(named: suiteName)
        userDefaults = nil
        suiteName = nil
        try await super.tearDown()
    }

    // MARK: Store → ViewModel reflection

    func test_storeChange_globalEnabled_reflectedInViewModel() {
        store.globalEnabled = false
        XCTAssertFalse(
            viewModel.settings.globalEnabled,
            "ViewModel.settings.globalEnabled must mirror direct SettingsStore mutation")
    }

    func test_storeChange_eyesInterval_reflectedInViewModel() {
        store.eyesInterval = 600
        XCTAssertEqual(
            viewModel.settings.eyesInterval,
            600,
            "ViewModel.settings.eyesInterval must reflect SettingsStore mutation")
    }

    func test_storeChange_pauseDuringFocus_reflectedInViewModel() {
        store.pauseDuringFocus = false
        XCTAssertFalse(
            viewModel.pauseDuringFocus,
            "ViewModel.pauseDuringFocus computed property must mirror SettingsStore")
    }

    func test_storeChange_pauseWhileDriving_reflectedInViewModel() {
        store.pauseWhileDriving = false
        XCTAssertFalse(
            viewModel.pauseWhileDriving,
            "ViewModel.pauseWhileDriving computed property must mirror SettingsStore")
    }

    // MARK: ViewModel → UserDefaults persistence

    func test_viewModelWrite_globalEnabled_persistsToUserDefaults() {
        store.globalEnabled = false
        XCTAssertNotNil(
            userDefaults.object(forKey: "epr.globalEnabled"),
            "SettingsStore must write globalEnabled to real UserDefaults immediately")
        XCTAssertFalse(
            userDefaults.bool(forKey: "epr.globalEnabled"),
            "Persisted globalEnabled must be false")
    }

    func test_viewModelWrite_eyesInterval_persistsToUserDefaults() {
        store.eyesInterval = 1800
        XCTAssertEqual(
            userDefaults.double(forKey: "epr.eyes.interval"),
            1800,
            "SettingsStore must write eyesInterval to real UserDefaults")
    }

    func test_viewModelWrite_pauseDuringFocus_persistsViaViewModelProxy() {
        viewModel.pauseDuringFocus = false
        XCTAssertNotNil(
            userDefaults.object(forKey: "epr.pauseDuringFocus"),
            "ViewModel setter must flow through SettingsStore into real UserDefaults")
        XCTAssertFalse(userDefaults.bool(forKey: "epr.pauseDuringFocus"))
    }

    func test_viewModelWrite_pauseWhileDriving_persistsViaViewModelProxy() {
        viewModel.pauseWhileDriving = false
        XCTAssertFalse(
            userDefaults.bool(forKey: "epr.pauseWhileDriving"),
            "ViewModel setter must persist pauseWhileDriving to UserDefaults")
    }

    // MARK: Reload survival

    func test_settingWrittenThroughStore_survivesStoreReload() {
        store.eyesInterval = 2700
        // Simulate app restart: create a new SettingsStore from the same UserDefaults suite.
        let reloaded = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        XCTAssertEqual(
            reloaded.eyesInterval,
            2700,
            "Value written through SettingsStore must survive a reload from the same UserDefaults suite")
    }

    func test_multipleSettingsMutation_allSurviveReload() {
        store.eyesInterval = 600
        store.postureInterval = 3600
        store.globalEnabled = false
        store.pauseDuringFocus = false

        let reloaded = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        XCTAssertEqual(reloaded.eyesInterval, 600)
        XCTAssertEqual(reloaded.postureInterval, 3600)
        XCTAssertFalse(reloaded.globalEnabled)
        XCTAssertFalse(reloaded.pauseDuringFocus)
    }

    // MARK: Snooze round-trip

    func test_snoozeApplied_viaSetter_persistedToUserDefaults() {
        let future = Date().addingTimeInterval(300)
        store.snoozedUntil = future
        XCTAssertNotNil(
            userDefaults.object(forKey: "epr.snoozedUntil"),
            "snoozedUntil must be written to real UserDefaults")
        let stored = userDefaults.double(forKey: "epr.snoozedUntil")
        XCTAssertGreaterThan(stored, 0, "Persisted snoozedUntil timestamp must be positive")
    }

    func test_snooze_cancelledViaViewModel_clearsUserDefaults() async {
        store.snoozedUntil = Date().addingTimeInterval(300)
        store.snoozeCount = 1

        viewModel.cancelSnooze()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNil(store.snoozedUntil, "cancelSnooze must clear snoozedUntil on SettingsStore")
        XCTAssertEqual(store.snoozeCount, 0, "cancelSnooze must reset snoozeCount to 0")
        let raw = userDefaults.double(forKey: "epr.snoozedUntil")
        XCTAssertEqual(raw, 0, "Persisted snoozedUntil must be 0 after cancel")
    }

    // MARK: Published change propagation

    func test_publishedChange_eyesInterval_receivedBySubscriber() {
        var received: [TimeInterval] = []
        store.$eyesInterval
            .dropFirst()
            .sink { received.append($0) }
            .store(in: &cancellables)

        store.eyesInterval = 600
        store.eyesInterval = 1200

        XCTAssertEqual(
            received,
            [600, 1200],
            "Subscribers must receive every @Published eyesInterval change in order")
    }

    func test_publishedChange_globalEnabled_triggersDownstreamAction() async {
        store.globalEnabled = true
        viewModel.globalToggleChanged()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(
            scheduler.scheduleRemindersCallCount,
            1,
            "globalToggleChanged with globalEnabled=true must invoke scheduleReminders")
        XCTAssertTrue(
            scheduler.lastScheduledSettings === store,
            "scheduleReminders must receive the same real SettingsStore instance")
    }
}

// MARK: - AppConfig → SettingsStore First Launch Integration

/// Verifies the data-driven defaults pipeline using real `UserDefaults` suites
/// (no `MockSettingsPersisting`). Each test gets a fresh suite to avoid pollution.
final class AppConfigSettingsStoreIntegrationTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "com.epr.integration.config.\(UUID().uuidString)"
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        userDefaults.removeSuite(named: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: Fresh UserDefaults + AppConfig.fallback

    func test_freshUserDefaults_eyesInterval_loadedFromFallback() {
        let sut = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        XCTAssertEqual(
            sut.eyesInterval,
            AppConfig.fallback.defaults.eyeInterval,
            "Fresh UserDefaults must yield eyesInterval from AppConfig.fallback")
    }

    func test_freshUserDefaults_postureInterval_loadedFromFallback() {
        let sut = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        XCTAssertEqual(
            sut.postureInterval,
            AppConfig.fallback.defaults.postureInterval,
            "Fresh UserDefaults must yield postureInterval from AppConfig.fallback")
    }

    func test_freshUserDefaults_eyesBreakDuration_loadedFromFallback() {
        let sut = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        XCTAssertEqual(
            sut.eyesBreakDuration,
            AppConfig.fallback.defaults.eyeBreakDuration,
            "Fresh UserDefaults must yield eyesBreakDuration from AppConfig.fallback")
    }

    func test_freshUserDefaults_postureBreakDuration_loadedFromFallback() {
        let sut = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        XCTAssertEqual(
            sut.postureBreakDuration,
            AppConfig.fallback.defaults.postureBreakDuration,
            "Fresh UserDefaults must yield postureBreakDuration from AppConfig.fallback")
    }

    func test_freshUserDefaults_globalEnabled_loadedFromFallback() {
        let sut = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        XCTAssertEqual(
            sut.globalEnabled,
            AppConfig.fallback.features.globalEnabledDefault,
            "Fresh UserDefaults must yield globalEnabled from AppConfig.fallback")
    }

    // MARK: Fresh UserDefaults + test fixture AppConfig

    func test_freshUserDefaults_eyesInterval_loadedFromTestFixture() {
        let testBundle = Bundle(for: AppConfigIntegrationTests.self)
        let fixtureConfig = AppConfig.load(from: testBundle)
        let sut = SettingsStore(store: userDefaults, config: fixtureConfig)
        XCTAssertEqual(
            sut.eyesInterval,
            fixtureConfig.defaults.eyeInterval,
            "Fresh UserDefaults must use values from injected AppConfig (fixture: 900s)")
    }

    func test_freshUserDefaults_postureInterval_loadedFromTestFixture() {
        let testBundle = Bundle(for: AppConfigIntegrationTests.self)
        let fixtureConfig = AppConfig.load(from: testBundle)
        let sut = SettingsStore(store: userDefaults, config: fixtureConfig)
        XCTAssertEqual(
            sut.postureInterval,
            fixtureConfig.defaults.postureInterval,
            "Fresh UserDefaults must use postureInterval from injected AppConfig (fixture: 2700s)")
    }

    // MARK: Pre-populated UserDefaults: user values win over JSON

    func test_prePopulated_eyesInterval_userValueWins() {
        userDefaults.set(600.0, forKey: "epr.eyes.interval")
        let sut = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        XCTAssertEqual(
            sut.eyesInterval,
            600,
            "Pre-populated UserDefaults value must win over AppConfig fallback")
    }

    func test_prePopulated_postureInterval_userValueWins() {
        userDefaults.set(3600.0, forKey: "epr.posture.interval")
        let sut = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        XCTAssertEqual(
            sut.postureInterval,
            3600,
            "Pre-populated posture interval must win over AppConfig fallback")
    }

    func test_prePopulated_globalEnabled_false_userValueWins() {
        userDefaults.set(false, forKey: "epr.globalEnabled")
        let sut = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        XCTAssertFalse(
            sut.globalEnabled,
            "Pre-populated globalEnabled=false must win over AppConfig.fallback.features.globalEnabledDefault (true)")
    }

    func test_prePopulated_allKeys_userValuesWin() {
        userDefaults.set(300.0, forKey: "epr.eyes.interval")
        userDefaults.set(5.0, forKey: "epr.eyes.breakDuration")
        userDefaults.set(600.0, forKey: "epr.posture.interval")
        userDefaults.set(5.0, forKey: "epr.posture.breakDuration")
        userDefaults.set(false, forKey: "epr.globalEnabled")

        let sut = SettingsStore(store: userDefaults, config: AppConfig.fallback)

        XCTAssertEqual(sut.eyesInterval, 300)
        XCTAssertEqual(sut.eyesBreakDuration, 5)
        XCTAssertEqual(sut.postureInterval, 600)
        XCTAssertEqual(sut.postureBreakDuration, 5)
        XCTAssertFalse(sut.globalEnabled)
    }

    // MARK: Different configs produce different defaults

    func test_customConfig_producesExpectedDefaults_onFreshSuite() {
        let customConfig = AppConfig(
            defaults: AppConfig.Defaults(
                eyeInterval: 300,
                eyeBreakDuration: 5,
                postureInterval: 600,
                postureBreakDuration: 5
            ),
            features: AppConfig.Features(globalEnabledDefault: false, maxSnoozeCount: 1)
        )
        let sut = SettingsStore(store: userDefaults, config: customConfig)
        XCTAssertEqual(
            sut.eyesInterval,
            300,
            "Fresh suite with custom config must use that config's eyeInterval")
        XCTAssertFalse(
            sut.globalEnabled,
            "Fresh suite with custom config must use globalEnabledDefault=false")
    }
}

// MARK: - PauseConditionManager ↔ SettingsStore Integration

/// Verifies that `PauseConditionManager` correctly reads from a real `SettingsStore`
/// backed by a real `UserDefaults` suite. Detector system calls are replaced with
/// mocks so no hardware or OS APIs are exercised.
@MainActor
final class PauseSettingsIntegrationTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var store: SettingsStore!
    private var focusDetector: MockFocusStatusDetector!
    private var carPlayDetector: MockCarPlayDetector!
    private var drivingDetector: MockDrivingActivityDetector!
    private var sut: PauseConditionManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "com.epr.integration.pause.\(UUID().uuidString)"
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        store = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        focusDetector = MockFocusStatusDetector()
        carPlayDetector = MockCarPlayDetector()
        drivingDetector = MockDrivingActivityDetector()
        sut = PauseConditionManager(
            settings: store,
            focusDetector: focusDetector,
            carPlayDetector: carPlayDetector,
            drivingDetector: drivingDetector
        )
        sut.startMonitoring()
    }

    override func tearDown() {
        sut.stopMonitoring()
        sut = nil
        drivingDetector = nil
        carPlayDetector = nil
        focusDetector = nil
        store = nil
        userDefaults.removeSuite(named: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: pauseDuringFocus=false: focus events ignored

    func test_pauseDuringFocusFalse_focusEventIgnored() {
        store.pauseDuringFocus = false
        focusDetector.simulateFocusChange(true)
        XCTAssertFalse(
            sut.isPaused,
            "With pauseDuringFocus=false from real SettingsStore, focus event must be ignored")
    }

    func test_pauseDuringFocusTrue_focusEventRespected() {
        store.pauseDuringFocus = true
        focusDetector.simulateFocusChange(true)
        XCTAssertTrue(
            sut.isPaused,
            "With pauseDuringFocus=true from real SettingsStore, focus event must pause")
    }

    // MARK: pauseWhileDriving=false: driving/CarPlay events ignored

    func test_pauseWhileDrivingFalse_drivingEventIgnored() {
        store.pauseWhileDriving = false
        drivingDetector.simulateDrivingChange(true)
        XCTAssertFalse(
            sut.isPaused,
            "With pauseWhileDriving=false from real SettingsStore, driving event must be ignored")
    }

    func test_pauseWhileDrivingFalse_carPlayEventIgnored() {
        store.pauseWhileDriving = false
        carPlayDetector.simulateCarPlayChange(true)
        XCTAssertFalse(
            sut.isPaused,
            "With pauseWhileDriving=false from real SettingsStore, CarPlay event must be ignored")
    }

    // MARK: Setting toggle mid-session

    func test_togglePauseDuringFocus_midSession_newEventsRespectNewValue() {
        // Start with focus pause disabled — focus fires, should not pause.
        store.pauseDuringFocus = false
        focusDetector.simulateFocusChange(true)
        XCTAssertFalse(sut.isPaused, "Pre-condition: focus ignored while pauseDuringFocus=false")

        // User enables the setting mid-session. Fire a new focus event.
        store.pauseDuringFocus = true
        focusDetector.simulateFocusChange(false) // clear
        focusDetector.simulateFocusChange(true)  // re-fire with new setting
        XCTAssertTrue(
            sut.isPaused,
            "After enabling pauseDuringFocus, subsequent focus events must cause a pause")
    }

    func test_togglePauseWhileDriving_midSession_newEventsRespectNewValue() {
        // Start with driving pause disabled.
        store.pauseWhileDriving = false
        drivingDetector.simulateDrivingChange(true)
        XCTAssertFalse(sut.isPaused, "Pre-condition: driving ignored while pauseWhileDriving=false")

        // User enables the setting. Next driving event should cause a pause.
        store.pauseWhileDriving = true
        drivingDetector.simulateDrivingChange(false)
        drivingDetector.simulateDrivingChange(true)
        XCTAssertTrue(
            sut.isPaused,
            "After enabling pauseWhileDriving, subsequent driving events must cause a pause")
    }

    // MARK: Callback fires correctly

    func test_pauseStateChangedCallback_firedOnFocusPause() {
        store.pauseDuringFocus = true
        var callbackValues: [Bool] = []
        sut.onPauseStateChanged = { callbackValues.append($0) }

        focusDetector.simulateFocusChange(true)
        focusDetector.simulateFocusChange(false)

        XCTAssertEqual(
            callbackValues,
            [true, false],
            "onPauseStateChanged must fire true then false as focus activates then clears")
    }

    // MARK: Real UserDefaults persistence round-trip

    func test_storeValuePersisted_pauseSettingReadCorrectly() {
        // Simulate a second launch: pre-set the value in UserDefaults before creating the store.
        userDefaults.set(false, forKey: "epr.pauseDuringFocus")
        let reloadedStore = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        let freshManager = PauseConditionManager(
            settings: reloadedStore,
            focusDetector: focusDetector,
            carPlayDetector: carPlayDetector,
            drivingDetector: drivingDetector
        )
        freshManager.startMonitoring()
        defer { freshManager.stopMonitoring() }

        focusDetector.simulateFocusChange(true)
        XCTAssertFalse(
            freshManager.isPaused,
            "Manager built from reloaded store with persisted pauseDuringFocus=false must ignore focus")
    }
}

// MARK: - AppConfig Integration Helpers
//
// Reuse this class reference for Bundle(for:) when loading the test fixture config.
private final class AppConfigIntegrationTests {}
