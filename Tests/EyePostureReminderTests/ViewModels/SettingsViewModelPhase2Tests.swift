import XCTest
import Combine
@testable import EyePostureReminder

/// Phase 2 unit tests for `SettingsViewModel`.
///
/// Covers:
/// - `snooze(option:)` for all three `SnoozeOption` cases
/// - `cancelSnooze()` clearing both `snoozedUntil` and `snoozeCount`
/// - `canSnooze` enforcement of the two-snooze consecutive limit
/// - `isSnoozeActive` computed property correctness
/// - Expired-snooze detection via `isSnoozeActive`
/// - `snoozeCount` UserDefaults persistence (via MockSettingsPersisting)
/// - Integration: snooze survives settings-change reschedule
/// - Integration: snooze count resets after a reminder fires
///
/// The class is `@MainActor` because `SettingsViewModel` is main-actor isolated.
/// Inner `Task {}` dispatches are awaited with a 200 ms sleep before asserting
/// call counts (same pattern as `SettingsViewModelTests`).
@MainActor
final class SettingsViewModelPhase2Tests: XCTestCase {

    var mockPersistence: MockSettingsPersisting!
    var settings: SettingsStore!
    var mockScheduler: MockReminderScheduler!
    var sut: SettingsViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockPersistence = MockSettingsPersisting()
        settings = SettingsStore(store: mockPersistence)
        mockScheduler = MockReminderScheduler()
        sut = SettingsViewModel(settings: settings, scheduler: mockScheduler)
    }

    override func tearDown() async throws {
        sut = nil
        mockScheduler = nil
        settings = nil
        mockPersistence = nil
        try await super.tearDown()
    }

    // MARK: - snooze(option: .fiveMinutes)

    func test_snoozeOptionFiveMinutes_setsSnoozedUntilApproximately5MinFromNow() {
        let before = Date()
        sut.snooze(option: .fiveMinutes)
        let after = Date()

        let expectedMin = before.addingTimeInterval(5 * 60)
        let expectedMax = after.addingTimeInterval(5 * 60)

        XCTAssertNotNil(settings.snoozedUntil)
        XCTAssertGreaterThanOrEqual(
            settings.snoozedUntil!.timeIntervalSince1970,
            expectedMin.timeIntervalSince1970 - 1
        )
        XCTAssertLessThanOrEqual(
            settings.snoozedUntil!.timeIntervalSince1970,
            expectedMax.timeIntervalSince1970 + 1
        )
    }

    func test_snoozeOptionFiveMinutes_incrementsSnoozeCountToOne() {
        sut.snooze(option: .fiveMinutes)
        XCTAssertEqual(settings.snoozeCount, 1)
    }

    func test_snoozeOptionFiveMinutes_callsCancelAllRemindersOnce() {
        sut.snooze(option: .fiveMinutes)
        XCTAssertEqual(mockScheduler.cancelAllCallCount, 1)
    }

    func test_snoozeOptionFiveMinutes_doesNotCallScheduleReminders() {
        sut.snooze(option: .fiveMinutes)
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 0)
    }

    // MARK: - snooze(option: .oneHour)

    func test_snoozeOptionOneHour_setsSnoozedUntilApproximately1HourFromNow() {
        let before = Date()
        sut.snooze(option: .oneHour)

        XCTAssertNotNil(settings.snoozedUntil)
        XCTAssertEqual(
            settings.snoozedUntil!.timeIntervalSince1970,
            before.addingTimeInterval(60 * 60).timeIntervalSince1970,
            accuracy: 2.0
        )
    }

    func test_snoozeOptionOneHour_incrementsSnoozeCountToOne() {
        sut.snooze(option: .oneHour)
        XCTAssertEqual(settings.snoozeCount, 1)
    }

    func test_snoozeOptionOneHour_callsCancelAllRemindersOnce() {
        sut.snooze(option: .oneHour)
        XCTAssertEqual(mockScheduler.cancelAllCallCount, 1)
    }

    // MARK: - snooze(option: .restOfDay)

    func test_snoozeOptionRestOfDay_setsSnoozedUntilToStartOfNextDay() {
        sut.snooze(option: .restOfDay)

        let calendar = Calendar.current
        let expectedMidnight = calendar.date(
            byAdding: .day, value: 1,
            to: calendar.startOfDay(for: Date())
        )!

        XCTAssertNotNil(settings.snoozedUntil)
        XCTAssertEqual(
            settings.snoozedUntil!.timeIntervalSince1970,
            expectedMidnight.timeIntervalSince1970,
            accuracy: 5.0,
            "restOfDay snooze must expire at the start of the next calendar day (midnight tonight)"
        )
    }

    func test_snoozeOptionRestOfDay_setsSnoozedUntilInFuture() {
        sut.snooze(option: .restOfDay)
        XCTAssertNotNil(settings.snoozedUntil)
        XCTAssertGreaterThan(settings.snoozedUntil!, Date())
    }

    func test_snoozeOptionRestOfDay_callsCancelAllRemindersOnce() {
        sut.snooze(option: .restOfDay)
        XCTAssertEqual(mockScheduler.cancelAllCallCount, 1)
    }

    func test_snoozeOptionRestOfDay_incrementsSnoozeCount() {
        sut.snooze(option: .restOfDay)
        XCTAssertEqual(settings.snoozeCount, 1)
    }

    // MARK: - cancelSnooze() clears snoozedUntil and resets snoozeCount

    func test_cancelSnooze_clearsSnoozedUntil() async {
        sut.snooze(option: .fiveMinutes)
        XCTAssertNotNil(settings.snoozedUntil)

        sut.cancelSnooze()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNil(settings.snoozedUntil)
    }

    func test_cancelSnooze_resetsSnoozeCountToZero() async {
        sut.snooze(option: .fiveMinutes)
        XCTAssertEqual(settings.snoozeCount, 1)

        sut.cancelSnooze()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(settings.snoozeCount, 0)
    }

    func test_cancelSnooze_schedulesReminders() async {
        sut.snooze(option: .fiveMinutes)

        sut.cancelSnooze()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 1)
    }

    // MARK: - canSnooze

    func test_canSnooze_trueWhenSnoozeCountIsZero() {
        settings.snoozeCount = 0
        XCTAssertTrue(sut.canSnooze)
    }

    func test_canSnooze_trueWhenSnoozeCountIsOne() {
        settings.snoozeCount = 1
        XCTAssertTrue(sut.canSnooze)
    }

    func test_canSnooze_falseAfterTwoConsecutiveSnoozes() {
        sut.snooze(option: .fiveMinutes)   // snoozeCount = 1
        sut.snooze(option: .fiveMinutes)   // snoozeCount = 2
        XCTAssertFalse(sut.canSnooze, "canSnooze must return false after \(SettingsViewModel.maxConsecutiveSnoozes) consecutive snoozes")
    }

    func test_canSnooze_falseWhenSnoozeCountEqualsMax() {
        settings.snoozeCount = SettingsViewModel.maxConsecutiveSnoozes
        XCTAssertFalse(sut.canSnooze)
    }

    func test_snooze_blockedWhenCanSnoozeFalse_doesNotChangeSnoozedUntil() {
        settings.snoozeCount = SettingsViewModel.maxConsecutiveSnoozes
        settings.snoozedUntil = nil

        sut.snooze(option: .fiveMinutes)

        XCTAssertNil(settings.snoozedUntil, "snooze() must be a no-op when canSnooze is false")
    }

    func test_snooze_blockedWhenCanSnoozeFalse_doesNotCallCancelAll() {
        settings.snoozeCount = SettingsViewModel.maxConsecutiveSnoozes

        sut.snooze(option: .fiveMinutes)

        XCTAssertEqual(mockScheduler.cancelAllCallCount, 0, "cancelAllReminders must not be called when snooze is blocked")
    }

    func test_canSnooze_trueAgainAfterCancelSnooze() async {
        sut.snooze(option: .fiveMinutes)   // snoozeCount = 1
        sut.snooze(option: .fiveMinutes)   // snoozeCount = 2
        XCTAssertFalse(sut.canSnooze)

        sut.cancelSnooze()                 // snoozeCount = 0

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(sut.canSnooze, "canSnooze must return true after cancelSnooze resets the count")
    }

    // MARK: - isSnoozeActive

    func test_isSnoozeActive_trueWhenSnoozedUntilIsFuture() {
        settings.snoozedUntil = Date().addingTimeInterval(300)
        XCTAssertTrue(sut.isSnoozeActive)
    }

    func test_isSnoozeActive_falseWhenSnoozedUntilIsNil() {
        settings.snoozedUntil = nil
        XCTAssertFalse(sut.isSnoozeActive)
    }

    func test_isSnoozeActive_falseWhenSnoozedUntilIsInThePast() {
        settings.snoozedUntil = Date().addingTimeInterval(-60)
        XCTAssertFalse(sut.isSnoozeActive, "Expired snoozedUntil must not be considered active")
    }

    func test_isSnoozeActive_trueAfterSnoozeApplied() {
        sut.snooze(option: .oneHour)
        XCTAssertTrue(sut.isSnoozeActive)
    }

    func test_isSnoozeActive_falseAfterCancelSnooze() async {
        sut.snooze(option: .fiveMinutes)
        XCTAssertTrue(sut.isSnoozeActive)

        sut.cancelSnooze()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(sut.isSnoozeActive)
    }

    // MARK: - Expired snooze auto-clears (isSnoozeActive false for past dates)

    func test_expiredSnooze_isSnoozeActiveReturnsFalse_withoutExplicitClear() {
        // Simulate a previously-set snooze that has since expired.
        // isSnoozeActive checks `until > Date()` so this must return false
        // even without calling cancelSnooze().
        settings.snoozedUntil = Date().addingTimeInterval(-1)
        XCTAssertFalse(
            sut.isSnoozeActive,
            "isSnoozeActive must return false for an expired snoozedUntil without needing an explicit cancelSnooze()"
        )
    }

    // MARK: - snoozeCount persists in UserDefaults

    func test_snoozeCount_persistsAfterSnoozeApplied() {
        sut.snooze(option: .fiveMinutes)
        XCTAssertEqual(settings.snoozeCount, 1)

        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertEqual(reloaded.snoozeCount, 1, "snoozeCount must survive a simulated app restart")
    }

    func test_snoozeCount_zeroPersistedAfterCancelSnooze() async {
        sut.snooze(option: .fiveMinutes)
        sut.cancelSnooze()

        try? await Task.sleep(nanoseconds: 200_000_000)

        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertEqual(reloaded.snoozeCount, 0, "snoozeCount of 0 must persist after cancelSnooze()")
    }

    // MARK: - Integration: Snooze survives settings-change reschedule

    func test_snooze_survivesReminderSettingChange() async {
        sut.snooze(option: .oneHour)
        let snoozeEnd = settings.snoozedUntil!

        // Changing a reminder setting calls rescheduleReminder, not cancelAllReminders.
        settings.eyesInterval = 600
        sut.reminderSettingChanged(for: .eyes)

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNotNil(settings.snoozedUntil, "snoozedUntil must not be cleared by a settings-change reschedule")
        XCTAssertEqual(
            settings.snoozedUntil!.timeIntervalSince1970,
            snoozeEnd.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func test_snooze_survivesMultipleSettingChanges() async {
        sut.snooze(option: .restOfDay)
        XCTAssertNotNil(settings.snoozedUntil)

        sut.reminderSettingChanged(for: .eyes)
        sut.reminderSettingChanged(for: .posture)
        sut.reminderSettingChanged(for: .eyes)

        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertNotNil(settings.snoozedUntil, "snoozedUntil must persist across multiple settings-change reschedules")
    }

    func test_masterToggle_doesNotClearSnoozedUntil() async {
        sut.snooze(option: .fiveMinutes)
        XCTAssertNotNil(settings.snoozedUntil)

        // Flipping master toggle off calls cancelAllReminders() on the scheduler
        // but must not touch snoozedUntil — snooze state is owned by snooze/cancelSnooze.
        settings.masterEnabled = false
        sut.masterToggleChanged()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNotNil(settings.snoozedUntil, "masterToggleChanged must not clear an active snooze")
    }

    // MARK: - Integration: snoozeCount resets after a reminder fires

    func test_snoozeCount_canBeResetToZeroExternally() {
        // Simulate two consecutive snoozes — at the max limit.
        sut.snooze(option: .fiveMinutes)
        sut.snooze(option: .fiveMinutes)
        XCTAssertFalse(sut.canSnooze)

        // AppCoordinator.handleNotification(for:) sets snoozeCount = 0 when a reminder fires.
        // Test that this mutation restores snooze availability.
        settings.snoozeCount = 0

        XCTAssertTrue(sut.canSnooze, "canSnooze must return true after snoozeCount is reset to 0 (reminder fired)")
    }

    func test_snoozeCount_resetPersistedAfterReminderFires() {
        // Simulate reminder firing: snoozeCount goes back to 0.
        settings.snoozeCount = SettingsViewModel.maxConsecutiveSnoozes
        settings.snoozeCount = 0

        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertEqual(reloaded.snoozeCount, 0, "Reset snoozeCount=0 must persist across app restart")
    }

    func test_snoozeAvailableAgain_afterSnoozeCountReset() {
        settings.snoozeCount = SettingsViewModel.maxConsecutiveSnoozes
        XCTAssertFalse(sut.canSnooze)

        settings.snoozeCount = 0

        // Now a new snooze(option:) call should succeed.
        sut.snooze(option: .oneHour)
        XCTAssertNotNil(settings.snoozedUntil, "A new snooze must be accepted once snoozeCount is reset to 0")
        XCTAssertEqual(settings.snoozeCount, 1)
    }
}
