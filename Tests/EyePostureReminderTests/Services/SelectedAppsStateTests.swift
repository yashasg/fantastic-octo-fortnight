@testable import EyePostureReminder
import XCTest

/// Unit tests for `SelectedAppsState` and `SelectedAppsMetadata` added in #204.
///
/// All tests use an isolated `UserDefaults` suite so they never touch the real
/// App Group (`group.com.yashasgujjar.kshana`), which requires a provisioned
/// device + entitlement profile. This makes the tests runnable in any SPM host.
@MainActor
final class SelectedAppsStateTests: XCTestCase {

    // MARK: - Test infrastructure

    private let suiteName = "com.yashasg.kshana.test.selectedAppsState"
    private var testDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        testDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        super.tearDown()
    }

    private func makeSUT() -> SelectedAppsState {
        SelectedAppsState(defaults: testDefaults)
    }

    // MARK: - SelectedAppsMetadata

    func test_metadata_empty_sentinel_isCorrect() {
        let empty = SelectedAppsMetadata.empty
        XCTAssertEqual(empty.categoryCount, 0)
        XCTAssertEqual(empty.appCount, 0)
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty.lastUpdated, .distantPast)
    }

    func test_metadata_isEmpty_falseWhenAppsSelected() {
        let metadata = SelectedAppsMetadata(categoryCount: 0, appCount: 2, lastUpdated: Date())
        XCTAssertFalse(metadata.isEmpty)
    }

    func test_metadata_isEmpty_falseWhenCategoriesSelected() {
        let metadata = SelectedAppsMetadata(categoryCount: 1, appCount: 0, lastUpdated: Date())
        XCTAssertFalse(metadata.isEmpty)
    }

    func test_metadata_equality() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let first = SelectedAppsMetadata(categoryCount: 2, appCount: 5, lastUpdated: now)
        let second = SelectedAppsMetadata(categoryCount: 2, appCount: 5, lastUpdated: now)
        XCTAssertEqual(first, second)
    }

    func test_metadata_codable_roundTrip() throws {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let original = SelectedAppsMetadata(categoryCount: 3, appCount: 7, lastUpdated: now)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SelectedAppsMetadata.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Persistence constants

    func test_appGroupSuiteName_isStable() {
        XCTAssertEqual(
            SelectedAppsState.appGroupSuiteName,
            "group.com.yashasgujjar.kshana",
            "App Group suite name must match the provisioned App Group — changing it breaks extension communication"
        )
    }

    func test_metadataKey_isStable() {
        XCTAssertEqual(SelectedAppsState.metadataKey, "trueInterrupt.selectionMetadata")
    }

    func test_enabledKey_isStable() {
        XCTAssertEqual(SelectedAppsState.enabledKey, "trueInterrupt.enabled")
    }

    // MARK: - Initial state (fresh defaults)

    func test_init_defaultMetadata_isEmpty() {
        let sut = makeSUT()
        XCTAssertTrue(sut.selectionMetadata.isEmpty)
        XCTAssertEqual(sut.selectionMetadata, .empty)
    }

    func test_init_defaultEnabled_isFalse() {
        let sut = makeSUT()
        XCTAssertFalse(sut.isTrueInterruptEnabled)
    }

    // MARK: - setEnabled

    func test_setEnabled_true_persistsToDefaults() {
        let sut = makeSUT()
        sut.setEnabled(true)
        XCTAssertTrue(sut.isTrueInterruptEnabled)
        XCTAssertTrue(testDefaults.bool(forKey: SelectedAppsState.enabledKey))
    }

    func test_setEnabled_false_persistsToDefaults() {
        let sut = makeSUT()
        sut.setEnabled(true)
        sut.setEnabled(false)
        XCTAssertFalse(sut.isTrueInterruptEnabled)
        XCTAssertFalse(testDefaults.bool(forKey: SelectedAppsState.enabledKey))
    }

    // MARK: - updateMetadata

    func test_updateMetadata_persistsAndUpdatesPublished() throws {
        let sut = makeSUT()
        let now = Date(timeIntervalSince1970: 3_000_000)
        let metadata = SelectedAppsMetadata(categoryCount: 2, appCount: 4, lastUpdated: now)
        sut.updateMetadata(metadata)

        XCTAssertEqual(sut.selectionMetadata, metadata)

        // Verify round-trip via defaults
        let data = try XCTUnwrap(testDefaults.data(forKey: SelectedAppsState.metadataKey))
        let decoded = try JSONDecoder().decode(SelectedAppsMetadata.self, from: data)
        XCTAssertEqual(decoded, metadata)
    }

    // MARK: - clearSelection

    func test_clearSelection_resetsMetadataAndEnabled() {
        let sut = makeSUT()
        sut.setEnabled(true)
        sut.updateMetadata(
            SelectedAppsMetadata(categoryCount: 1, appCount: 3, lastUpdated: Date())
        )

        sut.clearSelection()

        XCTAssertTrue(sut.selectionMetadata.isEmpty)
        XCTAssertFalse(sut.isTrueInterruptEnabled)
        XCTAssertFalse(testDefaults.bool(forKey: SelectedAppsState.enabledKey))
    }

    // MARK: - Persistence across reinit

    func test_reinit_loadsPersistedEnabled() {
        let sut1 = makeSUT()
        sut1.setEnabled(true)

        let sut2 = SelectedAppsState(defaults: testDefaults)
        XCTAssertTrue(sut2.isTrueInterruptEnabled)
    }

    func test_reinit_loadsPersistedMetadata() {
        let sut1 = makeSUT()
        let now = Date(timeIntervalSince1970: 4_000_000)
        let metadata = SelectedAppsMetadata(categoryCount: 5, appCount: 2, lastUpdated: now)
        sut1.updateMetadata(metadata)

        let sut2 = SelectedAppsState(defaults: testDefaults)
        XCTAssertEqual(sut2.selectionMetadata, metadata)
    }

    func test_reinit_afterClear_returnsEmptyState() {
        let sut1 = makeSUT()
        sut1.setEnabled(true)
        sut1.updateMetadata(
            SelectedAppsMetadata(categoryCount: 1, appCount: 1, lastUpdated: Date())
        )
        sut1.clearSelection()

        let sut2 = SelectedAppsState(defaults: testDefaults)
        XCTAssertTrue(sut2.selectionMetadata.isEmpty)
        XCTAssertFalse(sut2.isTrueInterruptEnabled)
    }
}
