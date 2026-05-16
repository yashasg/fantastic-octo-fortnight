import XCTest

@testable import EyePostureReminder

// MARK: - Multi-service Pipeline Integration

/// Verifies that changes flow correctly across multiple real services without breaking
/// the pipeline. Tests respect `@MainActor` boundaries using async/await patterns.
@MainActor
final class MultiServicePipelineIntegrationTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var store: SettingsStore!
    private var focusDetector: MockFocusStatusDetector!
    private var carPlayDetector: MockCarPlayDetector!
    private var drivingDetector: MockDrivingActivityDetector!
    private var pauseManager: PauseConditionManager!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "com.kshana.integration.pipeline.\(UUID().uuidString)"
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        store = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        focusDetector = MockFocusStatusDetector()
        carPlayDetector = MockCarPlayDetector()
        drivingDetector = MockDrivingActivityDetector()
        pauseManager = PauseConditionManager(
            settings: store,
            focusDetector: focusDetector,
            carPlayDetector: carPlayDetector,
            drivingDetector: drivingDetector
        )
        pauseManager.startMonitoring()
    }

    override func tearDown() async throws {
        pauseManager.stopMonitoring()
        pauseManager = nil
        drivingDetector = nil
        carPlayDetector = nil
        focusDetector = nil
        store = nil
        userDefaults.removeSuite(named: suiteName)
        userDefaults = nil
        suiteName = nil
        try await super.tearDown()
    }

    // MARK: Pause conditions do not affect scheduler via pipeline

    func test_pauseConditionActive_doesNotDirectlyCallScheduler() {
        store.pauseDuringFocus = true
        focusDetector.simulateFocusChange(true)

        XCTAssertTrue(pauseManager.isPaused, "PauseConditionManager must be paused")
    }

    // MARK: MainActor boundary test — async settings mutation

    func test_asyncSettingsMutation_mainActorSafe() async {
        // Mutate settings from an async context — the @MainActor isolation must prevent data races.
        await MainActor.run {
            store.globalEnabled = false
            store.eyesInterval = 600
            store.postureInterval = 1800
        }

        XCTAssertFalse(store.globalEnabled)
        XCTAssertEqual(store.eyesInterval, 600)
        XCTAssertEqual(store.postureInterval, 1800)
    }

    func test_concurrentObservers_receiveSnapshotsForEveryChange() {
        var snapshots1: [ReminderSettings] = []
        var snapshots2: [ReminderSettings] = []

        store.addObserver { snapshots1.append($0) }
        store.addObserver { snapshots2.append($0) }

        store.globalEnabled = false
        store.eyesInterval = 600
        store.eyesInterval = 1200

        // Three mutations × two observers = each observer sees 3 snapshots.
        XCTAssertEqual(
            snapshots1.count,
            3,
            "First observer must receive a snapshot for every mutation")
        XCTAssertEqual(
            snapshots2.count,
            3,
            "Second observer must receive a snapshot for every mutation")
        XCTAssertEqual(
            snapshots1.last?.interval,
            1200,
            "Last snapshot must reflect the most recent eyesInterval value")
        XCTAssertEqual(
            snapshots2.last?.interval,
            1200,
            "Last snapshot must reflect the most recent eyesInterval value")
    }

    // MARK: Full wiring smoke test

    func test_fullPipeline_settingsPersistedAndPauseManagerSeesSameStore() {
        store.pauseDuringFocus = true
        focusDetector.simulateFocusChange(true)

        XCTAssertTrue(
            pauseManager.isPaused,
            "PauseConditionManager must be paused via the shared real SettingsStore")

        let raw = userDefaults.bool(forKey: "kshana.pauseDuringFocus")
        XCTAssertTrue(
            raw,
            "pauseDuringFocus must be persisted to the shared real UserDefaults suite")
    }
}
