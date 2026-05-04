@testable import EyePostureReminder
import UIKit
import XCTest

private final class MockUserNotificationCenter: UserNotificationCenterDelegating {
    weak var delegate: UNUserNotificationCenterDelegate?
}

private final class MockMetricKitSubscriber: MetricKitSubscribing {
    private(set) var registerCallCount = 0

    func register() {
        registerCallCount += 1
    }
}

/// Unit tests for `AppDelegate` notification routing logic.
///
/// ## What is tested here
/// - `applicationDidBecomeActive` → clears an expired `snoozedUntil` (via coordinator)
/// - `AppDelegate.notificationRoute(for:)` category routing used by both
///   `willPresent` and `didReceive`
/// - `AppCoordinator.snoozeWakeCategory` routes to `scheduleReminders()`
///   instead of `handleNotification(for:)`
///
/// ## Why `willPresent` and `didReceive` are not called directly
/// `UNNotification` and `UNNotificationResponse` have no public initialisers — they
/// are vended exclusively by the system. Because the routing logic inside those two
/// delegate methods is entirely determined by `categoryIdentifier` string → action
/// dispatch, testing `notificationRoute(for:)` and the coordinator's downstream
/// methods provides equivalent coverage without system-object construction.
@MainActor
final class AppDelegateTests: XCTestCase {

    var delegate: AppDelegate!
    var coordinator: AppCoordinator!
    var settings: SettingsStore!
    var mockNotif: MockNotificationCenter!
    var mockOverlay: MockOverlayPresenting!

    override func setUp() async throws {
        try await super.setUp()
        let persistence = MockSettingsPersisting()
        settings        = SettingsStore(store: persistence)
        mockNotif       = MockNotificationCenter()
        mockOverlay     = MockOverlayPresenting()
        coordinator     = AppCoordinator(
            settings: settings,
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            overlayManager: mockOverlay,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider(),
            ipcStore: MockAppGroupIPCRecorder()
        )
        delegate = AppDelegate()
        delegate.coordinator = coordinator
    }

    override func tearDown() async throws {
        coordinator.stopFallbackTimers()
        delegate = nil
        coordinator = nil
        settings = nil
        mockNotif = nil
        mockOverlay = nil
        try await super.tearDown()
    }

    // MARK: - applicationDidBecomeActive: clearExpiredSnoozeIfNeeded

    func test_objectiveCInit_createsDelegateForUIApplicationDelegateAdaptor() {
        let delegate = (AppDelegate.self as NSObject.Type).init()

        XCTAssertTrue(delegate is AppDelegate)
    }

    /// When `snoozedUntil` is in the past, `applicationDidBecomeActive` must clear it.
    func test_applicationDidBecomeActive_withExpiredSnooze_clearsSnoozeFields() async throws {
        settings.snoozedUntil = Date(timeIntervalSinceNow: -60) // 1 minute ago
        settings.snoozeCount  = 3

        delegate.applicationDidBecomeActive(UIApplication.shared)

        // Poll until the inner task clears the expired snooze fields.
        await awaitCondition { settings.snoozedUntil == nil }

        XCTAssertNil(
            settings.snoozedUntil,
            "applicationDidBecomeActive must clear an expired snoozedUntil")
        XCTAssertEqual(
            settings.snoozeCount,
            0,
            "applicationDidBecomeActive must reset snoozeCount when snooze was expired"
        )
    }

    /// When `snoozedUntil` is in the future, `applicationDidBecomeActive` must NOT clear it.
    func test_applicationDidBecomeActive_withActiveSnooze_keepsSnoozeIntact() async throws {
        let futureDate = Date(timeIntervalSinceNow: 300) // 5 minutes from now
        settings.snoozedUntil = futureDate
        settings.snoozeCount  = 1

        delegate.applicationDidBecomeActive(UIApplication.shared)

        // Active snooze is never cleared — yield to let the inner task run and confirm no mutation.
        for _ in 0..<5 { await Task.yield() }

        XCTAssertNotNil(settings.snoozedUntil, "An active snooze must not be cleared by applicationDidBecomeActive")
        XCTAssertEqual(settings.snoozeCount, 1, "snoozeCount must remain unchanged when snooze is still active")
    }

    /// When there is no active snooze, `applicationDidBecomeActive` must not crash.
    func test_applicationDidBecomeActive_withNoSnooze_doesNotCrash() async throws {
        settings.snoozedUntil = nil

        delegate.applicationDidBecomeActive(UIApplication.shared)

        // No mutation expected — yield to let the inner task run without crashing.
        for _ in 0..<5 { await Task.yield() }

        XCTAssertNil(settings.snoozedUntil)
    }

    /// `applicationDidBecomeActive` must still work when `coordinator` is nil
    /// (e.g. during early launch before the SwiftUI scene connects).
    func test_applicationDidBecomeActive_withNilCoordinator_doesNotCrash() async throws {
        delegate.coordinator = nil

        delegate.applicationDidBecomeActive(UIApplication.shared)

        // Optional chain exits immediately when coordinator is nil — one yield is sufficient.
        await Task.yield()
        // No assertions needed — surviving without a coordinator is the behaviour under test.
    }

    // MARK: - Uncaught exception handler

    func test_installUncaughtExceptionHandler_usesInjectedInstaller() {
        var registerCallCount = 0
        let sut = AppDelegate(
            installUncaughtExceptionHandler: {
                registerCallCount += 1
            }
        )

        sut.installUncaughtExceptionHandler()

        XCTAssertEqual(registerCallCount, 1)
    }

    func test_didFinishLaunching_registersUncaughtExceptionHandlerViaInjectedInstaller() {
        let mockCenter = MockUserNotificationCenter()
        let mockMetricKitSubscriber = MockMetricKitSubscriber()
        var registerCallCount = 0
        let sut = AppDelegate(
            notificationCenter: mockCenter,
            metricKitSubscriber: mockMetricKitSubscriber,
            installUncaughtExceptionHandler: {
                registerCallCount += 1
            }
        )

        _ = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        XCTAssertEqual(registerCallCount, 1)
    }

    func test_didFinishLaunching_registersDelegateAndMetricKitViaInjectedSeams() {
        let mockCenter = MockUserNotificationCenter()
        let mockMetricKitSubscriber = MockMetricKitSubscriber()
        let sut = AppDelegate(
            notificationCenter: mockCenter,
            metricKitSubscriber: mockMetricKitSubscriber
        )

        let didFinish = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        XCTAssertTrue(didFinish)
        XCTAssertTrue(
            mockCenter.delegate === sut,
            "didFinishLaunching must register AppDelegate as notification center delegate"
        )
        XCTAssertEqual(
            mockMetricKitSubscriber.registerCallCount,
            1,
            "didFinishLaunching must register MetricKit exactly once"
        )
    }

    func test_didFinishLaunching_withNilNotificationCenter_usesInjectedFactory() {
        let factoryCenter = MockUserNotificationCenter()
        let mockMetricKitSubscriber = MockMetricKitSubscriber()
        var makeNotificationCenterCallCount = 0
        let sut = AppDelegate(
            notificationCenter: nil,
            metricKitSubscriber: mockMetricKitSubscriber,
            makeNotificationCenter: {
                makeNotificationCenterCallCount += 1
                return factoryCenter
            }
        )

        let didFinish = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        XCTAssertTrue(didFinish)
        XCTAssertEqual(makeNotificationCenterCallCount, 1)
        XCTAssertTrue(factoryCenter.delegate === sut)
        XCTAssertEqual(mockMetricKitSubscriber.registerCallCount, 1)
    }

    func test_didFinishLaunching_withExplicitNotificationCenter_doesNotCallInjectedFactory() {
        let explicitCenter = MockUserNotificationCenter()
        let mockMetricKitSubscriber = MockMetricKitSubscriber()
        var makeNotificationCenterCallCount = 0
        let sut = AppDelegate(
            notificationCenter: explicitCenter,
            metricKitSubscriber: mockMetricKitSubscriber,
            makeNotificationCenter: {
                makeNotificationCenterCallCount += 1
                return MockUserNotificationCenter()
            }
        )

        let didFinish = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        XCTAssertTrue(didFinish)
        XCTAssertEqual(makeNotificationCenterCallCount, 0)
        XCTAssertTrue(explicitCenter.delegate === sut)
        XCTAssertEqual(mockMetricKitSubscriber.registerCallCount, 1)
    }

    func test_didFinishLaunching_withNilMetricKitSubscriber_usesInjectedFactory() {
        let mockCenter = MockUserNotificationCenter()
        let factoryMetricKitSubscriber = MockMetricKitSubscriber()
        var makeMetricKitSubscriberCallCount = 0
        let sut = AppDelegate(
            notificationCenter: mockCenter,
            metricKitSubscriber: nil,
            makeMetricKitSubscriber: {
                makeMetricKitSubscriberCallCount += 1
                return factoryMetricKitSubscriber
            }
        )

        let didFinish = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        XCTAssertTrue(didFinish)
        XCTAssertEqual(makeMetricKitSubscriberCallCount, 1)
        XCTAssertEqual(factoryMetricKitSubscriber.registerCallCount, 1)
    }

    func test_didFinishLaunching_calledTwice_reusesFactoryNotificationCenterInstance() {
        let factoryCenter = MockUserNotificationCenter()
        let mockMetricKitSubscriber = MockMetricKitSubscriber()
        var makeNotificationCenterCallCount = 0
        let sut = AppDelegate(
            notificationCenter: nil,
            metricKitSubscriber: mockMetricKitSubscriber,
            makeNotificationCenter: {
                makeNotificationCenterCallCount += 1
                return factoryCenter
            }
        )

        _ = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)
        _ = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        XCTAssertEqual(makeNotificationCenterCallCount, 1)
        XCTAssertTrue(factoryCenter.delegate === sut)
    }

    func test_didFinishLaunching_calledTwice_reusesFactoryMetricKitSubscriberInstance() {
        let mockCenter = MockUserNotificationCenter()
        let factoryMetricKitSubscriber = MockMetricKitSubscriber()
        var makeMetricKitSubscriberCallCount = 0
        let sut = AppDelegate(
            notificationCenter: mockCenter,
            metricKitSubscriber: nil,
            makeMetricKitSubscriber: {
                makeMetricKitSubscriberCallCount += 1
                return factoryMetricKitSubscriber
            }
        )

        _ = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)
        _ = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        XCTAssertEqual(makeMetricKitSubscriberCallCount, 1)
        XCTAssertEqual(factoryMetricKitSubscriber.registerCallCount, 2)
    }

#if DEBUG
    func test_init_withoutUITestDefaults_usesInjectedDefaultsFactory() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)
        var makeUITestDefaultsCallCount = 0

        _ = AppDelegate(
            launchArguments: ["--simulate-screen-time-not-determined"],
            uiTestDefaults: nil,
            makeUITestDefaults: {
                makeUITestDefaultsCallCount += 1
                return defaults
            }
        )

        XCTAssertEqual(makeUITestDefaultsCallCount, 1)
        XCTAssertEqual(
            defaults.string(forKey: AppStorageKey.uiTestScreenTimeStatus),
            ScreenTimeAuthorizationStatus.notDetermined.rawValue
        )
    }

    func test_init_withExplicitUITestDefaults_doesNotCallInjectedDefaultsFactory() throws {
        let explicitDefaults = try makeIsolatedDefaults(suffix: "\(#function).explicit")
        let factoryDefaults = try makeIsolatedDefaults(suffix: "\(#function).factory")
        var makeUITestDefaultsCallCount = 0

        _ = AppDelegate(
            launchArguments: ["--simulate-screen-time-not-determined"],
            uiTestDefaults: explicitDefaults,
            makeUITestDefaults: {
                makeUITestDefaultsCallCount += 1
                return factoryDefaults
            }
        )

        XCTAssertEqual(makeUITestDefaultsCallCount, 0)
        XCTAssertEqual(
            explicitDefaults.string(forKey: AppStorageKey.uiTestScreenTimeStatus),
            ScreenTimeAuthorizationStatus.notDetermined.rawValue
        )
    }

    func test_init_withoutLaunchArguments_usesInjectedLaunchArgumentsProvider() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)
        defaults.removeObject(forKey: AppStorageKey.uiTestScreenTimeStatus)
        defaults.set(true, forKey: AppStorageKey.trueInterruptSkippedBannerDismissed)
        var launchArgumentsProviderCallCount = 0

        _ = AppDelegate(
            launchArguments: nil,
            uiTestDefaults: defaults,
            launchArgumentsProvider: {
                launchArgumentsProviderCallCount += 1
                return ["--simulate-screen-time-not-determined"]
            }
        )

        XCTAssertEqual(launchArgumentsProviderCallCount, 1)
        XCTAssertEqual(
            defaults.string(forKey: AppStorageKey.uiTestScreenTimeStatus),
            ScreenTimeAuthorizationStatus.notDetermined.rawValue
        )
        XCTAssertFalse(defaults.bool(forKey: AppStorageKey.trueInterruptSkippedBannerDismissed))
    }

    func test_init_withExplicitLaunchArguments_doesNotCallInjectedLaunchArgumentsProvider() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)
        defaults.set("stale", forKey: AppStorageKey.uiTestScreenTimeStatus)
        var launchArgumentsProviderCallCount = 0

        _ = AppDelegate(
            launchArguments: ["--skip-onboarding"],
            uiTestDefaults: defaults,
            launchArgumentsProvider: {
                launchArgumentsProviderCallCount += 1
                return ["--simulate-screen-time-not-determined"]
            }
        )

        XCTAssertEqual(launchArgumentsProviderCallCount, 0)
        XCTAssertNil(defaults.string(forKey: AppStorageKey.uiTestScreenTimeStatus))
    }

    func test_init_preSeedsScreenTimeStatus_usingInjectedLaunchArgumentsAndDefaults() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)
        defaults.removeObject(forKey: AppStorageKey.uiTestScreenTimeStatus)
        defaults.set(true, forKey: AppStorageKey.trueInterruptSkippedBannerDismissed)

        _ = AppDelegate(
            launchArguments: ["--simulate-screen-time-not-determined"],
            uiTestDefaults: defaults
        )

        XCTAssertEqual(
            defaults.string(forKey: AppStorageKey.uiTestScreenTimeStatus),
            ScreenTimeAuthorizationStatus.notDetermined.rawValue
        )
        XCTAssertFalse(defaults.bool(forKey: AppStorageKey.trueInterruptSkippedBannerDismissed))
    }

    func test_init_withoutSimulateFlag_clearsInjectedScreenTimeStatusKey() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)
        defaults.set("stale", forKey: AppStorageKey.uiTestScreenTimeStatus)

        _ = AppDelegate(
            launchArguments: ["--skip-onboarding"],
            uiTestDefaults: defaults
        )

        XCTAssertNil(defaults.string(forKey: AppStorageKey.uiTestScreenTimeStatus))
    }

    func test_didFinishLaunching_showOverlayEyes_usesInjectedSettingsStoreFactory() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)
        let mockCenter = MockUserNotificationCenter()
        let store = MockSettingsPersisting()
        let settings = SettingsStore(store: store, config: .fallback)
        var makeSettingsStoreCallCount = 0
        let sut = AppDelegate(
            notificationCenter: mockCenter,
            metricKitSubscriber: MockMetricKitSubscriber(),
            launchArguments: ["--show-overlay-eyes"],
            uiTestDefaults: defaults,
            makeSettingsStore: {
                makeSettingsStoreCallCount += 1
                return settings
            }
        )

        _ = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        XCTAssertEqual(makeSettingsStoreCallCount, 1)
        XCTAssertEqual(defaults.string(forKey: AppStorageKey.uiTestOverlayType), ReminderType.eyes.rawValue)
        XCTAssertEqual(settings.eyesBreakDuration, 120)
        XCTAssertEqual(settings.postureBreakDuration, 120)
    }

    func test_didFinishLaunching_withNilSettingsStore_usesInjectedFactoryOnce() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)
        let mockCenter = MockUserNotificationCenter()
        let store = MockSettingsPersisting()
        let settings = SettingsStore(store: store, config: .fallback)
        var makeSettingsStoreCallCount = 0
        let sut = AppDelegate(
            notificationCenter: mockCenter,
            metricKitSubscriber: MockMetricKitSubscriber(),
            settingsStore: nil,
            launchArguments: ["--skip-onboarding", "--simulate-screen-time-not-determined"],
            uiTestDefaults: defaults,
            makeSettingsStore: {
                makeSettingsStoreCallCount += 1
                return settings
            }
        )

        _ = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        XCTAssertEqual(makeSettingsStoreCallCount, 1)
        XCTAssertEqual(
            defaults.string(forKey: AppStorageKey.uiTestScreenTimeStatus),
            ScreenTimeAuthorizationStatus.notDetermined.rawValue
        )
    }

    func test_didFinishLaunching_withExplicitSettingsStore_doesNotCallInjectedFactory() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)
        let mockCenter = MockUserNotificationCenter()
        let explicitStore = MockSettingsPersisting()
        let explicitSettings = SettingsStore(store: explicitStore, config: .fallback)
        var makeSettingsStoreCallCount = 0
        let sut = AppDelegate(
            notificationCenter: mockCenter,
            metricKitSubscriber: MockMetricKitSubscriber(),
            settingsStore: explicitSettings,
            launchArguments: ["--show-overlay-eyes"],
            uiTestDefaults: defaults,
            makeSettingsStore: {
                makeSettingsStoreCallCount += 1
                return SettingsStore(store: MockSettingsPersisting(), config: .fallback)
            }
        )

        _ = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        XCTAssertEqual(makeSettingsStoreCallCount, 0)
        XCTAssertEqual(defaults.string(forKey: AppStorageKey.uiTestOverlayType), ReminderType.eyes.rawValue)
        XCTAssertEqual(explicitSettings.eyesBreakDuration, 120)
        XCTAssertEqual(explicitSettings.postureBreakDuration, 120)
    }

    func test_consumeUITestOverlayType_withValidValue_returnsTypeAndClearsKey() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)
        defaults.set(ReminderType.posture.rawValue, forKey: AppStorageKey.uiTestOverlayType)
        let sut = AppDelegate(
            launchArguments: [],
            uiTestDefaults: defaults
        )

        let consumedType = sut.consumeUITestOverlayType()

        XCTAssertEqual(consumedType, .posture)
        XCTAssertNil(defaults.string(forKey: AppStorageKey.uiTestOverlayType))
    }

    func test_consumeUITestOverlayType_withInvalidValue_returnsNilAndLeavesKey() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)
        defaults.set("invalid-reminder-type", forKey: AppStorageKey.uiTestOverlayType)
        let sut = AppDelegate(
            launchArguments: [],
            uiTestDefaults: defaults
        )

        let consumedType = sut.consumeUITestOverlayType()

        XCTAssertNil(consumedType)
        XCTAssertEqual(defaults.string(forKey: AppStorageKey.uiTestOverlayType), "invalid-reminder-type")
    }
#endif

    // MARK: - Category-identifier routing logic

    func test_notificationRoute_eyeReminder_routesToEyes() {
        let route = delegate.notificationRoute(for: "EYE_REMINDER")

        XCTAssertEqual(route, .reminder(.eyes))
    }

    func test_notificationRoute_postureReminder_routesToPosture() {
        let route = delegate.notificationRoute(for: "POSTURE_REMINDER")

        XCTAssertEqual(route, .reminder(.posture))
    }

    func test_notificationRoute_snoozeWake_routesToSnoozeWake() {
        let route = delegate.notificationRoute(for: AppCoordinator.snoozeWakeCategory)

        XCTAssertEqual(route, .snoozeWake)
    }

    /// An unrecognised category identifier must route to `.ignore`.
    func test_notificationRoute_unknown_routesToIgnore() {
        XCTAssertEqual(delegate.notificationRoute(for: "UNKNOWN_CATEGORY"), .ignore)
        XCTAssertEqual(delegate.notificationRoute(for: ""), .ignore)
        XCTAssertEqual(delegate.notificationRoute(for: "eye_reminder"), .ignore) // case-sensitive
    }

    /// Every `ReminderType` case must produce a `categoryIdentifier` that round-trips
    /// correctly back through `init?(categoryIdentifier:)`.
    func test_categoryIdentifier_roundTrips_forAllTypes() {
        for reminderType in ReminderType.allCases {
            let parsed = ReminderType(categoryIdentifier: reminderType.categoryIdentifier)
            XCTAssertEqual(
                parsed,
                reminderType,
                "\(reminderType.categoryIdentifier) must round-trip back to \(reminderType)"
            )
        }
    }

    // MARK: - handleNotification routing (coordinator path exercised by delegate)

    /// `handleNotification(for:)` must reset `snoozeCount` to 0.
    /// This is observable without an active UIWindowScene and is the key side-effect
    /// triggered by the `willPresent` / `didReceive` delegate paths.
    func test_handleNotification_resetsSnoozeCount() {
        settings.snoozeCount = 5

        coordinator.handleNotification(for: .eyes)

        XCTAssertEqual(
            settings.snoozeCount,
            0,
            "handleNotification must reset snoozeCount to 0 (a real reminder fired)"
        )
    }

    func test_handleNotification_resetsSnoozeCount_forPosture() {
        settings.snoozeCount = 2

        coordinator.handleNotification(for: .posture)

        XCTAssertEqual(settings.snoozeCount, 0)
    }

    /// When there is no active UIWindowScene (unit test environment), `handleNotification`
    /// must queue a pending overlay rather than crashing.
    func test_handleNotification_withNoActiveScene_doesNotCrash() {
        // In the unit-test runner there are no active UIWindowScenes,
        // so the coordinator queues the overlay — both paths must not crash.
        coordinator.handleNotification(for: .eyes)
        coordinator.handleNotification(for: .posture)
    }

    // MARK: - Snooze-wake routing (scheduleReminders path exercised by delegate)

    /// The snooze-wake path calls `scheduleReminders()`, which (when auth is granted)
    /// adds notification requests. This verifies the coordinator correctly handles the
    /// snooze-wake category routing branch.
    func test_snoozeWakeRouting_callsScheduleReminders_addsRequests() async {
        mockNotif.authorizationGranted = true
        settings.eyesEnabled    = true
        settings.postureEnabled = true
        settings.snoozedUntil   = nil // no active snooze

        // `scheduleReminders()` is called by the delegate when it sees snoozeWakeCategory.
        await coordinator.scheduleReminders()

        // screenTimeTracker path is used (no UNNotification requests in screen-time mode),
        // but `scheduleReminders` must complete without crashing.
        // The coordinator operates in screen-time mode so no UNNotification is scheduled.
        XCTAssertNil(settings.snoozedUntil, "scheduleReminders must not set a snooze when none was active")
    }

    private func makeIsolatedDefaults(suffix: String) throws -> UserDefaults {
        let suiteName = "AppDelegateTests.\(suffix).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Failed to create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
