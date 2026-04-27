@testable import EyePostureReminder
import XCTest

/// Tests for `AppStorageKey` — centralised UserDefaults key constants.
///
/// Key correctness is critical: a typo in a key silently breaks onboarding
/// routing or overlay triggering. These tests act as a regression guard.
final class AppStorageKeysTests: XCTestCase {

    // MARK: - Key Values

    func test_hasSeenOnboarding_keyValue() {
        XCTAssertEqual(
            AppStorageKey.hasSeenOnboarding,
            "kshana.hasSeenOnboarding",
            "Key must match the documented value exactly")
    }

    func test_openSettingsOnLaunch_keyValue() {
        XCTAssertEqual(
            AppStorageKey.openSettingsOnLaunch,
            "kshana.openSettingsOnLaunch",
            "Key must match the documented value exactly")
    }

    func test_uiTestOverlayType_keyValue() {
        XCTAssertEqual(
            AppStorageKey.uiTestOverlayType,
            "kshana.ui-test.overlayType",
            "Key must match the documented value exactly")
    }

    // MARK: - Key Uniqueness

    func test_allKeys_areUnique() {
        let keys = [
            AppStorageKey.hasSeenOnboarding,
            AppStorageKey.openSettingsOnLaunch,
            AppStorageKey.uiTestOverlayType
        ]
        XCTAssertEqual(
            keys.count,
            Set(keys).count,
            "All AppStorageKey constants must be unique — duplicate keys cause silent data corruption")
    }

    // MARK: - Key Non-Empty

    func test_hasSeenOnboarding_isNotEmpty() {
        XCTAssertFalse(AppStorageKey.hasSeenOnboarding.isEmpty)
    }

    func test_openSettingsOnLaunch_isNotEmpty() {
        XCTAssertFalse(AppStorageKey.openSettingsOnLaunch.isEmpty)
    }

    func test_uiTestOverlayType_isNotEmpty() {
        XCTAssertFalse(AppStorageKey.uiTestOverlayType.isEmpty)
    }

    // MARK: - Key Prefix Convention

    func test_allKeys_followKshanaPrefix() {
        let keys = [
            AppStorageKey.hasSeenOnboarding,
            AppStorageKey.openSettingsOnLaunch,
            AppStorageKey.uiTestOverlayType
        ]
        for key in keys {
            XCTAssertTrue(
                key.hasPrefix("kshana."),
                "Key '\(key)' must follow the 'kshana.' prefix convention")
        }
    }
}
