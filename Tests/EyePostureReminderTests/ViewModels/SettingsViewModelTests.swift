import XCTest
import Combine
@testable import EyePostureReminder

/// Tests for `SettingsViewModel`.
///
/// All methods are `@MainActor` because `SettingsViewModel` is isolated to the
/// main actor. Async methods that internally spawn `Task {}` are given a short
/// sleep to allow those tasks to complete before assertions.
@MainActor
final class SettingsViewModelTests: XCTestCase {

    var mockPersistence: MockSettingsPersisting!
    var settings: SettingsStore!
    var mockScheduler: MockReminderScheduler!
    var sut: SettingsViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        mockPersistence = MockSettingsPersisting()
        settings = SettingsStore(store: mockPersistence)
        mockScheduler = MockReminderScheduler()
        sut = SettingsViewModel(settings: settings, scheduler: mockScheduler)
        cancellables = []
    }

    override func tearDown() async throws {
        cancellables = nil
        sut = nil
        mockScheduler = nil
        settings = nil
        mockPersistence = nil
        try await super.tearDown()
    }

    // MARK: - masterToggleChanged: enabled

    func test_masterToggleChanged_whenEnabled_callsScheduleReminders() async {
        settings.masterEnabled = true

        sut.masterToggleChanged()

        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms for inner Task
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 1)
    }

    func test_masterToggleChanged_whenEnabled_passesCorrectSettings() async {
        settings.masterEnabled = true

        sut.masterToggleChanged()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(mockScheduler.lastScheduledSettings === settings,
            "scheduleReminders must be called with the same SettingsStore instance")
    }

    func test_masterToggleChanged_whenEnabled_doesNotCallCancelAll() async {
        settings.masterEnabled = true

        sut.masterToggleChanged()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockScheduler.cancelAllCallCount, 0)
    }

    // MARK: - masterToggleChanged: disabled

    func test_masterToggleChanged_whenDisabled_callsCancelAll() async {
        settings.masterEnabled = false

        sut.masterToggleChanged()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockScheduler.cancelAllCallCount, 1)
    }

    func test_masterToggleChanged_whenDisabled_doesNotCallScheduleReminders() async {
        settings.masterEnabled = false

        sut.masterToggleChanged()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 0)
    }

    // MARK: - reminderSettingChanged

    func test_reminderSettingChanged_forEyes_callsReschedule() async {
        sut.reminderSettingChanged(for: .eyes)

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 1)
    }

    func test_reminderSettingChanged_forEyes_passesCorrectType() async {
        sut.reminderSettingChanged(for: .eyes)

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockScheduler.lastRescheduledType, .eyes)
    }

    func test_reminderSettingChanged_forPosture_callsReschedule() async {
        sut.reminderSettingChanged(for: .posture)

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 1)
    }

    func test_reminderSettingChanged_forPosture_passesCorrectType() async {
        sut.reminderSettingChanged(for: .posture)

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockScheduler.lastRescheduledType, .posture)
    }

    func test_reminderSettingChanged_passesCorrectSettings() async {
        sut.reminderSettingChanged(for: .eyes)

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(mockScheduler.lastScheduledSettings === settings)
    }

    func test_reminderSettingChanged_calledTwice_reschedulesTwice() async {
        sut.reminderSettingChanged(for: .eyes)
        sut.reminderSettingChanged(for: .posture)

        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 2)
    }

    // MARK: - Toggle enable/disable affects scheduler

    func test_disablingMasterToggle_triggersCancel_notSchedule() async {
        settings.masterEnabled = true
        sut.masterToggleChanged()
        try? await Task.sleep(nanoseconds: 200_000_000)
        mockScheduler.reset()

        settings.masterEnabled = false
        sut.masterToggleChanged()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(mockScheduler.cancelAllCallCount, 1)
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 0)
    }

    func test_enablingMasterToggle_triggersSchedule_notCancel() async {
        settings.masterEnabled = false
        sut.masterToggleChanged()
        try? await Task.sleep(nanoseconds: 200_000_000)
        mockScheduler.reset()

        settings.masterEnabled = true
        sut.masterToggleChanged()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 1)
        XCTAssertEqual(mockScheduler.cancelAllCallCount, 0)
    }

    // MARK: - snooze

    func test_snooze_5min_cancelAllReminders() {
        sut.snooze(for: 5)
        XCTAssertEqual(mockScheduler.cancelAllCallCount, 1)
    }

    func test_snooze_1hour_cancelAllReminders() {
        sut.snooze(for: 60)
        XCTAssertEqual(mockScheduler.cancelAllCallCount, 1)
    }

    func test_snooze_setsSnoozedUntilInFuture() {
        sut.snooze(for: 5)
        XCTAssertNotNil(settings.snoozedUntil)
        XCTAssertGreaterThan(settings.snoozedUntil!, Date())
    }

    func test_snooze_5min_setsCorrectDuration() {
        let before = Date()
        sut.snooze(for: 5)
        let after = Date()

        let expectedMin = before.addingTimeInterval(5 * 60)
        let expectedMax = after.addingTimeInterval(5 * 60)

        XCTAssertGreaterThanOrEqual(settings.snoozedUntil!.timeIntervalSince1970,
                                    expectedMin.timeIntervalSince1970 - 1)
        XCTAssertLessThanOrEqual(settings.snoozedUntil!.timeIntervalSince1970,
                                  expectedMax.timeIntervalSince1970 + 1)
    }

    func test_snooze_60min_setsCorrectDuration() {
        let before = Date()
        sut.snooze(for: 60)

        XCTAssertEqual(
            settings.snoozedUntil!.timeIntervalSince1970,
            before.addingTimeInterval(60 * 60).timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func test_snooze_doesNotCallSchedule() {
        sut.snooze(for: 5)
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 0)
    }

    // MARK: - cancelSnooze

    func test_cancelSnooze_clearsSnoozedUntil() async {
        settings.snoozedUntil = Date().addingTimeInterval(300)

        sut.cancelSnooze()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNil(settings.snoozedUntil)
    }

    func test_cancelSnooze_schedulesReminders() async {
        settings.snoozedUntil = Date().addingTimeInterval(300)

        sut.cancelSnooze()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 1)
    }

    func test_cancelSnooze_passesCorrectSettings() async {
        settings.snoozedUntil = Date().addingTimeInterval(300)

        sut.cancelSnooze()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(mockScheduler.lastScheduledSettings === settings)
    }

    func test_cancelSnooze_whenNoSnoozeActive_stillSchedules() async {
        XCTAssertNil(settings.snoozedUntil)

        sut.cancelSnooze()

        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 1)
    }

    // MARK: - Settings store reference

    func test_viewModel_exposesCorrectSettingsStore() {
        XCTAssertTrue(sut.settings === settings)
    }

    // MARK: - Edge Case: rapid setting changes

    func test_rapidSettingChanges_allReschedulesAreTriggered() async {
        sut.reminderSettingChanged(for: .eyes)
        sut.reminderSettingChanged(for: .posture)
        sut.reminderSettingChanged(for: .eyes)
        sut.reminderSettingChanged(for: .posture)

        try? await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 4,
            "Every setting change must trigger a reschedule, even when called rapidly")
    }
}
