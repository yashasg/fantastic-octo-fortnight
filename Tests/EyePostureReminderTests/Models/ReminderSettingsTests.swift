@testable import EyePostureReminder
import XCTest

/// Tests for `ReminderSettings` — the immutable value type carrying schedule parameters.
final class ReminderSettingsTests: XCTestCase {

    // MARK: - Initialisation

    func test_init_retainsInterval() {
        let sut = ReminderSettings(interval: 1200, breakDuration: 20)
        XCTAssertEqual(sut.interval, 1200)
    }

    func test_init_retainsBreakDuration() {
        let sut = ReminderSettings(interval: 1200, breakDuration: 20)
        XCTAssertEqual(sut.breakDuration, 20)
    }

    func test_init_zeroInterval_isAllowed() {
        let sut = ReminderSettings(interval: 0, breakDuration: 10)
        XCTAssertEqual(sut.interval, 0)
    }

    func test_init_zeroBreakDuration_isAllowed() {
        let sut = ReminderSettings(interval: 600, breakDuration: 0)
        XCTAssertEqual(sut.breakDuration, 0)
    }

    func test_init_largeValues_areRetained() {
        let sut = ReminderSettings(interval: 86400, breakDuration: 3600)
        XCTAssertEqual(sut.interval, 86400)
        XCTAssertEqual(sut.breakDuration, 3600)
    }

    // MARK: - Equatable

    func test_equatable_sameValues_areEqual() {
        let first = ReminderSettings(interval: 1200, breakDuration: 20)
        let second = ReminderSettings(interval: 1200, breakDuration: 20)
        XCTAssertEqual(first, second)
    }

    func test_equatable_differentInterval_areNotEqual() {
        let first = ReminderSettings(interval: 1200, breakDuration: 20)
        let second = ReminderSettings(interval: 600, breakDuration: 20)
        XCTAssertNotEqual(first, second)
    }

    func test_equatable_differentBreakDuration_areNotEqual() {
        let first = ReminderSettings(interval: 1200, breakDuration: 20)
        let second = ReminderSettings(interval: 1200, breakDuration: 30)
        XCTAssertNotEqual(first, second)
    }

    func test_equatable_bothDifferent_areNotEqual() {
        let first = ReminderSettings(interval: 1200, breakDuration: 20)
        let second = ReminderSettings(interval: 600, breakDuration: 30)
        XCTAssertNotEqual(first, second)
    }

    // MARK: - Static Defaults

    func test_defaultEyes_intervalIsPositive() {
        XCTAssertGreaterThan(
            ReminderSettings.defaultEyes.interval, 0,
            "Default eye interval must be > 0")
    }

    func test_defaultEyes_breakDurationIsPositive() {
        XCTAssertGreaterThan(
            ReminderSettings.defaultEyes.breakDuration, 0,
            "Default eye break duration must be > 0")
    }

    func test_defaultPosture_intervalIsPositive() {
        XCTAssertGreaterThan(
            ReminderSettings.defaultPosture.interval, 0,
            "Default posture interval must be > 0")
    }

    func test_defaultPosture_breakDurationIsPositive() {
        XCTAssertGreaterThan(
            ReminderSettings.defaultPosture.breakDuration, 0,
            "Default posture break duration must be > 0")
    }

    func test_defaultEyes_intervalMatchesAppConfig() {
        let config = AppConfig.load()
        XCTAssertEqual(
            ReminderSettings.defaultEyes.interval,
            config.defaults.eyeInterval,
            "Default eyes interval must match AppConfig")
    }

    func test_defaultEyes_breakDurationMatchesAppConfig() {
        let config = AppConfig.load()
        XCTAssertEqual(
            ReminderSettings.defaultEyes.breakDuration,
            config.defaults.eyeBreakDuration,
            "Default eyes break duration must match AppConfig")
    }

    func test_defaultPosture_intervalMatchesAppConfig() {
        let config = AppConfig.load()
        XCTAssertEqual(
            ReminderSettings.defaultPosture.interval,
            config.defaults.postureInterval,
            "Default posture interval must match AppConfig")
    }

    func test_defaultPosture_breakDurationMatchesAppConfig() {
        let config = AppConfig.load()
        XCTAssertEqual(
            ReminderSettings.defaultPosture.breakDuration,
            config.defaults.postureBreakDuration,
            "Default posture break duration must match AppConfig")
    }

    // MARK: - Sensible defaults: interval > breakDuration

    func test_defaultEyes_intervalGreaterThanBreakDuration() {
        XCTAssertGreaterThan(
            ReminderSettings.defaultEyes.interval,
            ReminderSettings.defaultEyes.breakDuration,
            "Eye interval must be longer than break duration")
    }

    func test_defaultPosture_intervalGreaterThanBreakDuration() {
        XCTAssertGreaterThan(
            ReminderSettings.defaultPosture.interval,
            ReminderSettings.defaultPosture.breakDuration,
            "Posture interval must be longer than break duration")
    }
}
