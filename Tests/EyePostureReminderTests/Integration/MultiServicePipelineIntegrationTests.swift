import Combine
@testable import EyePostureReminder
import XCTest

// MARK: - Multi-service Pipeline Integration

/// Verifies that changes flow correctly across multiple real services without breaking
/// the pipeline. Tests respect `@MainActor` boundaries using async/await patterns.
@MainActor
final class MultiServicePipelineIntegrationTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var store: SettingsStore!
    private var scheduler: MockReminderScheduler!
    private var viewModel: SettingsViewModel!
    private var focusDetector: MockFocusStatusDetector!
    private var carPlayDetector: MockCarPlayDetector!
    private var drivingDetector: MockDrivingActivityDetector!
    private var pauseManager: PauseConditionManager!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "com.epr.integration.pipeline.\(UUID().uuidString)"
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        store = SettingsStore(store: userDefaults, config: AppConfig.fallback)
        scheduler = MockReminderScheduler()
        viewModel = SettingsViewModel(settings: store, scheduler: scheduler)
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
        cancellables = []
    }

    override func tearDown() async throws {
        pauseManager.stopMonitoring()
        cancellables = nil
        pauseManager = nil
        drivingDetector = nil
        carPlayDetector = nil
        focusDetector = nil
        viewModel = nil
        scheduler = nil
        store = nil
        userDefaults.removeSuite(named: suiteName)
        userDefaults = nil
        suiteName = nil
        try await super.tearDown()
    }

    // MARK: Settings change → ViewModel → Scheduler pipeline

    func test_eyesIntervalChange_pipelineDoesNotBreak() async {
        store.eyesInterval = 600
        viewModel.reminderSettingChanged(for: .eyes)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(
            scheduler.rescheduleCallCount,
            1,
            "Changing eyesInterval and calling reminderSettingChanged must trigger a reschedule")
        XCTAssertEqual(scheduler.lastRescheduledType, .eyes)
    }

    func test_globalToggle_off_then_on_schedulerCallsInOrder() async {
        store.globalEnabled = false
        viewModel.globalToggleChanged()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(scheduler.cancelAllCallCount, 1, "Disabling master must cancel all")

        store.globalEnabled = true
        viewModel.globalToggleChanged()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(scheduler.scheduleRemindersCallCount, 1, "Re-enabling master must schedule")
    }

    func test_settingsChange_doesNotAffectPauseConditionManager() async {
        store.eyesInterval = 900
        viewModel.reminderSettingChanged(for: .eyes)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(
            pauseManager.isPaused,
            "Changing reminder settings must not inadvertently affect PauseConditionManager state")
    }

    // MARK: Pause conditions do not affect scheduler via pipeline

    func test_pauseConditionActive_doesNotDirectlyCallScheduler() {
        store.pauseDuringFocus = true
        focusDetector.simulateFocusChange(true)

        XCTAssertTrue(pauseManager.isPaused, "PauseConditionManager must be paused")
        XCTAssertEqual(
            scheduler.cancelAllCallCount,
            0,
            "PauseConditionManager firing must not directly invoke the scheduler (AppCoordinator owns that)")
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

    func test_concurrentPublishedObservers_receiveAllChanges() async {
        var globalValues: [Bool] = []
        var intervalValues: [TimeInterval] = []

        store.$globalEnabled.dropFirst().sink { globalValues.append($0) }.store(in: &cancellables)
        store.$eyesInterval.dropFirst().sink { intervalValues.append($0) }.store(in: &cancellables)

        store.globalEnabled = false
        store.eyesInterval = 600
        store.eyesInterval = 1200

        // Give Combine publishers a moment to deliver.
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(
            globalValues,
            [false],
            "globalEnabled subscriber must receive one change")
        XCTAssertEqual(
            intervalValues,
            [600, 1200],
            "eyesInterval subscriber must receive both changes in order")
    }

    // MARK: Full wiring smoke test

    func test_fullPipeline_settingsPersistedAndPauseManagerSeesSameStore() {
        store.pauseDuringFocus = true
        focusDetector.simulateFocusChange(true)

        // Both the ViewModel and PauseConditionManager share the same SettingsStore reference.
        XCTAssertTrue(
            pauseManager.isPaused,
            "PauseConditionManager must be paused via the shared real SettingsStore")
        XCTAssertTrue(
            viewModel.settings.pauseDuringFocus,
            "ViewModel must see the same pauseDuringFocus=true on the shared store")

        let raw = userDefaults.bool(forKey: "epr.pauseDuringFocus")
        XCTAssertTrue(
            raw,
            "pauseDuringFocus must be persisted to the shared real UserDefaults suite")
    }
}
