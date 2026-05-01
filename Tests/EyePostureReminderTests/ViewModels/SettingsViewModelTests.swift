import Combine
@testable import EyePostureReminder
import XCTest

/// Tests for `SettingsViewModel`.
///
/// All methods are `@MainActor` because `SettingsViewModel` is isolated to the
/// main actor. Async methods that internally spawn `Task {}` are awaited with
/// `awaitCondition` (deterministic polling) rather than fixed-duration sleeps.
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

    // MARK: - globalToggleChanged: enabled

    func test_globalToggleChanged_whenEnabled_callsScheduleReminders() async {
        settings.globalEnabled = true

        sut.globalToggleChanged()

        await awaitCondition { mockScheduler.scheduleRemindersCallCount >= 1 }
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 1)
    }

    func test_globalToggleChanged_whenEnabled_passesCorrectSettings() async {
        settings.globalEnabled = true

        sut.globalToggleChanged()

        await awaitCondition { mockScheduler.lastScheduledSettings != nil }
        XCTAssertTrue(
            mockScheduler.lastScheduledSettings === settings,
            "scheduleReminders must be called with the same SettingsStore instance")
    }

    func test_globalToggleChanged_whenEnabled_doesNotCallCancelAll() async {
        settings.globalEnabled = true

        sut.globalToggleChanged()

        // Wait for the enabled path (scheduleReminders) to complete, then verify cancelAll was not called.
        await awaitCondition { mockScheduler.scheduleRemindersCallCount >= 1 }
        XCTAssertEqual(mockScheduler.cancelAllCallCount, 0)
    }

    // MARK: - globalToggleChanged: disabled

    func test_globalToggleChanged_whenDisabled_callsCancelAll() async {
        settings.globalEnabled = false

        sut.globalToggleChanged()

        await awaitCondition { mockScheduler.cancelAllCallCount >= 1 }
        XCTAssertEqual(mockScheduler.cancelAllCallCount, 1)
    }

    func test_globalToggleChanged_whenDisabled_doesNotCallScheduleReminders() async {
        settings.globalEnabled = false

        sut.globalToggleChanged()

        // cancelAllReminders is synchronous; wait for it then verify no schedule path ran.
        await awaitCondition { mockScheduler.cancelAllCallCount >= 1 }
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 0)
    }

    // MARK: - reminderSettingChanged

    func test_reminderSettingChanged_forEyes_callsReschedule() async {
        sut.reminderSettingChanged(for: .eyes)

        await awaitCondition { mockScheduler.rescheduleCallCount >= 1 }
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 1)
    }

    func test_reminderSettingChanged_forEyes_passesCorrectType() async {
        sut.reminderSettingChanged(for: .eyes)

        await awaitCondition { mockScheduler.rescheduleCallCount >= 1 }
        XCTAssertEqual(mockScheduler.lastRescheduledType, .eyes)
    }

    func test_reminderSettingChanged_forPosture_callsReschedule() async {
        sut.reminderSettingChanged(for: .posture)

        await awaitCondition { mockScheduler.rescheduleCallCount >= 1 }
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 1)
    }

    func test_reminderSettingChanged_forPosture_passesCorrectType() async {
        sut.reminderSettingChanged(for: .posture)

        await awaitCondition { mockScheduler.rescheduleCallCount >= 1 }
        XCTAssertEqual(mockScheduler.lastRescheduledType, .posture)
    }

    func test_reminderSettingChanged_passesCorrectSettings() async {
        sut.reminderSettingChanged(for: .eyes)

        await awaitCondition { mockScheduler.lastScheduledSettings != nil }
        XCTAssertTrue(mockScheduler.lastScheduledSettings === settings)
    }

    func test_reminderSettingChanged_calledTwice_reschedulesTwice() async {
        sut.reminderSettingChanged(for: .eyes)
        sut.reminderSettingChanged(for: .posture)

        await awaitCondition { mockScheduler.rescheduleCallCount >= 2 }
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 2)
    }

    // MARK: - Toggle enable/disable affects scheduler

    func test_disablingGlobalToggle_triggersCancel_notSchedule() async {
        settings.globalEnabled = true
        sut.globalToggleChanged()
        await awaitCondition { mockScheduler.scheduleRemindersCallCount >= 1 }
        mockScheduler.reset()

        settings.globalEnabled = false
        sut.globalToggleChanged()
        await awaitCondition { mockScheduler.cancelAllCallCount >= 1 }

        XCTAssertEqual(mockScheduler.cancelAllCallCount, 1)
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 0)
    }

    func test_enablingGlobalToggle_triggersSchedule_notCancel() async {
        settings.globalEnabled = false
        sut.globalToggleChanged()
        await awaitCondition { mockScheduler.cancelAllCallCount >= 1 }
        mockScheduler.reset()

        settings.globalEnabled = true
        sut.globalToggleChanged()
        await awaitCondition { mockScheduler.scheduleRemindersCallCount >= 1 }

        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 1)
        XCTAssertEqual(mockScheduler.cancelAllCallCount, 0)
    }

    // MARK: - snooze

    func test_snooze_5min_cancelAllReminders() {
        sut.snooze(option: .fiveMinutes)
        XCTAssertEqual(mockScheduler.cancelAllCallCount, 1)
    }

    func test_snooze_1hour_cancelAllReminders() {
        sut.snooze(option: .oneHour)
        XCTAssertEqual(mockScheduler.cancelAllCallCount, 1)
    }

    func test_snooze_setsSnoozedUntilInFuture() throws {
        sut.snooze(option: .fiveMinutes)
        let snoozedUntil = try XCTUnwrap(settings.snoozedUntil)
        XCTAssertGreaterThan(snoozedUntil, Date())
    }

    func test_snooze_5min_setsCorrectDuration() throws {
        let before = Date()
        sut.snooze(option: .fiveMinutes)
        let after = Date()

        let expectedMin = before.addingTimeInterval(5 * 60)
        let expectedMax = after.addingTimeInterval(5 * 60)

        let snoozedUntil = try XCTUnwrap(settings.snoozedUntil)
        XCTAssertGreaterThanOrEqual(
            snoozedUntil.timeIntervalSince1970,
            expectedMin.timeIntervalSince1970 - 1)
        XCTAssertLessThanOrEqual(
            snoozedUntil.timeIntervalSince1970,
            expectedMax.timeIntervalSince1970 + 1)
    }

    func test_snooze_60min_setsCorrectDuration() throws {
        let before = Date()
        sut.snooze(option: .oneHour)

        let snoozedUntil = try XCTUnwrap(settings.snoozedUntil)
        XCTAssertEqual(
            snoozedUntil.timeIntervalSince1970,
            before.addingTimeInterval(60 * 60).timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func test_snooze_doesNotCallSchedule() {
        sut.snooze(option: .fiveMinutes)
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 0)
    }

    // MARK: - cancelSnooze

    func test_cancelSnooze_clearsSnoozedUntil() async {
        settings.snoozedUntil = Date().addingTimeInterval(300)

        sut.cancelSnooze()

        // snoozedUntil is cleared synchronously; await task completion as positive confirmation.
        await awaitCondition { mockScheduler.scheduleRemindersCallCount >= 1 }
        XCTAssertNil(settings.snoozedUntil)
    }

    func test_cancelSnooze_schedulesReminders() async {
        settings.snoozedUntil = Date().addingTimeInterval(300)

        sut.cancelSnooze()

        await awaitCondition { mockScheduler.scheduleRemindersCallCount >= 1 }
        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 1)
    }

    func test_cancelSnooze_passesCorrectSettings() async {
        settings.snoozedUntil = Date().addingTimeInterval(300)

        sut.cancelSnooze()

        await awaitCondition { mockScheduler.lastScheduledSettings != nil }
        XCTAssertTrue(mockScheduler.lastScheduledSettings === settings)
    }

    func test_cancelSnooze_whenNoSnoozeActive_stillSchedules() async {
        XCTAssertNil(settings.snoozedUntil)

        sut.cancelSnooze()

        await awaitCondition { mockScheduler.scheduleRemindersCallCount >= 1 }
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

        await awaitCondition { mockScheduler.rescheduleCallCount >= 4 }
        XCTAssertEqual(
            mockScheduler.rescheduleCallCount,
            4,
            "Every setting change must trigger a reschedule, even when called rapidly")
    }

    // MARK: - pauseDuringFocus / pauseWhileDriving setter pass-through

    func test_pauseDuringFocus_setter_passesValueToSettings() {
        sut.pauseDuringFocus = true
        XCTAssertTrue(settings.pauseDuringFocus, "Setting pauseDuringFocus via VM must persist to SettingsStore")
    }

    func test_pauseDuringFocus_setter_canBeClearedAgain() {
        settings.pauseDuringFocus = true
        sut.pauseDuringFocus = false
        XCTAssertFalse(settings.pauseDuringFocus, "Clearing pauseDuringFocus via VM must persist to SettingsStore")
    }

    func test_pauseWhileDriving_setter_passesValueToSettings() {
        sut.pauseWhileDriving = true
        XCTAssertTrue(settings.pauseWhileDriving, "Setting pauseWhileDriving via VM must persist to SettingsStore")
    }

    func test_pauseWhileDriving_setter_canBeClearedAgain() {
        settings.pauseWhileDriving = true
        sut.pauseWhileDriving = false
        XCTAssertFalse(settings.pauseWhileDriving, "Clearing pauseWhileDriving via VM must persist to SettingsStore")
    }

    // MARK: - Notification fallback

    func test_notificationFallbackEnabled_getter_readsSettings() {
        settings.notificationFallbackEnabled = false
        XCTAssertFalse(sut.notificationFallbackEnabled)
    }

    func test_notificationFallbackEnabled_setter_persistsValue() async {
        sut.notificationFallbackEnabled = false

        // State is persisted synchronously; await task completion as positive signal.
        await awaitCondition { mockScheduler.scheduleRemindersCallCount >= 1 }
        XCTAssertFalse(settings.notificationFallbackEnabled)
    }

    func test_notificationFallbackEnabled_setter_schedulesReminders() async {
        sut.notificationFallbackEnabled = false

        await awaitCondition { mockScheduler.scheduleRemindersCallCount >= 1 }

        XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 1)
        XCTAssertTrue(mockScheduler.lastScheduledSettings === settings)
    }

    // MARK: - hapticsEnabled

    func test_hapticsEnabled_getter_readsFromSettings() {
        settings.hapticsEnabled = false
        XCTAssertFalse(sut.hapticsEnabled)
    }

    func test_hapticsEnabled_setter_passesValueToSettings() {
        settings.hapticsEnabled = true
        sut.hapticsEnabled = false
        XCTAssertFalse(settings.hapticsEnabled, "hapticsEnabled false must persist to SettingsStore")
    }

    func test_hapticsEnabled_setter_canBeSetTrue() {
        settings.hapticsEnabled = false
        sut.hapticsEnabled = true
        XCTAssertTrue(settings.hapticsEnabled, "hapticsEnabled true must persist to SettingsStore")
    }

    func test_hapticsEnabled_setter_emitsSettingChangedEvent() {
        var captured: [AnalyticsEvent] = []
        AnalyticsLogger.testEventHandler = { captured.append($0) }
        defer { AnalyticsLogger.testEventHandler = nil }

        let initial = settings.hapticsEnabled
        sut.hapticsEnabled = !initial

        let match = captured.first {
            if case let .settingChanged(setting, _, _) = $0 { return setting == .hapticsEnabled }
            return false
        }
        XCTAssertNotNil(
            match,
            "Toggling hapticsEnabled via SettingsViewModel must emit settingChanged(setting: \"hapticsEnabled\")"
        )
    }

    func test_hapticsEnabled_setter_emitsCorrectOldAndNewValues() {
        var captured: [AnalyticsEvent] = []
        AnalyticsLogger.testEventHandler = { captured.append($0) }
        defer { AnalyticsLogger.testEventHandler = nil }

        settings.hapticsEnabled = false
        sut.hapticsEnabled = true

        if case let .settingChanged(_, oldValue, newValue) = captured.first {
            XCTAssertEqual(oldValue, "false")
            XCTAssertEqual(newValue, "true")
        } else {
            XCTFail("Expected settingChanged event with old=false new=true")
        }
    }

    func test_notifySettingChanged_emitsEvent() {
        var captured: [AnalyticsEvent] = []
        AnalyticsLogger.testEventHandler = { captured.append($0) }
        defer { AnalyticsLogger.testEventHandler = nil }

        sut.notifySettingChanged(.eyesInterval, old: "1200", new: "900")

        XCTAssertEqual(captured.count, 1)
        if case let .settingChanged(setting, old, new) = captured[0] {
            XCTAssertEqual(setting, .eyesInterval)
            XCTAssertEqual(old, "1200")
            XCTAssertEqual(new, "900")
        } else {
            XCTFail("Expected settingChanged event")
        }
    }

    func test_notifySettingChanged_sameOldAndNew_doesNotEmit() {
        var captured: [AnalyticsEvent] = []
        AnalyticsLogger.testEventHandler = { captured.append($0) }
        defer { AnalyticsLogger.testEventHandler = nil }

        sut.notifySettingChanged(.globalEnabled, old: "true", new: "true")

        XCTAssertTrue(captured.isEmpty, "No event should be emitted when old == new")
    }
}
