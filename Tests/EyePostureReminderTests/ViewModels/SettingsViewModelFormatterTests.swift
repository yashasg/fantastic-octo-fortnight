@testable import EyePostureReminder
import XCTest

/// Tests for `SettingsViewModel` static formatting helpers.
/// These are pure functions with branching logic used for user-visible picker labels.
@MainActor
final class SettingsViewModelFormatterTests: XCTestCase {

    // MARK: - labelForInterval

    func test_labelForInterval_600s_returns10Min() {
        XCTAssertEqual(SettingsViewModel.labelForInterval(600), "10 min")
    }

    func test_labelForInterval_1200s_returns20Min() {
        XCTAssertEqual(SettingsViewModel.labelForInterval(1200), "20 min")
    }

    func test_labelForInterval_3600s_returns60Min() {
        XCTAssertEqual(SettingsViewModel.labelForInterval(3600), "60 min")
    }

    // MARK: - labelForBreakDuration

    func test_labelForBreakDuration_20s_returns20Sec() {
        XCTAssertEqual(SettingsViewModel.labelForBreakDuration(20), "20 sec")
    }

    func test_labelForBreakDuration_59s_returns59Sec() {
        XCTAssertEqual(SettingsViewModel.labelForBreakDuration(59), "59 sec")
    }

    func test_labelForBreakDuration_60s_returns1Min() {
        XCTAssertEqual(SettingsViewModel.labelForBreakDuration(60), "1 min")
    }

    func test_labelForBreakDuration_65s_returns1Min() {
        XCTAssertEqual(SettingsViewModel.labelForBreakDuration(65), "1 min")
    }

    func test_labelForBreakDuration_120s_returns2Min() {
        XCTAssertEqual(SettingsViewModel.labelForBreakDuration(120), "2 min")
    }
}
