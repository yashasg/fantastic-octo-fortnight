import XCTest

@testable import EyePostureReminder

// MARK: - AppConfig → SettingsStore First Launch Integration

/// Verifies the data-driven defaults pipeline using real `UserDefaults` suites
/// (no `MockSettingsPersisting`). Each test gets a fresh suite to avoid pollution.
@MainActor
final class AppConfigSettingsStoreIntegrationTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "com.kshana.integration.config.\(UUID().uuidString)"
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
        userDefaults.set(600.0, forKey: "kshana.eyes.interval")
        let sut = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        XCTAssertEqual(
            sut.eyesInterval,
            600,
            "Pre-populated UserDefaults value must win over AppConfig fallback")
    }

    func test_prePopulated_postureInterval_userValueWins() {
        userDefaults.set(3600.0, forKey: "kshana.posture.interval")
        let sut = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        XCTAssertEqual(
            sut.postureInterval,
            3600,
            "Pre-populated posture interval must win over AppConfig fallback")
    }

    func test_prePopulated_globalEnabled_false_userValueWins() {
        userDefaults.set(false, forKey: "kshana.globalEnabled")
        let sut = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        XCTAssertFalse(
            sut.globalEnabled,
            "Pre-populated globalEnabled=false must win over AppConfig.fallback.features.globalEnabledDefault (true)")
    }

    func test_prePopulated_allKeys_userValuesWin() {
        userDefaults.set(300.0, forKey: "kshana.eyes.interval")
        userDefaults.set(5.0, forKey: "kshana.eyes.breakDuration")
        userDefaults.set(600.0, forKey: "kshana.posture.interval")
        userDefaults.set(5.0, forKey: "kshana.posture.breakDuration")
        userDefaults.set(false, forKey: "kshana.globalEnabled")

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
        suiteName = "com.kshana.integration.pause.\(UUID().uuidString)"
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
        userDefaults.set(false, forKey: "kshana.pauseDuringFocus")
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
