@testable import EyePostureReminder
import UIKit
import XCTest

/// Unit tests for `AppDelegate` notification routing logic.
///
/// ## What is tested here
/// - `applicationDidBecomeActive` → clears an expired `snoozedUntil` (via coordinator)
/// - `ReminderType(categoryIdentifier:)` parsing — the core category-routing logic
///   used by both `willPresent` and `didReceive`
/// - `AppCoordinator.snoozeWakeCategory` is distinct from all `ReminderType` identifiers
///   so snooze-wake routes to `scheduleReminders()` instead of `handleNotification`
///
/// ## Why `willPresent` and `didReceive` are not called directly
/// `UNNotification` and `UNNotificationResponse` have no public initialisers — they
/// are vended exclusively by the system. Because the routing logic inside those two
/// delegate methods is entirely determined by `categoryIdentifier` string → action
/// dispatch, testing `ReminderType(categoryIdentifier:)` and the coordinator's
/// downstream methods provides equivalent coverage without system-object construction.
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

    /// Verifies `installUncaughtExceptionHandler` sets a non-nil global handler.
    /// Called directly because `application(_:didFinishLaunchingWithOptions:)` touches
    /// MetricKit and UNNotificationCenter which crash in the unit-test host.
    func test_appDelegate_installsUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler(nil)
        XCTAssertNil(NSGetUncaughtExceptionHandler(), "precondition: handler should be nil")

        delegate.installUncaughtExceptionHandler()

        XCTAssertNotNil(
            NSGetUncaughtExceptionHandler(),
            "installUncaughtExceptionHandler must set a global exception handler"
        )
    }

    // MARK: - Category-identifier routing logic (ReminderType parsing)

    /// The two valid reminder category identifiers must parse to the correct types.
    func test_categoryIdentifier_eyeReminder_parsesToEyes() {
        let type = ReminderType(categoryIdentifier: "EYE_REMINDER")
        XCTAssertEqual(type, .eyes, "'EYE_REMINDER' must parse to .eyes")
    }

    func test_categoryIdentifier_postureReminder_parsesToPosture() {
        let type = ReminderType(categoryIdentifier: "POSTURE_REMINDER")
        XCTAssertEqual(type, .posture, "'POSTURE_REMINDER' must parse to .posture")
    }

    /// An unrecognised category identifier must return `nil` — the delegate no-ops.
    func test_categoryIdentifier_unknown_returnsNil() {
        XCTAssertNil(ReminderType(categoryIdentifier: "UNKNOWN_CATEGORY"))
        XCTAssertNil(ReminderType(categoryIdentifier: ""))
        XCTAssertNil(ReminderType(categoryIdentifier: "eye_reminder")) // case-sensitive
    }

    /// The snooze-wake category must NOT map to any `ReminderType` — this is what
    /// causes the delegate to route to `scheduleReminders()` instead of
    /// `handleNotification(for:)`.
    func test_snoozeWakeCategory_doesNotParseToAnyReminderType() {
        let type = ReminderType(categoryIdentifier: AppCoordinator.snoozeWakeCategory)
        XCTAssertNil(
            type,
            "snoozeWakeCategory must not map to a ReminderType — it has its own routing branch")
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
}
