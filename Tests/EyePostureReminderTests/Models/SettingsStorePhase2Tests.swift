@testable import EyePostureReminder
import XCTest

/// Phase 2 unit tests for `SettingsStore` covering haptics and snooze-count persistence.
@MainActor
final class SettingsStorePhase2Tests: XCTestCase {

    var mockPersistence: MockSettingsPersisting!
    var sut: SettingsStore!

    override func setUp() {
        super.setUp()
        mockPersistence = MockSettingsPersisting()
        sut = SettingsStore(store: mockPersistence)
    }

    override func tearDown() {
        sut = nil
        mockPersistence = nil
        super.tearDown()
    }

    // MARK: - Haptics: Defaults

    func test_hapticsEnabled_defaultIsTrue() {
        let fresh = SettingsStore(store: MockSettingsPersisting())
        XCTAssertTrue(fresh.hapticsEnabled, "hapticsEnabled must default to true (Phase 2 feature)")
    }

    // MARK: - Haptics: Persistence

    func test_hapticsEnabled_persistsFalse() {
        sut.hapticsEnabled = false
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertFalse(reloaded.hapticsEnabled)
    }

    func test_hapticsEnabled_persistsTrue_afterToggle() {
        sut.hapticsEnabled = false
        sut.hapticsEnabled = true
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertTrue(reloaded.hapticsEnabled)
    }

    func test_toggleHapticsEnabled_savesToPersistence() {
        sut.hapticsEnabled = false
        XCTAssertTrue(
            mockPersistence.hasValue(forKey: "epr.hapticsEnabled"),
            "Setting hapticsEnabled must write to the persistence store immediately"
        )
    }

    func test_hapticsEnabled_independentOfOtherSettings() {
        sut.hapticsEnabled = false
        XCTAssertTrue(sut.globalEnabled, "Changing hapticsEnabled must not affect globalEnabled")
        XCTAssertFalse(sut.pauseMediaDuringBreaks, "Changing hapticsEnabled must not affect pauseMediaDuringBreaks")
    }

    // MARK: - SnoozeCount: Defaults and Persistence

    func test_snoozeCount_defaultIsZero() {
        let fresh = SettingsStore(store: MockSettingsPersisting())
        XCTAssertEqual(fresh.snoozeCount, 0)
    }

    func test_snoozeCount_persistsNonZeroValue() {
        sut.snoozeCount = 2
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertEqual(reloaded.snoozeCount, 2)
    }

    func test_snoozeCount_resetPersistsZero() {
        sut.snoozeCount = 2
        sut.snoozeCount = 0
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertEqual(reloaded.snoozeCount, 0)
    }

    func test_snoozeCount_writesToPersistence() {
        sut.snoozeCount = 1
        XCTAssertTrue(
            mockPersistence.hasValue(forKey: "epr.snoozeCount"),
            "Setting snoozeCount must write to the persistence store immediately"
        )
    }

    func test_snoozeCount_independentOfSnoozedUntil() {
        sut.snoozeCount = 1
        XCTAssertNil(sut.snoozedUntil, "Setting snoozeCount must not affect snoozedUntil")
    }

    // MARK: - Onboarding
    // Note: hasSeenOnboarding is not yet implemented in Phase 2 source.
    // Tests will be added in a future phase once AppCoordinator / SettingsStore
    // gains the `hasSeenOnboarding` property.
}
