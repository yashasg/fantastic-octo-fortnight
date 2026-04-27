@testable import EyePostureReminder
import XCTest

/// Additional coverage for `SettingsViewModel` — edge cases not yet covered
/// by the existing test files: SnoozeOption computed properties, preset option
/// arrays, pauseDuringFocus/pauseWhileDriving proxy properties, and canSnooze
/// boundary conditions.
@MainActor
final class SettingsViewModelExtendedTests: XCTestCase {

    var mockPersistence: MockSettingsPersisting!
    var settings: SettingsStore!
    var mockScheduler: MockReminderScheduler!

    override func setUp() async throws {
        try await super.setUp()
        mockPersistence = MockSettingsPersisting()
        settings = SettingsStore(store: mockPersistence)
        mockScheduler = MockReminderScheduler()
    }

    override func tearDown() async throws {
        mockScheduler = nil
        settings = nil
        mockPersistence = nil
        try await super.tearDown()
    }

    private func makeSUT(maxSnoozeCount: Int = 3) -> SettingsViewModel {
        SettingsViewModel(settings: settings, scheduler: mockScheduler, maxSnoozeCount: maxSnoozeCount)
    }

    // MARK: - SnoozeOption.allCases

    func test_snoozeOptions_countIsThree() {
        XCTAssertEqual(SettingsViewModel.SnoozeOption.allCases.count, 3)
    }

    func test_snoozeOptions_staticArray_matchesAllCases() {
        XCTAssertEqual(
            SettingsViewModel.snoozeOptions.count,
            SettingsViewModel.SnoozeOption.allCases.count)
    }

    // MARK: - SnoozeOption.minutes

    func test_snoozeOption_fiveMinutes_minutesIs5() {
        XCTAssertEqual(SettingsViewModel.SnoozeOption.fiveMinutes.minutes, 5)
    }

    func test_snoozeOption_oneHour_minutesIs60() {
        XCTAssertEqual(SettingsViewModel.SnoozeOption.oneHour.minutes, 60)
    }

    func test_snoozeOption_restOfDay_minutesIsNegativeOne() {
        XCTAssertEqual(SettingsViewModel.SnoozeOption.restOfDay.minutes, -1)
    }

    // MARK: - SnoozeOption.endDate

    func test_snoozeOption_fiveMinutes_endDateIsFuture() {
        let endDate = SettingsViewModel.SnoozeOption.fiveMinutes.endDate
        XCTAssertGreaterThan(endDate, Date())
    }

    func test_snoozeOption_oneHour_endDateIsFuture() {
        let endDate = SettingsViewModel.SnoozeOption.oneHour.endDate
        XCTAssertGreaterThan(endDate, Date())
    }

    func test_snoozeOption_restOfDay_endDateIsFuture() {
        let endDate = SettingsViewModel.SnoozeOption.restOfDay.endDate
        XCTAssertGreaterThan(endDate, Date())
    }

    func test_snoozeOption_fiveMinutes_endDateIsApproximately5MinFromNow() {
        let now = Date()
        let endDate = SettingsViewModel.SnoozeOption.fiveMinutes.endDate
        let delta = endDate.timeIntervalSince(now)
        XCTAssertGreaterThan(delta, 4 * 60)
        XCTAssertLessThan(delta, 6 * 60)
    }

    func test_snoozeOption_oneHour_endDateIsApproximately1HourFromNow() {
        let now = Date()
        let endDate = SettingsViewModel.SnoozeOption.oneHour.endDate
        let delta = endDate.timeIntervalSince(now)
        XCTAssertGreaterThan(delta, 59 * 60)
        XCTAssertLessThan(delta, 61 * 60)
    }

    func test_snoozeOption_restOfDay_endDateIsStartOfNextDay() {
        let endDate = SettingsViewModel.SnoozeOption.restOfDay.endDate
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: endDate)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    // MARK: - SnoozeOption.label

    func test_snoozeOption_fiveMinutes_labelIsNotEmpty() {
        XCTAssertFalse(SettingsViewModel.SnoozeOption.fiveMinutes.label.isEmpty)
    }

    func test_snoozeOption_oneHour_labelIsNotEmpty() {
        XCTAssertFalse(SettingsViewModel.SnoozeOption.oneHour.label.isEmpty)
    }

    func test_snoozeOption_restOfDay_labelIsNotEmpty() {
        XCTAssertFalse(SettingsViewModel.SnoozeOption.restOfDay.label.isEmpty)
    }

    // MARK: - Preset Options

    func test_intervalOptions_hasExpectedCount() {
        XCTAssertEqual(SettingsViewModel.intervalOptions.count, 5)
    }

    func test_intervalOptions_allPositive() {
        for interval in SettingsViewModel.intervalOptions {
            XCTAssertGreaterThan(interval, 0, "Interval option \(interval) must be > 0")
        }
    }

    func test_intervalOptions_areSortedAscending() {
        let options = SettingsViewModel.intervalOptions
        for i in 1..<options.count {
            XCTAssertGreaterThan(options[i], options[i - 1],
                "Interval options must be sorted ascending")
        }
    }

    func test_intervalOptions_containsExpectedValues() {
        let expected: [TimeInterval] = [600, 1200, 1800, 2700, 3600]
        XCTAssertEqual(SettingsViewModel.intervalOptions, expected)
    }

    func test_breakDurationOptions_hasExpectedCount() {
        XCTAssertEqual(SettingsViewModel.breakDurationOptions.count, 4)
    }

    func test_breakDurationOptions_allPositive() {
        for duration in SettingsViewModel.breakDurationOptions {
            XCTAssertGreaterThan(duration, 0, "Break duration \(duration) must be > 0")
        }
    }

    func test_breakDurationOptions_areSortedAscending() {
        let options = SettingsViewModel.breakDurationOptions
        for i in 1..<options.count {
            XCTAssertGreaterThan(options[i], options[i - 1],
                "Break duration options must be sorted ascending")
        }
    }

    func test_breakDurationOptions_containsExpectedValues() {
        let expected: [TimeInterval] = [10, 20, 30, 60]
        XCTAssertEqual(SettingsViewModel.breakDurationOptions, expected)
    }

    // MARK: - maxConsecutiveSnoozes

    func test_maxConsecutiveSnoozes_matchesInjectedValue() {
        let sut = makeSUT(maxSnoozeCount: 5)
        XCTAssertEqual(sut.maxConsecutiveSnoozes, 5)
    }

    func test_maxConsecutiveSnoozes_defaultUsesAppConfig() {
        let sut = SettingsViewModel(settings: settings, scheduler: mockScheduler)
        XCTAssertEqual(sut.maxConsecutiveSnoozes, AppConfig.load().features.maxSnoozeCount)
    }

    // MARK: - isSnoozeActive

    func test_isSnoozeActive_nilSnoozedUntil_isFalse() {
        settings.snoozedUntil = nil
        let sut = makeSUT()
        XCTAssertFalse(sut.isSnoozeActive)
    }

    func test_isSnoozeActive_futureSnoozedUntil_isTrue() {
        settings.snoozedUntil = Date().addingTimeInterval(3600)
        let sut = makeSUT()
        XCTAssertTrue(sut.isSnoozeActive)
    }

    func test_isSnoozeActive_pastSnoozedUntil_isFalse() {
        settings.snoozedUntil = Date().addingTimeInterval(-60)
        let sut = makeSUT()
        XCTAssertFalse(sut.isSnoozeActive)
    }

    // MARK: - canSnooze boundary

    func test_canSnooze_atZeroCount_isTrue() {
        settings.snoozeCount = 0
        let sut = makeSUT(maxSnoozeCount: 3)
        XCTAssertTrue(sut.canSnooze)
    }

    func test_canSnooze_atMaxMinusOne_isTrue() {
        settings.snoozeCount = 2
        let sut = makeSUT(maxSnoozeCount: 3)
        XCTAssertTrue(sut.canSnooze)
    }

    func test_canSnooze_atMax_isFalse() {
        settings.snoozeCount = 3
        let sut = makeSUT(maxSnoozeCount: 3)
        XCTAssertFalse(sut.canSnooze)
    }

    func test_canSnooze_aboveMax_isFalse() {
        settings.snoozeCount = 5
        let sut = makeSUT(maxSnoozeCount: 3)
        XCTAssertFalse(sut.canSnooze)
    }

    // MARK: - pauseDuringFocus proxy

    func test_pauseDuringFocus_getter_readsFromSettings() {
        settings.pauseDuringFocus = false
        let sut = makeSUT()
        XCTAssertFalse(sut.pauseDuringFocus)
    }

    func test_pauseDuringFocus_setter_writesToSettings() {
        let sut = makeSUT()
        sut.pauseDuringFocus = false
        XCTAssertFalse(settings.pauseDuringFocus)
    }

    // MARK: - pauseWhileDriving proxy

    func test_pauseWhileDriving_getter_readsFromSettings() {
        settings.pauseWhileDriving = false
        let sut = makeSUT()
        XCTAssertFalse(sut.pauseWhileDriving)
    }

    func test_pauseWhileDriving_setter_writesToSettings() {
        let sut = makeSUT()
        sut.pauseWhileDriving = false
        XCTAssertFalse(settings.pauseWhileDriving)
    }

    // MARK: - cancelSnooze

    func test_cancelSnooze_clearsSnoozedUntil() async {
        let sut = makeSUT()
        sut.snooze(option: .fiveMinutes)
        sut.cancelSnooze()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNil(settings.snoozedUntil)
    }

    func test_cancelSnooze_resetsSnoozeCount() async {
        let sut = makeSUT()
        sut.snooze(option: .fiveMinutes)
        sut.cancelSnooze()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(settings.snoozeCount, 0)
    }

    func test_cancelSnooze_callsScheduleReminders() async {
        let sut = makeSUT()
        sut.snooze(option: .fiveMinutes)
        let countBefore = mockScheduler.scheduleRemindersCallCount
        sut.cancelSnooze()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, countBefore + 1)
    }

    // MARK: - snooze at limit is rejected

    func test_snooze_atLimit_doesNotChangeSnoozedUntil() {
        let sut = makeSUT(maxSnoozeCount: 1)
        sut.snooze(option: .fiveMinutes)
        let firstUntil = settings.snoozedUntil

        sut.snooze(option: .oneHour)
        XCTAssertEqual(settings.snoozedUntil, firstUntil,
            "Snooze beyond limit must not change snoozedUntil")
    }

    // MARK: - reminderSettingChanged

    func test_reminderSettingChanged_callsReschedule() async {
        let sut = makeSUT()
        sut.reminderSettingChanged(for: .eyes)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 1)
    }

    func test_reminderSettingChanged_forPosture_callsReschedule() async {
        let sut = makeSUT()
        sut.reminderSettingChanged(for: .posture)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 1)
    }
}
