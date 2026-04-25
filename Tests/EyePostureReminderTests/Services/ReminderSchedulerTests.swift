@testable import EyePostureReminder
import UserNotifications
import XCTest

@MainActor
// swiftlint:disable:next type_body_length
final class ReminderSchedulerTests: XCTestCase {

    var mockCenter: MockNotificationCenter!
    var mockPersistence: MockSettingsPersisting!
    var settings: SettingsStore!
    var sut: ReminderScheduler!

    override func setUp() {
        super.setUp()
        mockCenter = MockNotificationCenter()
        mockPersistence = MockSettingsPersisting()
        settings = SettingsStore(store: mockPersistence)
        sut = ReminderScheduler(notificationCenter: mockCenter)
    }

    override func tearDown() {
        sut = nil
        settings = nil
        mockPersistence = nil
        mockCenter = nil
        super.tearDown()
    }

    // MARK: - scheduleReminders — request count

    func test_scheduleAll_bothEnabled_addsTwoRequests() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true

        await sut.scheduleReminders(using: settings)

        XCTAssertEqual(mockCenter.addedRequests.count, 2)
    }

    func test_scheduleAll_globalDisabled_addsNoRequests() async {
        settings.globalEnabled = false
        settings.eyesEnabled = true
        settings.postureEnabled = true

        await sut.scheduleReminders(using: settings)

        XCTAssertTrue(mockCenter.addedRequests.isEmpty)
    }

    func test_scheduleAll_eyesDisabled_addsOnlyPostureRequest() async {
        settings.globalEnabled = true
        settings.eyesEnabled = false
        settings.postureEnabled = true

        await sut.scheduleReminders(using: settings)

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        XCTAssertEqual(
            mockCenter.addedRequests.first?.content.categoryIdentifier,
            ReminderType.posture.categoryIdentifier
        )
    }

    func test_scheduleAll_postureDisabled_addsOnlyEyesRequest() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = false

        await sut.scheduleReminders(using: settings)

        XCTAssertEqual(mockCenter.addedRequests.count, 1)
        XCTAssertEqual(
            mockCenter.addedRequests.first?.content.categoryIdentifier,
            ReminderType.eyes.categoryIdentifier
        )
    }

    func test_scheduleAll_bothDisabled_addsNoRequests() async {
        settings.globalEnabled = true
        settings.eyesEnabled = false
        settings.postureEnabled = false

        await sut.scheduleReminders(using: settings)

        XCTAssertTrue(mockCenter.addedRequests.isEmpty)
    }

    // MARK: - rescheduleReminder — cancel-before-add contract

    func test_reschedule_cancelsExistingBeforeAdding() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true

        // First schedule
        await sut.rescheduleReminder(for: .eyes, using: settings)
        XCTAssertEqual(mockCenter.addedRequests.count, 1)

        // Change interval and reschedule
        settings.eyesInterval = 600
        await sut.rescheduleReminder(for: .eyes, using: settings)

        // Cancel must have been called before the second add
        XCTAssertFalse(
            mockCenter.removedIdentifiers.isEmpty,
            "reschedule must cancel the previous request before adding a new one")
        XCTAssertEqual(mockCenter.addedRequests.count, 2, "Second schedule should produce a second add")
        XCTAssertEqual(mockCenter.pendingRequests.count, 1, "Only one pending request should remain after reschedule")
    }

    func test_reschedule_whenDisabled_removesAndDoesNotAdd() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true

        await sut.rescheduleReminder(for: .eyes, using: settings)
        XCTAssertEqual(mockCenter.pendingRequests.count, 1)

        settings.eyesEnabled = false
        await sut.rescheduleReminder(for: .eyes, using: settings)

        XCTAssertEqual(
            mockCenter.pendingRequests.count,
            0,
            "Rescheduling a disabled type must remove the existing request")
        XCTAssertEqual(mockCenter.addedRequests.count, 1, "No new add should occur when type is disabled")
    }

    func test_reschedule_onlyAffectsTargetType() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true

        await sut.scheduleReminders(using: settings)
        XCTAssertEqual(mockCenter.pendingRequests.count, 2)

        // Reschedule only eyes
        settings.eyesInterval = 600
        await sut.rescheduleReminder(for: .eyes, using: settings)

        // Posture should still be pending
        XCTAssertEqual(mockCenter.pendingRequests.count, 2)
        let postureStillPending = mockCenter.pendingRequests.contains {
            $0.content.categoryIdentifier == ReminderType.posture.categoryIdentifier
        }
        XCTAssertTrue(postureStillPending, "Rescheduling eyes must not affect posture notification")
    }

    // MARK: - cancelReminder

    func test_cancelReminder_removesCorrectIdentifier() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true
        await sut.scheduleReminders(using: settings)

        sut.cancelReminder(for: .eyes)

        XCTAssertEqual(mockCenter.pendingRequests.count, 1)
        XCTAssertEqual(
            mockCenter.pendingRequests.first?.content.categoryIdentifier,
            ReminderType.posture.categoryIdentifier,
            "After cancelling eyes, only posture should remain"
        )
    }

    func test_cancelReminder_forPosture_leavesEyesPending() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true
        await sut.scheduleReminders(using: settings)

        sut.cancelReminder(for: .posture)

        XCTAssertEqual(mockCenter.pendingRequests.count, 1)
        XCTAssertEqual(
            mockCenter.pendingRequests.first?.content.categoryIdentifier,
            ReminderType.eyes.categoryIdentifier
        )
    }

    // MARK: - cancelAllReminders

    func test_cancelAll_callsRemoveAll() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true
        await sut.scheduleReminders(using: settings)

        sut.cancelAllReminders()

        XCTAssertEqual(mockCenter.removeAllCallCount, 1)
    }

    func test_cancelAll_clearsAllPendingRequests() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true
        await sut.scheduleReminders(using: settings)

        sut.cancelAllReminders()

        XCTAssertTrue(mockCenter.pendingRequests.isEmpty)
    }

    func test_cancelAll_whenNothingScheduled_doesNotCrash() {
        sut.cancelAllReminders()
        XCTAssertEqual(mockCenter.removeAllCallCount, 1)
    }

    // MARK: - Notification content: Eyes

    func test_eyesNotification_title_matchesSpec() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = false

        await sut.scheduleReminders(using: settings)

        XCTAssertEqual(mockCenter.addedRequests.first?.content.title, "👁 Eye Break")
    }

    func test_eyesNotification_body_matchesSpec() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = false

        await sut.scheduleReminders(using: settings)

        XCTAssertEqual(
            mockCenter.addedRequests.first?.content.body,
            "Look 20 ft away for 20 seconds."
        )
    }

    func test_eyesNotification_categoryIdentifier_matchesSpec() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = false

        await sut.scheduleReminders(using: settings)

        XCTAssertEqual(mockCenter.addedRequests.first?.content.categoryIdentifier, "EYE_REMINDER")
    }

    // MARK: - Notification content: Posture

    func test_postureNotification_title_matchesSpec() async {
        settings.globalEnabled = true
        settings.eyesEnabled = false
        settings.postureEnabled = true

        await sut.scheduleReminders(using: settings)

        XCTAssertEqual(mockCenter.addedRequests.first?.content.title, "🧍 Posture Check")
    }

    func test_postureNotification_body_matchesSpec() async {
        settings.globalEnabled = true
        settings.eyesEnabled = false
        settings.postureEnabled = true

        await sut.scheduleReminders(using: settings)

        XCTAssertEqual(
            mockCenter.addedRequests.first?.content.body,
            "Sit up straight and roll your shoulders."
        )
    }

    func test_postureNotification_categoryIdentifier_matchesSpec() async {
        settings.globalEnabled = true
        settings.eyesEnabled = false
        settings.postureEnabled = true

        await sut.scheduleReminders(using: settings)

        XCTAssertEqual(mockCenter.addedRequests.first?.content.categoryIdentifier, "POSTURE_REMINDER")
    }

    // MARK: - Trigger: repeats = true

    func test_eyesTrigger_repeatsIsTrue() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = false

        await sut.scheduleReminders(using: settings)

        let trigger = mockCenter.addedRequests.first?.trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertEqual(trigger?.repeats, true, "Eyes notification trigger must have repeats = true")
    }

    func test_postureTrigger_repeatsIsTrue() async {
        settings.globalEnabled = true
        settings.eyesEnabled = false
        settings.postureEnabled = true

        await sut.scheduleReminders(using: settings)

        let trigger = mockCenter.addedRequests.first?.trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertEqual(trigger?.repeats, true, "Posture notification trigger must have repeats = true")
    }

    // MARK: - Trigger: repeats = false for short intervals (< 60s)

    func test_eyesTrigger_shortInterval_repeatsIsFalse() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = false
        settings.eyesInterval = 30 // < 60s

        await sut.scheduleReminders(using: settings)

        let trigger = mockCenter.addedRequests.first?.trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertEqual(
            trigger?.repeats,
            false,
            "Intervals < 60s must use repeats: false to satisfy UNTimeIntervalNotificationTrigger constraint")
    }

    func test_postureTrigger_shortInterval_repeatsIsFalse() async {
        settings.globalEnabled = true
        settings.eyesEnabled = false
        settings.postureEnabled = true
        settings.postureInterval = 30 // < 60s

        await sut.scheduleReminders(using: settings)

        let trigger = mockCenter.addedRequests.first?.trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertEqual(
            trigger?.repeats,
            false,
            "Intervals < 60s must use repeats: false to satisfy UNTimeIntervalNotificationTrigger constraint")
    }

    // MARK: - Trigger: timeInterval matches settings

    func test_eyesTrigger_timeInterval_matchesSettingsInterval() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = false
        settings.eyesInterval = 600

        await sut.scheduleReminders(using: settings)

        let trigger = mockCenter.addedRequests.first?.trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertEqual(trigger?.timeInterval, 600)
    }

    func test_postureTrigger_timeInterval_matchesSettingsInterval() async {
        settings.globalEnabled = true
        settings.eyesEnabled = false
        settings.postureEnabled = true
        settings.postureInterval = 2700

        await sut.scheduleReminders(using: settings)

        let trigger = mockCenter.addedRequests.first?.trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertEqual(trigger?.timeInterval, 2700)
    }

    // MARK: - Notification Identifiers

    func test_requestIdentifiers_areUnique() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true

        await sut.scheduleReminders(using: settings)

        let identifiers = mockCenter.addedRequests.map { $0.identifier }
        XCTAssertEqual(
            Set(identifiers).count,
            identifiers.count,
            "Each reminder type must use a distinct notification identifier")
    }

    func test_eyesRequest_identifierContainsEyes() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = false

        await sut.scheduleReminders(using: settings)

        let identifier = mockCenter.addedRequests.first?.identifier ?? ""
        XCTAssertTrue(
            identifier.contains("eyes"),
            "Eyes notification identifier should contain 'eyes', got: \(identifier)")
    }

    func test_postureRequest_identifierContainsPosture() async {
        settings.globalEnabled = true
        settings.eyesEnabled = false
        settings.postureEnabled = true

        await sut.scheduleReminders(using: settings)

        let identifier = mockCenter.addedRequests.first?.identifier ?? ""
        XCTAssertTrue(
            identifier.contains("posture"),
            "Posture notification identifier should contain 'posture', got: \(identifier)")
    }

    // MARK: - getPendingNotificationRequests

    func test_getPendingRequests_afterScheduleAll_returnsTwo() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true

        await sut.scheduleReminders(using: settings)

        let pending = await mockCenter.getPendingNotificationRequests()
        XCTAssertEqual(pending.count, 2)
    }

    func test_getPendingRequests_afterCancelAll_isEmpty() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true
        await sut.scheduleReminders(using: settings)

        sut.cancelAllReminders()

        let pending = await mockCenter.getPendingNotificationRequests()
        XCTAssertTrue(pending.isEmpty)
    }

    // MARK: - Edge Case: add() throws (permission denied simulation)

    func test_addThrows_doesNotCrash_andLogsGracefully() async {
        mockCenter.addError = NSError(
            domain: "UNErrorDomain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Notifications not authorized"])
        settings.globalEnabled = true
        settings.eyesEnabled = true

        // Must not throw or crash
        await sut.rescheduleReminder(for: .eyes, using: settings)

        XCTAssertTrue(
            mockCenter.addedRequests.isEmpty,
            "No request should be added when the notification center throws")
    }

    func test_addThrows_forOneType_doesNotPreventOtherType() async {
        // Fail on first add (eyes), succeed on second (posture).
        // Verifies the scheduler loops over all types regardless of individual failures.
        let failOnceCenter = FailOnceNotificationCenter()
        let scheduler = ReminderScheduler(notificationCenter: failOnceCenter)

        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true

        await scheduler.scheduleReminders(using: settings)

        // Both types should have been attempted (eyes fails, posture succeeds).
        XCTAssertGreaterThanOrEqual(
            failOnceCenter.addAttemptCount,
            2,
            "Scheduler must attempt to add all types even if the first add fails")
    }

    // MARK: - Overlapping Reminders

    func test_scheduleAllTwice_secondCallReplacesFirst() async {
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true

        await sut.scheduleReminders(using: settings)
        await sut.scheduleReminders(using: settings)

        // After two full scheduleAll calls, there should still be exactly 2 pending
        XCTAssertEqual(
            mockCenter.pendingRequests.count,
            2,
            "Scheduling all twice must not stack duplicate requests")
    }
}

// MARK: - Test Helper: FailOnceNotificationCenter

/// A mock that throws on the first `add()` call, then succeeds.
/// Used to verify that a scheduling failure for one type doesn't prevent others.
private final class FailOnceNotificationCenter: NotificationScheduling {
    private(set) var addAttemptCount = 0
    private var hasFailed = false

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }

    func getAuthorizationStatus() async -> UNAuthorizationStatus { .authorized }

    func add(_ request: UNNotificationRequest) async throws {
        addAttemptCount += 1
        if !hasFailed {
            hasFailed = true
            throw NSError(domain: "UNErrorDomain", code: 1)
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
    func removeAllPendingNotificationRequests() {}
    func getPendingNotificationRequests() async -> [UNNotificationRequest] { [] }
}
