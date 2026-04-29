@testable import EyePostureReminder
@testable import ScreenTimeExtensionShared
import XCTest

@MainActor
final class AppGroupIPCStoreTests: XCTestCase {
    private let suiteName = "AppGroupIPCStoreTests"
    private var defaults: UserDefaults!
    private var store: AppGroupIPCStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        store = AppGroupIPCStore(defaults: defaults, maxEventCount: 3)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        super.tearDown()
    }

    func test_keys_alignWithMainAppSelectionStateAndShieldSession() {
        XCTAssertEqual(AppGroupIPCKeys.appGroupID, SelectedAppsState.appGroupSuiteName)
        XCTAssertEqual(AppGroupIPCKeys.selectionMetadata, SelectedAppsState.metadataKey)
        XCTAssertEqual(AppGroupIPCKeys.trueInterruptEnabled, SelectedAppsState.enabledKey)
        XCTAssertEqual(ShieldSessionKeys.breakReason, ShieldSession.reasonKey)
        XCTAssertEqual(ShieldSessionKeys.durationSeconds, ShieldSession.durationKey)
        XCTAssertEqual(ShieldSessionKeys.triggeredAt, ShieldSession.triggeredAtKey)
    }

    func test_trueInterruptEnabled_roundTripsThroughDefaults() {
        XCTAssertFalse(store.isTrueInterruptEnabled())

        store.setTrueInterruptEnabled(true)

        XCTAssertTrue(store.isTrueInterruptEnabled())
        XCTAssertTrue(defaults.bool(forKey: AppGroupIPCKeys.trueInterruptEnabled))
    }

    func test_selectionSnapshot_roundTripsAndMatchesSelectedAppsMetadataShape() throws {
        let snapshot = AppGroupSelectionSnapshot(
            categoryCount: 2,
            appCount: 4,
            lastUpdated: Date(timeIntervalSince1970: 1_000)
        )

        try store.writeSelection(snapshot)

        XCTAssertEqual(try store.readSelection(), snapshot)
        let data = try XCTUnwrap(defaults.data(forKey: AppGroupIPCKeys.selectionMetadata))
        let decodedByMainApp = try JSONDecoder().decode(SelectedAppsMetadata.self, from: data)
        XCTAssertEqual(decodedByMainApp.categoryCount, snapshot.categoryCount)
        XCTAssertEqual(decodedByMainApp.appCount, snapshot.appCount)
        XCTAssertEqual(decodedByMainApp.lastUpdated, snapshot.lastUpdated)
    }

    func test_readSelection_missingValue_returnsEmptySnapshot() throws {
        XCTAssertEqual(try store.readSelection(), .empty)
    }

    func test_readSelection_corruptValue_throws() {
        defaults.set(Data("not-json".utf8), forKey: AppGroupIPCKeys.selectionMetadata)

        XCTAssertThrowsError(try store.readSelection()) { error in
            XCTAssertTrue(error is AppGroupIPCStore.StoreError)
        }
    }

    func test_shieldSession_roundTripsAndStoresLastStartedTimestamp() {
        let triggeredAt = Date(timeIntervalSince1970: 2_000)

        store.writeShieldSession(reasonRaw: "eyes", durationSeconds: 20, triggeredAt: triggeredAt)

        let snapshot = store.readShieldSession()
        XCTAssertEqual(snapshot.reasonRaw, "eyes")
        XCTAssertEqual(snapshot.durationSeconds, 20)
        XCTAssertEqual(snapshot.triggeredAt, triggeredAt)
        XCTAssertEqual(
            defaults.double(forKey: AppGroupIPCKeys.lastShieldStartedAt),
            triggeredAt.timeIntervalSince1970
        )
    }

    func test_clearShieldSession_removesSessionAndStoresLastEndedTimestamp() {
        let endedAt = Date(timeIntervalSince1970: 2_100)
        store.writeShieldSession(
            reasonRaw: "posture",
            durationSeconds: 30,
            triggeredAt: Date(timeIntervalSince1970: 2_000)
        )

        store.clearShieldSession(endedAt: endedAt)

        XCTAssertNil(defaults.string(forKey: ShieldSessionKeys.breakReason))
        XCTAssertEqual(defaults.double(forKey: ShieldSessionKeys.durationSeconds), 0)
        XCTAssertEqual(defaults.double(forKey: ShieldSessionKeys.triggeredAt), 0)
        XCTAssertEqual(defaults.double(forKey: AppGroupIPCKeys.lastShieldEndedAt), endedAt.timeIntervalSince1970)
    }

    func test_recordEvent_appendsAndCapsLog() throws {
        let first = AppGroupIPCEvent(kind: .watchdogHeartbeat, timestamp: Date(timeIntervalSince1970: 1), detail: "1")
        let second = AppGroupIPCEvent(kind: .shieldStarted, timestamp: Date(timeIntervalSince1970: 2), detail: "2")
        let third = AppGroupIPCEvent(kind: .shieldEnded, timestamp: Date(timeIntervalSince1970: 3), detail: "3")
        let fourth = AppGroupIPCEvent(kind: .watchdogHeartbeat, timestamp: Date(timeIntervalSince1970: 4), detail: "4")

        try store.recordEvent(first)
        try store.recordEvent(second)
        try store.recordEvent(third)
        try store.recordEvent(fourth)

        XCTAssertEqual(try store.readEvents(), [second, third, fourth])
    }

    func test_recordAccessRequested_setsLastAccessRequestTimestamp() throws {
        let requestedAt = Date(timeIntervalSince1970: 3_000)
        let event = AppGroupIPCEvent(
            kind: .accessRequested,
            reasonRaw: "eyes",
            timestamp: requestedAt,
            detail: "User requested access during shield"
        )

        try store.recordEvent(event)

        XCTAssertEqual(try store.readEvents(), [event])
        XCTAssertEqual(defaults.double(forKey: AppGroupIPCKeys.lastAccessRequestAt), requestedAt.timeIntervalSince1970)
    }

    func test_readEvents_corruptLog_throws() {
        defaults.set(Data("not-json".utf8), forKey: AppGroupIPCKeys.eventLog)

        XCTAssertThrowsError(try store.readEvents()) { error in
            XCTAssertTrue(error is AppGroupIPCStore.StoreError)
        }
    }

    func test_clearEvents_removesLog() throws {
        try store.recordEvent(AppGroupIPCEvent(kind: .watchdogHeartbeat))

        store.clearEvents()

        XCTAssertEqual(try store.readEvents(), [])
    }
}
