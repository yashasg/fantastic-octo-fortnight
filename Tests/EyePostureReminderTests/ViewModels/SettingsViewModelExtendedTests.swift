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

    private func makeSUT(maxSnoozeCount: Int = 2) -> SettingsViewModel {
        SettingsViewModel(settings: settings, scheduler: mockScheduler, maxSnoozeCount: maxSnoozeCount)
    }

    private func makeSUT(maxSnoozeCount: Int = 2, dateProvider: DateProviding) -> SettingsViewModel {
        SettingsViewModel(
            settings: settings,
            scheduler: mockScheduler,
            maxSnoozeCount: maxSnoozeCount,
            dateProvider: dateProvider
        )
    }

    private func makeSUT(
        maxSnoozeCount: Int = 2,
        dateProvider: DateProviding? = nil,
        makeDateProvider: @escaping SettingsViewModel.DateProviderFactory
    ) -> SettingsViewModel {
        SettingsViewModel(
            settings: settings,
            scheduler: mockScheduler,
            maxSnoozeCount: maxSnoozeCount,
            dateProvider: dateProvider,
            makeDateProvider: makeDateProvider
        )
    }

    private func makeSUT(
        maxSnoozeCount: Int? = nil,
        makeMaxSnoozeCount: @escaping SettingsViewModel.MaxSnoozeCountFactory
    ) -> SettingsViewModel {
        SettingsViewModel(
            settings: settings,
            scheduler: mockScheduler,
            maxSnoozeCount: maxSnoozeCount,
            makeMaxSnoozeCount: makeMaxSnoozeCount
        )
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
        XCTAssertEqual(SettingsViewModel.intervalOptions.count, 6)
    }

    func test_intervalOptions_allPositive() {
        for interval in SettingsViewModel.intervalOptions {
            XCTAssertGreaterThan(interval, 0, "Interval option \(interval) must be > 0")
        }
    }

    func test_intervalOptions_areSortedAscending() {
        let options = SettingsViewModel.intervalOptions
        for index in 1..<options.count {
            XCTAssertGreaterThan(options[index], options[index - 1],
                "Interval options must be sorted ascending")
        }
    }

    func test_intervalOptions_containsExpectedValues() {
        let expected: [TimeInterval] = [60, 600, 1200, 1800, 2700, 3600]
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
        for index in 1..<options.count {
            XCTAssertGreaterThan(options[index], options[index - 1],
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

    func test_maxConsecutiveSnoozes_withoutExplicitValue_usesFactory() {
        var factoryCallCount = 0
        let sut = makeSUT(
            maxSnoozeCount: nil,
            makeMaxSnoozeCount: {
                factoryCallCount += 1
                return 7
            }
        )

        XCTAssertEqual(factoryCallCount, 1, "Factory must run when explicit maxSnoozeCount is absent")
        XCTAssertEqual(sut.maxConsecutiveSnoozes, 7)
    }

    func test_maxConsecutiveSnoozes_withExplicitValue_bypassesFactory() {
        var factoryCallCount = 0
        let sut = makeSUT(
            maxSnoozeCount: 5,
            makeMaxSnoozeCount: {
                factoryCallCount += 1
                return 9
            }
        )

        XCTAssertEqual(factoryCallCount, 0, "Factory must not run when explicit maxSnoozeCount is provided")
        XCTAssertEqual(sut.maxConsecutiveSnoozes, 5)
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
        await awaitCondition { mockScheduler.scheduleRemindersCallCount >= 1 }
        XCTAssertNil(settings.snoozedUntil)
    }

    func test_cancelSnooze_resetsSnoozeCount() async {
        let sut = makeSUT()
        sut.snooze(option: .fiveMinutes)
        sut.cancelSnooze()
        await awaitCondition { mockScheduler.scheduleRemindersCallCount >= 1 }
        XCTAssertEqual(settings.snoozeCount, 0)
    }

    func test_cancelSnooze_callsScheduleReminders() async {
        let sut = makeSUT()
        sut.snooze(option: .fiveMinutes)
        let countBefore = mockScheduler.scheduleRemindersCallCount
        sut.cancelSnooze()
        await awaitCondition { mockScheduler.scheduleRemindersCallCount > countBefore }
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
        await awaitCondition { mockScheduler.rescheduleCallCount >= 1 }
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 1)
    }

    func test_reminderSettingChanged_forPosture_callsReschedule() async {
        let sut = makeSUT()
        sut.reminderSettingChanged(for: .posture)
        await awaitCondition { mockScheduler.rescheduleCallCount >= 1 }
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 1)
    }

    // MARK: - Lifecycle / weak-self guard (Issue #441)
    //
    // Verifies that the `guard let self else { return }` inside each Task closure
    // exits early without touching the scheduler when the ViewModel is deallocated
    // before the Task body runs. The test exploits @MainActor cooperative scheduling:
    // the Task body cannot execute until we yield, so we nil out the SUT first.

    func test_globalToggleChanged_afterDealloc_doesNotCallScheduler() async {
        var localSUT: SettingsViewModel? = makeSUT()
        settings.globalEnabled = true

        localSUT?.globalToggleChanged()
        // Deallocate before yielding; weak self inside Task becomes nil.
        localSUT = nil

        await Task.yield()

        XCTAssertEqual(
            mockScheduler.scheduleRemindersCallCount, 0,
            "Scheduler must not be called when ViewModel is deallocated before Task body executes"
        )
    }

    func test_reminderSettingChanged_afterDealloc_doesNotCallReschedule() async {
        var localSUT: SettingsViewModel? = makeSUT()

        localSUT?.reminderSettingChanged(for: .eyes)
        localSUT = nil

        await Task.yield()

        XCTAssertEqual(
            mockScheduler.rescheduleCallCount, 0,
            "Reschedule must not be called when ViewModel is deallocated before Task body executes"
        )
    }

    func test_cancelSnooze_afterDealloc_doesNotCallScheduler() async {
        var localSUT: SettingsViewModel? = makeSUT()
        localSUT?.snooze(option: .fiveMinutes)
        mockScheduler.reset()   // clear the snooze-path cancelAll call

        localSUT?.cancelSnooze()
        localSUT = nil

        await Task.yield()

        XCTAssertEqual(
            mockScheduler.scheduleRemindersCallCount, 0,
            "scheduleReminders must not be called when ViewModel is deallocated before Task body executes"
        )
    }

    func test_notificationFallbackEnabled_setter_afterDealloc_doesNotCallScheduler() async {
        var localSUT: SettingsViewModel? = makeSUT()
        settings.notificationFallbackEnabled = false

        localSUT?.notificationFallbackEnabled = true
        localSUT = nil

        await Task.yield()

        XCTAssertEqual(
            mockScheduler.scheduleRemindersCallCount, 0,
            "scheduleReminders must not be called when ViewModel is deallocated before Task body executes"
        )
    }

    // MARK: - DateProviding seam (deterministic snooze tests)

    @available(*, deprecated, message: "Tests legacy snooze(for:) date-provider seam")
    func test_init_withoutDateProvider_usesFactoryDateProviderForSnoozeComputation() throws {
        let fixedNow = Date(timeIntervalSince1970: 2_000_000)
        let fallbackProvider = MockDateProvider(now: fixedNow)
        var factoryCallCount = 0
        let sut = makeSUT(
            dateProvider: nil,
            makeDateProvider: {
                factoryCallCount += 1
                return fallbackProvider
            }
        )

        sut.snooze(for: 5)

        XCTAssertEqual(factoryCallCount, 1, "Factory must be used when explicit dateProvider is absent")
        let snoozedUntil = try XCTUnwrap(settings.snoozedUntil)
        XCTAssertEqual(
            snoozedUntil.timeIntervalSince1970,
            fixedNow.addingTimeInterval(5 * 60).timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    @available(*, deprecated, message: "Tests legacy snooze(for:) date-provider seam")
    func test_init_withExplicitDateProvider_bypassesFactory() throws {
        let explicitNow = Date(timeIntervalSince1970: 3_000_000)
        let explicitProvider = MockDateProvider(now: explicitNow)
        var factoryCallCount = 0
        let sut = makeSUT(
            dateProvider: explicitProvider,
            makeDateProvider: {
                factoryCallCount += 1
                return MockDateProvider(now: .distantPast)
            }
        )

        sut.snooze(for: 5)

        XCTAssertEqual(factoryCallCount, 0, "Factory must not run when explicit dateProvider is provided")
        let snoozedUntil = try XCTUnwrap(settings.snoozedUntil)
        XCTAssertEqual(
            snoozedUntil.timeIntervalSince1970,
            explicitNow.addingTimeInterval(5 * 60).timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func test_isSnoozeActive_withMockedNow_exactlyAtExpiry_returnsFalse() {
        let fixedNow = Date(timeIntervalSince1970: 1_000_000)
        let dateProvider = MockDateProvider(now: fixedNow)
        let sut = makeSUT(dateProvider: dateProvider)
        // snoozedUntil == now → not active (snooze has expired)
        settings.snoozedUntil = fixedNow
        XCTAssertFalse(sut.isSnoozeActive,
            "A snoozedUntil equal to the current time must not be considered active")
    }

    func test_isSnoozeActive_withMockedNow_oneSecondBeforeExpiry_returnsTrue() {
        let fixedNow = Date(timeIntervalSince1970: 1_000_000)
        let dateProvider = MockDateProvider(now: fixedNow)
        let sut = makeSUT(dateProvider: dateProvider)
        // snoozedUntil is 1 second in the future relative to mocked now
        settings.snoozedUntil = fixedNow.addingTimeInterval(1)
        XCTAssertTrue(sut.isSnoozeActive,
            "A snoozedUntil one second in the future must be considered active")
    }

    func test_isSnoozeActive_withMockedNow_oneSecondPastExpiry_returnsFalse() {
        let fixedNow = Date(timeIntervalSince1970: 1_000_000)
        let dateProvider = MockDateProvider(now: fixedNow)
        let sut = makeSUT(dateProvider: dateProvider)
        settings.snoozedUntil = fixedNow.addingTimeInterval(-1)
        XCTAssertFalse(sut.isSnoozeActive,
            "A snoozedUntil one second in the past must not be considered active")
    }

    @available(*, deprecated, message: "Tests legacy snooze(for:) date-provider seam")
    func test_snoozeForLegacy_persistsNowPlusDuration_usingMockedDate() throws {
        let fixedNow = Date(timeIntervalSince1970: 1_000_000)
        let dateProvider = MockDateProvider(now: fixedNow)
        let sut = makeSUT(dateProvider: dateProvider)
        sut.snooze(for: 5)
        let snoozedUntil = try XCTUnwrap(settings.snoozedUntil)
        let expected = fixedNow.addingTimeInterval(5 * 60)
        XCTAssertEqual(
            snoozedUntil.timeIntervalSince1970,
            expected.timeIntervalSince1970,
            accuracy: 0.001,
            "snooze(for:5) must persist exactly now + 5 min using the injected date provider"
        )
    }

    func test_snoozeOptionOneHour_persistsNowPlusDuration_usingMockedDate() throws {
        let fixedNow = Date(timeIntervalSince1970: 1_000_000)
        let dateProvider = MockDateProvider(now: fixedNow)
        let sut = makeSUT(dateProvider: dateProvider)

        sut.snooze(option: .oneHour)

        let snoozedUntil = try XCTUnwrap(settings.snoozedUntil)
        let expected = fixedNow.addingTimeInterval(60 * 60)
        XCTAssertEqual(
            snoozedUntil.timeIntervalSince1970,
            expected.timeIntervalSince1970,
            accuracy: 0.001,
            "snooze(option:.oneHour) must use injected date provider now"
        )
    }

    func test_snoozeOptionRestOfDay_usesInjectedReferenceDateForMidnightCutoff() throws {
        let fixedNow = Date(timeIntervalSince1970: 1_000_000)
        let dateProvider = MockDateProvider(now: fixedNow)
        let sut = makeSUT(dateProvider: dateProvider)

        sut.snooze(option: .restOfDay)

        let calendar = Calendar.current
        let expected = try XCTUnwrap(
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: fixedNow))
        )
        let snoozedUntil = try XCTUnwrap(settings.snoozedUntil)
        XCTAssertEqual(
            snoozedUntil.timeIntervalSince1970,
            expected.timeIntervalSince1970,
            accuracy: 0.001,
            "restOfDay must compute midnight from the injected current date"
        )
    }
}
