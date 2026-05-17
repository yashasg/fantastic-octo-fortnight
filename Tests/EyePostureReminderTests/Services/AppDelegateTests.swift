import ComposableArchitecture
import UIKit
import XCTest

@testable import EyePostureReminder

private final class MockUserNotificationCenter: UserNotificationCenterDelegating {
    weak var delegate: UNUserNotificationCenterDelegate?
}

private final class MockMetricKitSubscriber: MetricKitSubscribing {
    private(set) var registerCallCount = 0

    func register() {
        registerCallCount += 1
    }
}

// swiftlint:disable type_body_length file_length
/// Unit tests for `AppDelegate` notification routing logic.
///
/// ## What is tested here
/// - `applicationDidBecomeActive` → forwards `.clearExpiredSnoozeIfNeeded` into
///   the TCA root `Store` (no-crash plus pending-route flush behaviour); the
///   expired-snooze state mutation lives on `SchedulingFeature` and is covered
///   by the SchedulingFeature TestStore tests added in `p0-tca-17` (#680).
/// - `AppDelegate.notificationRoute(for:)` category routing used by both
///   `willPresent` and `didReceive`.
/// - Notification routes dispatched by the delegate land on the wired
///   `Store` and reach `SchedulingFeature.notificationRoutedEffect` (observable
///   through the `SettingsClient.setSnoozeCount` override below).
///
/// ## Why `willPresent` and `didReceive` are not called directly
/// `UNNotification` and `UNNotificationResponse` have no public initialisers — they
/// are vended exclusively by the system. Because the routing logic inside those two
/// delegate methods is entirely determined by `categoryIdentifier` string → action
/// dispatch, testing `notificationRoute(for:)` and the store's downstream
/// effect provides equivalent coverage without system-object construction.
@MainActor
final class AppDelegateTests: XCTestCase {

    var delegate: AppDelegate!
    var settings: SettingsStore!
    var mockNotif: MockNotificationCenter!
    var mockOverlay: MockOverlayPresenting!
    var store: StoreOf<AppFeature>!
    var snoozeCountWrites: LockIsolated<[Int]>!

    override func setUp() async throws {
        try await super.setUp()
        let persistence = MockSettingsPersisting()
        settings        = SettingsStore(store: persistence)
        mockNotif       = MockNotificationCenter()
        mockOverlay     = MockOverlayPresenting()
        snoozeCountWrites = LockIsolated<[Int]>([])
        store = Self.makeAppFeatureStore(
            settings: settings,
            snoozeCountWrites: snoozeCountWrites
        )
        delegate = AppDelegate()
        delegate.store = store
    }

    override func tearDown() async throws {
        delegate = nil
        settings = nil
        mockNotif = nil
        mockOverlay = nil
        store = nil
        snoozeCountWrites = nil
        try await super.tearDown()
    }

    /// Builds a real `StoreOf<AppFeature>` whose `SchedulingFeature` dependencies
    /// are stubbed by replacing each `DependencyKey`'s value wholesale, so the
    /// live `liveValue` factories (which spin up `LiveReminderSchedulerBridge`
    /// → `UNUserNotificationCenter.current()` and other production singletons)
    /// are never evaluated. The `SettingsClient.setSnoozeCount` override
    /// records every value into `snoozeCountWrites` and mirrors it onto the
    /// supplied `SettingsStore` so legacy assertions on
    /// `settings.snoozeCount` continue to work post-migration.
    static func makeAppFeatureStore(
        settings: SettingsStore,
        snoozeCountWrites: LockIsolated<[Int]>
    ) -> StoreOf<AppFeature> {
        // The `snapshot` closure on `SettingsClient` is `@Sendable` and therefore
        // cannot synchronously call `@MainActor`-isolated methods on
        // `SettingsStore`. Capture the eyes snapshot once on the main actor (this
        // function is invoked from a `@MainActor` test setUp) and return the
        // captured value. The `SchedulingFeature` paths under test never re-read
        // `snapshot`, so a stable initial value is sufficient.
        let initialEyesSnapshot = MainActor.assumeIsolated {
            settings.settings(for: .eyes)
        }
        return Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.settingsClient = SettingsClient(
                snapshot: { initialEyesSnapshot },
                stream: { .finished },
                postureSnapshot: { ReminderSettings(interval: 0, breakDuration: 0) },
                postureStream: { .finished },
                enabledFlagsSnapshot: { .allEnabled },
                enabledFlagsStream: { .finished },
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
                setSnoozedUntil: { value in
                    await MainActor.run { settings.snoozedUntil = value }
                },
                setSnoozeCount: { value in
                    snoozeCountWrites.withValue { $0.append(value) }
                    await MainActor.run { settings.snoozeCount = value }
                },
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
                setTrueInterruptEnabled: { _ in false },
                readSelection: { .empty },
                writeSelection: { _ in false },
                record: { _, _ in },
                trueInterruptChanges: { .finished },
                selectionChanges: { .finished }
            )
            $0.deviceActivityMonitorClient = DeviceActivityMonitorClient(
                schedule: { _, _ in },
                cancel: { _ in }
            )
            $0.analyticsClient = AnalyticsClient(log: { _ in })
        }
    }

    // MARK: - applicationDidBecomeActive: clearExpiredSnoozeIfNeeded

    func test_objectiveCInit_createsDelegateForUIApplicationDelegateAdaptor() {
        let delegate = (AppDelegate.self as NSObject.Type).init()

        XCTAssertTrue(delegate is AppDelegate)
    }

    /// `applicationDidBecomeActive` forwards the snooze-cleanup intent into the
    /// TCA `Store` via `.scheduling(.clearExpiredSnoozeIfNeeded)`. The actual
    /// `state.snoozedUntil` mutation lives on `SchedulingFeature` and is
    /// covered by the `SchedulingFeature` TestStore tests added in
    /// `p0-tca-17` (#680). Until that lands, `state.snoozedUntil` cannot be
    /// seeded through the public action surface, so this test only verifies
    /// the delegate does not crash on a wired store.
    func test_applicationDidBecomeActive_withWiredStore_doesNotCrash() async throws {
        settings.snoozedUntil = Date(timeIntervalSinceNow: -60) // 1 minute ago
        settings.snoozeCount  = 3

        delegate.applicationDidBecomeActive(UIApplication.shared)

        // Yield so the wrapped Task body invokes `store?.send(...)`.
        for _ in 0..<5 { await Task.yield() }
    }

    /// When there is no active snooze, `applicationDidBecomeActive` must not crash.
    func test_applicationDidBecomeActive_withNoSnooze_doesNotCrash() async throws {
        settings.snoozedUntil = nil

        delegate.applicationDidBecomeActive(UIApplication.shared)

        // No mutation expected — yield to let the inner task run without crashing.
        for _ in 0..<5 { await Task.yield() }

        XCTAssertNil(settings.snoozedUntil)
    }

    /// `applicationDidBecomeActive` must still work when `store` is nil
    /// (e.g. during early launch before the SwiftUI scene connects).
    func test_applicationDidBecomeActive_withNilStore_doesNotCrash() async throws {
        delegate.store = nil

        delegate.applicationDidBecomeActive(UIApplication.shared)

        // Optional chain exits immediately when store is nil — one yield is sufficient.
        await Task.yield()
        // No assertions needed — surviving without a store is the behaviour under test.
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

    /// Regression for #711: the `--show-overlay-eyes` launch arg must seed
    /// `uiTestOverlayType`, `hasSeenOnboarding`, and the inflated break
    /// durations during `init()` (before `didFinishLaunchingWithOptions`),
    /// so the `AppFeature` store seed in `EyePostureReminderApp.init()`
    /// reads the inflated `SettingsStore` values from `UserDefaults` and
    /// the overlay does not auto-dismiss before the UI test asserts on it.
    func test_init_showOverlayEyes_preSeedsOverlayDefaultsBeforeDidFinishLaunching() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)

        _ = AppDelegate(
            launchArguments: ["--show-overlay-eyes"],
            uiTestDefaults: defaults
        )

        XCTAssertEqual(defaults.string(forKey: AppStorageKey.uiTestOverlayType), ReminderType.eyes.rawValue)
        XCTAssertTrue(defaults.bool(forKey: AppStorageKey.hasSeenOnboarding))
        XCTAssertEqual(
            defaults.double(forKey: SettingsStore.Keys.eyesBreakDuration),
            AppDelegate.uiTestOverlayBreakDuration
        )
        XCTAssertEqual(
            defaults.double(forKey: SettingsStore.Keys.postureBreakDuration),
            AppDelegate.uiTestOverlayBreakDuration
        )
    }

    /// Regression for #711: `--show-overlay-posture` must pre-seed the same
    /// keys at `init()` time as `--show-overlay-eyes`, only with the
    /// posture `ReminderType` raw value.
    func test_init_showOverlayPosture_preSeedsOverlayDefaultsBeforeDidFinishLaunching() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)

        _ = AppDelegate(
            launchArguments: ["--show-overlay-posture"],
            uiTestDefaults: defaults
        )

        XCTAssertEqual(defaults.string(forKey: AppStorageKey.uiTestOverlayType), ReminderType.posture.rawValue)
        XCTAssertTrue(defaults.bool(forKey: AppStorageKey.hasSeenOnboarding))
        XCTAssertEqual(
            defaults.double(forKey: SettingsStore.Keys.eyesBreakDuration),
            AppDelegate.uiTestOverlayBreakDuration
        )
        XCTAssertEqual(
            defaults.double(forKey: SettingsStore.Keys.postureBreakDuration),
            AppDelegate.uiTestOverlayBreakDuration
        )
    }

    /// Without an overlay launch arg, `applyUITestLaunchArguments()` (called
    /// from `didFinishLaunchingWithOptions`) must clear any stale
    /// `uiTestOverlayType` value left behind by a previous test launch on the
    /// same simulator so the next launch does not unexpectedly re-trigger an
    /// overlay (#711).
    func test_didFinishLaunching_withoutOverlayFlag_clearsStaleOverlayTypeKey() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)
        defaults.set(ReminderType.eyes.rawValue, forKey: AppStorageKey.uiTestOverlayType)
        let store = MockSettingsPersisting()
        let settings = SettingsStore(store: store, config: .fallback)
        let sut = AppDelegate(
            notificationCenter: MockUserNotificationCenter(),
            metricKitSubscriber: MockMetricKitSubscriber(),
            settingsStore: settings,
            launchArguments: ["--skip-onboarding"],
            uiTestDefaults: defaults
        )

        _ = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        XCTAssertNil(defaults.string(forKey: AppStorageKey.uiTestOverlayType))
    }

    /// The full launch sequence (init + didFinishLaunching) must leave the
    /// inflated break durations intact even after
    /// `SettingsStore.resetToDefaults()` runs — the regression in #711 was
    /// that the reset wiped the pre-seed without re-applying it.
    func test_didFinishLaunching_showOverlayEyes_preservesInflatedBreakDurationsAfterReset() throws {
        let defaults = try makeIsolatedDefaults(suffix: #function)
        let store = MockSettingsPersisting()
        let settings = SettingsStore(store: store, config: .fallback)
        let sut = AppDelegate(
            notificationCenter: MockUserNotificationCenter(),
            metricKitSubscriber: MockMetricKitSubscriber(),
            settingsStore: settings,
            launchArguments: ["--show-overlay-eyes"],
            uiTestDefaults: defaults
        )

        _ = sut.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)

        XCTAssertEqual(settings.eyesBreakDuration, AppDelegate.uiTestOverlayBreakDuration)
        XCTAssertEqual(settings.postureBreakDuration, AppDelegate.uiTestOverlayBreakDuration)
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
        XCTAssertEqual(settings.eyesBreakDuration, AppDelegate.uiTestOverlayBreakDuration)
        XCTAssertEqual(settings.postureBreakDuration, AppDelegate.uiTestOverlayBreakDuration)
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
        XCTAssertEqual(explicitSettings.eyesBreakDuration, AppDelegate.uiTestOverlayBreakDuration)
        XCTAssertEqual(explicitSettings.postureBreakDuration, AppDelegate.uiTestOverlayBreakDuration)
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
        let route = delegate.notificationRoute(for: SchedulingFeature.snoozeWakeCategory)

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

    func test_dispatchNotificationRoute_beforeStoreWiring_replaysReminderWhenStoreIsSet() async {
        delegate.store = nil
        settings.snoozeCount = 4
        snoozeCountWrites.setValue([])

        delegate.dispatchNotificationRoute(.reminder(.eyes))
        for _ in 0..<3 { await Task.yield() }

        XCTAssertEqual(
            settings.snoozeCount,
            4,
            "Reminder route should wait for store wiring instead of being dropped."
        )

        delegate.store = store

        await awaitCondition { self.settings.snoozeCount == 0 }
        XCTAssertEqual(settings.snoozeCount, 0)
        XCTAssertTrue(
            snoozeCountWrites.value.contains(0),
            "Replayed reminder route must reach SchedulingFeature.notificationRoutedEffect"
        )
    }

    func test_dispatchNotificationRoute_ignoreBeforeStoreWiring_isNotReplayed() async {
        delegate.store = nil
        settings.snoozeCount = 4
        snoozeCountWrites.setValue([])

        delegate.dispatchNotificationRoute(.ignore)
        for _ in 0..<3 { await Task.yield() }

        delegate.store = store
        for _ in 0..<3 { await Task.yield() }

        XCTAssertEqual(settings.snoozeCount, 4)
        XCTAssertTrue(
            snoozeCountWrites.value.isEmpty,
            "`.ignore` routes must never reach SchedulingFeature.notificationRoutedEffect"
        )
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
// swiftlint:enable type_body_length
// swiftlint:enable file_length
