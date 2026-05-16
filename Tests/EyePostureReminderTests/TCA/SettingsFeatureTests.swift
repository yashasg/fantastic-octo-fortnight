import ComposableArchitecture
import XCTest

@testable import EyePostureReminder

/// `TestStore` baseline coverage for `SettingsFeature` (Phase 1 reducer
/// `p0-tca-6` / #669). Behavioural parity with `SettingsViewModel` lives
/// under Phase 3 issue `p0-tca-16` (#679).
@MainActor
final class SettingsFeatureTests: XCTestCase {

    // MARK: - Default state

    func test_state_init_documentedDefaults() {
        let state = SettingsFeature.State()

        XCTAssertEqual(state.eyesInterval, 0)
        XCTAssertEqual(state.eyesBreakDuration, 0)
        XCTAssertEqual(state.prevEyesInterval, .zero)
        XCTAssertEqual(state.prevEyesBreakDuration, .zero)
        XCTAssertEqual(state.prevPostureInterval, .zero)
        XCTAssertEqual(state.prevPostureBreakDuration, .zero)
        XCTAssertFalse(state.showResetConfirm)
        XCTAssertFalse(state.showSavedBanner)
    }

    func test_state_settings_isComputedFromBindableMirrors() {
        var state = SettingsFeature.State()
        state.eyesInterval = 600
        state.eyesBreakDuration = 30

        XCTAssertEqual(state.settings.interval, 600)
        XCTAssertEqual(state.settings.breakDuration, 30)
    }

    // MARK: - SnoozeOption

    func test_snoozeOption_analyticsCodes_areStable() {
        XCTAssertEqual(SettingsFeature.SnoozeOption.fiveMinutes.analyticsCode, "5m")
        XCTAssertEqual(SettingsFeature.SnoozeOption.oneHour.analyticsCode, "1h")
        XCTAssertEqual(SettingsFeature.SnoozeOption.restOfDay.analyticsCode, "rest_of_day")
    }

    func test_snoozeOption_endDate_fiveMinutes_addsFiveMinutes() {
        let reference = Date(timeIntervalSince1970: 1_000_000)
        let result = SettingsFeature.SnoozeOption.fiveMinutes.endDate(
            referenceDate: reference, calendar: .init(identifier: .gregorian)
        )

        XCTAssertEqual(result.timeIntervalSince(reference), 5 * 60, accuracy: 0.001)
    }

    func test_snoozeOption_endDate_oneHour_addsOneHour() {
        let reference = Date(timeIntervalSince1970: 1_000_000)
        let result = SettingsFeature.SnoozeOption.oneHour.endDate(
            referenceDate: reference, calendar: .init(identifier: .gregorian)
        )

        XCTAssertEqual(result.timeIntervalSince(reference), 60 * 60, accuracy: 0.001)
    }

    func test_snoozeOption_endDate_restOfDay_returnsNextMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        calendar.timeZone = utc
        // 2026-01-01 12:00:00 UTC.
        let reference = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone, year: 2026, month: 1, day: 1, hour: 12
        )))
        let expected = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone, year: 2026, month: 1, day: 2, hour: 0
        )))

        let result = SettingsFeature.SnoozeOption.restOfDay.endDate(
            referenceDate: reference, calendar: calendar
        )

        XCTAssertEqual(result, expected,
                       "restOfDay must produce the next-day midnight in the supplied calendar")
    }

    // MARK: - .onAppear

    func test_onAppear_seedsBindablesAndPrevValuesFromSnapshot() async {
        let snapshot = ReminderSettings(interval: 1200, breakDuration: 25)
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = SettingsClient(
                snapshot: { snapshot },
                stream: { .finished },
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
                setSnoozedUntil: { _ in },
                setSnoozeCount: { _ in },
                resetToDefaults: {}
            )
            $0.notificationClient.authorizationStatus = { .authorized }
            $0.screenTimeAuthorizationClient.status = { .approved }
            $0.screenTimeAuthorizationClient.statusChanges = { .finished }
        }

        await store.send(.onAppear) {
            $0.eyesInterval = 1200
            $0.eyesBreakDuration = 25
            $0.prevEyesInterval = 1200
            $0.prevEyesBreakDuration = 25
        }
        await store.receive(\.notificationAuthStatusChanged) {
            $0.notificationAuthStatus = .authorized
        }
        await store.receive(\.screenTimeAuthStatusChanged) {
            $0.screenTimeAuthStatus = .approved
        }
    }

    // MARK: - .settingsChanged

    func test_settingsChanged_writesAllFourMirroredFields() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        let snapshot = ReminderSettings(interval: 900, breakDuration: 15)

        await store.send(.settingsChanged(snapshot)) {
            $0.eyesInterval = 900
            $0.eyesBreakDuration = 15
            $0.prevEyesInterval = 900
            $0.prevEyesBreakDuration = 15
        }
    }

    // MARK: - .savedBannerExpired

    func test_savedBannerExpired_clearsBannerFlag() async {
        var initial = SettingsFeature.State()
        initial.showSavedBanner = true
        let store = TestStore(initialState: initial) {
            SettingsFeature()
        }

        await store.send(.savedBannerExpired) {
            $0.showSavedBanner = false
        }
    }

    // MARK: - .resetConfirmed

    func test_resetConfirmed_dropsConfirmFlagAndCallsClient() async {
        var initial = SettingsFeature.State()
        initial.showResetConfirm = true
        let resetCalls = LockIsolated(0)

        let store = TestStore(initialState: initial) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = SettingsClient(
                snapshot: { ReminderSettings(interval: 0, breakDuration: 0) },
                stream: { .finished },
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
                setSnoozedUntil: { _ in },
                setSnoozeCount: { _ in },
                resetToDefaults: { resetCalls.withValue { $0 += 1 } }
            )
        }

        await store.send(.resetConfirmed) {
            $0.showResetConfirm = false
        }
        await store.finish()

        resetCalls.withValue { count in
            XCTAssertEqual(count, 1,
                           "resetConfirmed must dispatch exactly one resetToDefaults call")
        }
    }

    // MARK: - .snoozeTapped

    func test_snoozeTapped_setsSavedBannerImmediately() async {
        let clock = TestClock()
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = TCATestDependencies.silentSettingsClient()
            $0.analyticsClient = AnalyticsClient(log: { _ in })
            $0.continuousClock = clock
            $0.date = .constant(Date(timeIntervalSince1970: 1_000_000))
            $0.calendar = Calendar(identifier: .gregorian)
        }

        await store.send(.snoozeTapped(.fiveMinutes)) {
            $0.showSavedBanner = true
        }

        // Drive the savedBannerExpired effect.
        await clock.advance(by: .seconds(4))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }
    }
}
