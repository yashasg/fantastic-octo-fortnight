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
        XCTAssertEqual(ShieldSessionKeys.sessionData, ShieldSession.sessionDataKey)
        XCTAssertEqual(ShieldSessionKeys.breakReason, ShieldSession.reasonKey)
        XCTAssertEqual(ShieldSessionKeys.durationSeconds, ShieldSession.durationKey)
        XCTAssertEqual(ShieldSessionKeys.triggeredAt, ShieldSession.triggeredAtKey)
    }

    func test_trueInterruptEnabled_withSelection_roundTripsThroughDefaults() throws {
        XCTAssertFalse(store.isTrueInterruptEnabled())
        try store.writeSelection(AppGroupSelectionSnapshot(categoryCount: 0, appCount: 1, lastUpdated: Date()))

        XCTAssertTrue(store.setTrueInterruptEnabled(true))

        XCTAssertTrue(store.isTrueInterruptEnabled())
        XCTAssertTrue(defaults.bool(forKey: AppGroupIPCKeys.trueInterruptEnabled))
    }

    func test_trueInterruptEnabled_postsChangeNotificationWithEnabledValue() throws {
        var observedValues: [Bool] = []
        let observer = NotificationCenter.default.addObserver(
            forName: AppGroupIPCStore.trueInterruptEnabledDidChangeNotification,
            object: nil,
            queue: nil
        ) { notification in
            let key = AppGroupIPCStore.trueInterruptEnabledValueUserInfoKey
            if let value = notification.userInfo?[key] as? Bool {
                observedValues.append(value)
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        try store.writeSelection(AppGroupSelectionSnapshot(categoryCount: 0, appCount: 1, lastUpdated: Date()))

        XCTAssertTrue(store.setTrueInterruptEnabled(true))

        XCTAssertEqual(observedValues, [true])
    }

    func test_trueInterruptEnabled_doesNotPostChangeNotificationWhenValueUnchanged() {
        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: AppGroupIPCStore.trueInterruptEnabledDidChangeNotification,
            object: nil,
            queue: nil
        ) { _ in
            notificationCount += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        XCTAssertTrue(store.setTrueInterruptEnabled(false))

        XCTAssertEqual(notificationCount, 0)
    }

    func test_trueInterruptEnabled_emptySelection_refusesEnable() {
        XCTAssertFalse(store.setTrueInterruptEnabled(true))

        XCTAssertFalse(store.isTrueInterruptEnabled())
        XCTAssertFalse(defaults.bool(forKey: AppGroupIPCKeys.trueInterruptEnabled))
    }

    func test_trueInterruptEnabled_corruptSelection_refusesEnableAndWritesFalse() {
        defaults.set(Data("not-json".utf8), forKey: AppGroupIPCKeys.selectionMetadata)

        XCTAssertFalse(store.setTrueInterruptEnabled(true))

        XCTAssertFalse(store.isTrueInterruptEnabled())
        XCTAssertFalse(defaults.bool(forKey: AppGroupIPCKeys.trueInterruptEnabled))
    }

    func test_unavailableSuiteResolver_reportsDiagnosticAndDoesNotReturnStandardDefaults() throws {
        var diagnostics: [AppGroupDefaultsUnavailableDiagnostic] = []

        let resolved = AppGroupDefaults.resolve(
            consumer: "UnitTest",
            suiteFactory: { _ in nil },
            diagnosticHandler: { diagnostics.append($0) },
            assertOnFailure: false
        )

        XCTAssertNil(resolved)
        let diagnostic = try XCTUnwrap(diagnostics.first)
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(
            diagnostic,
            AppGroupDefaultsUnavailableDiagnostic(
                suiteName: AppGroupIPCKeys.appGroupID,
                consumer: "UnitTest"
            )
        )
        XCTAssertTrue(diagnostic.message.contains("extension-critical state was not written"))
    }

    func test_unavailableStoreDoesNotFallBackToStandardDefaults() throws {
        let store = AppGroupIPCStore(defaults: nil)
        let standardKeys = [
            AppGroupIPCKeys.trueInterruptEnabled,
            AppGroupIPCKeys.selectionMetadata,
            AppGroupIPCKeys.eventLog,
            AppGroupIPCKeys.lastShieldStartedAt,
            AppGroupIPCKeys.lastShieldEndedAt,
            ShieldSessionKeys.sessionData,
            ShieldSessionKeys.breakReason,
            ShieldSessionKeys.durationSeconds,
            ShieldSessionKeys.triggeredAt
        ]

        try preservingStandardDefaults(for: standardKeys) {
            XCTAssertFalse(store.isAvailable)
            XCTAssertFalse(store.setTrueInterruptEnabled(true))
            XCTAssertFalse(store.isTrueInterruptEnabled())
            XCTAssertThrowsError(try store.writeSelection(.empty)) { error in
                XCTAssertEqual(error as? AppGroupIPCStore.StoreError, .appGroupSuiteUnavailable)
            }
            XCTAssertFalse(
                store.writeShieldSession(
                    reasonRaw: "eyes",
                    durationSeconds: 20,
                    triggeredAt: Date(timeIntervalSince1970: 2_000)
                )
            )
            XCTAssertThrowsError(try store.readShieldSession()) { error in
                XCTAssertEqual(error as? AppGroupIPCStore.StoreError, .appGroupSuiteUnavailable)
            }
            XCTAssertFalse(store.clearShieldSession(endedAt: Date(timeIntervalSince1970: 2_100)))
            XCTAssertThrowsError(try store.recordEvent(AppGroupIPCEvent(kind: .watchdogHeartbeat))) { error in
                XCTAssertEqual(error as? AppGroupIPCStore.StoreError, .appGroupSuiteUnavailable)
            }
            XCTAssertFalse(store.clearEvents())
            for key in standardKeys {
                XCTAssertNil(UserDefaults.standard.object(forKey: key), "Unexpected standard-default write for \(key)")
            }
        }
    }

    func test_selectionSnapshot_roundTripsThroughSharedType() throws {
        let snapshot = AppGroupSelectionSnapshot(
            categoryCount: 2,
            appCount: 4,
            lastUpdated: Date(timeIntervalSince1970: 1_000)
        )

        try store.writeSelection(snapshot)

        XCTAssertEqual(try store.readSelection(), snapshot)
        let appMetadata: SelectedAppsMetadata = snapshot
        XCTAssertEqual(appMetadata, snapshot)
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

    func test_shieldSession_roundTripsAndStoresLastStartedTimestamp() throws {
        let triggeredAt = Date(timeIntervalSince1970: 2_000)
        defaults.set("stale", forKey: ShieldSessionKeys.breakReason)
        defaults.set(1, forKey: ShieldSessionKeys.durationSeconds)
        defaults.set(1, forKey: ShieldSessionKeys.triggeredAt)

        store.writeShieldSession(reasonRaw: "eyes", durationSeconds: 20, triggeredAt: triggeredAt)

        let data = try XCTUnwrap(defaults.data(forKey: ShieldSessionKeys.sessionData))
        let decoded = try ShieldSessionSnapshot.decode(from: data)
        XCTAssertEqual(decoded.reasonRaw, "eyes")
        XCTAssertEqual(decoded.durationSeconds, 20)
        XCTAssertEqual(decoded.triggeredAt, triggeredAt)
        XCTAssertNil(defaults.object(forKey: ShieldSessionKeys.breakReason))
        XCTAssertNil(defaults.object(forKey: ShieldSessionKeys.durationSeconds))
        XCTAssertNil(defaults.object(forKey: ShieldSessionKeys.triggeredAt))

        let snapshot = try store.readShieldSession()
        XCTAssertEqual(snapshot.reasonRaw, "eyes")
        XCTAssertEqual(snapshot.durationSeconds, 20)
        XCTAssertEqual(snapshot.triggeredAt, triggeredAt)
        XCTAssertEqual(
            defaults.double(forKey: AppGroupIPCKeys.lastShieldStartedAt),
            triggeredAt.timeIntervalSince1970
        )
    }

    func test_writeShieldSession_invalidDuration_returnsFalseAndDoesNotWrite() {
        let triggeredAt = Date(timeIntervalSince1970: 2_000)

        XCTAssertFalse(
            store.writeShieldSession(
                reasonRaw: ShieldTriggerReason.scheduledEyesBreak.rawValue,
                durationSeconds: 0,
                triggeredAt: triggeredAt
            )
        )

        XCTAssertNil(defaults.data(forKey: ShieldSessionKeys.sessionData))
        XCTAssertEqual(defaults.double(forKey: AppGroupIPCKeys.lastShieldStartedAt), 0)
    }

    func test_clearShieldSession_removesSessionAndStoresLastEndedTimestamp() {
        let endedAt = Date(timeIntervalSince1970: 2_100)
        store.writeShieldSession(
            reasonRaw: "posture",
            durationSeconds: 30,
            triggeredAt: Date(timeIntervalSince1970: 2_000)
        )

        store.clearShieldSession(endedAt: endedAt)

        XCTAssertNil(defaults.data(forKey: ShieldSessionKeys.sessionData))
        XCTAssertNil(defaults.string(forKey: ShieldSessionKeys.breakReason))
        XCTAssertEqual(defaults.double(forKey: ShieldSessionKeys.durationSeconds), 0)
        XCTAssertEqual(defaults.double(forKey: ShieldSessionKeys.triggeredAt), 0)
        XCTAssertEqual(defaults.double(forKey: AppGroupIPCKeys.lastShieldEndedAt), endedAt.timeIntervalSince1970)
    }

    func test_readShieldSession_corruptPayload_throws() {
        defaults.set(Data("not-json".utf8), forKey: ShieldSessionKeys.sessionData)

        XCTAssertThrowsError(try store.readShieldSession()) { error in
            XCTAssertEqual(error as? AppGroupIPCStore.StoreError, .corruptShieldSession)
        }
    }

    func test_readShieldSession_legacyKeysOnly_returnsPopulatedSnapshot() throws {
        let triggeredAt = Date(timeIntervalSince1970: 2_000)
        defaults.set("eyes", forKey: ShieldSessionKeys.breakReason)
        defaults.set(20, forKey: ShieldSessionKeys.durationSeconds)
        defaults.set(triggeredAt.timeIntervalSince1970, forKey: ShieldSessionKeys.triggeredAt)

        let snapshot = try store.readShieldSession()

        XCTAssertEqual(snapshot.reasonRaw, "eyes")
        XCTAssertEqual(snapshot.durationSeconds, 20)
        XCTAssertEqual(snapshot.triggeredAt, triggeredAt)
    }

    func test_readShieldSession_partialLegacyKeys_returnsEmptySnapshot() throws {
        defaults.set("eyes", forKey: ShieldSessionKeys.breakReason)
        defaults.set(20, forKey: ShieldSessionKeys.durationSeconds)

        let snapshot = try store.readShieldSession()

        XCTAssertEqual(snapshot, .empty)
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

    func test_readEvents_corruptLegacyLog_logsWarningAndContinues() {
        defaults.set(Data("not-json".utf8), forKey: AppGroupIPCKeys.eventLog)

        XCTAssertNoThrow(try store.readEvents())
        XCTAssertEqual(try store.readEvents(), [])
    }

    func test_readEvents_corruptLegacyLog_returnsValidSlotEvents() throws {
        // Corrupt legacy key
        defaults.set(Data("not-json".utf8), forKey: AppGroupIPCKeys.eventLog)

        // Valid per-slot event
        let slotEvent = AppGroupIPCEvent(
            kind: .watchdogHeartbeat,
            timestamp: Date(timeIntervalSince1970: 100),
            detail: WatchdogHeartbeatDetail.deviceActivityIntervalStarted.rawValue
        )
        try store.recordEvent(slotEvent)

        let events = try store.readEvents()
        XCTAssertEqual(events, [slotEvent])
    }

    func test_clearEvents_removesLog() throws {
        try store.recordEvent(AppGroupIPCEvent(kind: .watchdogHeartbeat))

        store.clearEvents()

        XCTAssertEqual(try store.readEvents(), [])
    }

    // MARK: - Cross-process safety

    /// Simulates two independent processes (two store instances sharing the same defaults)
    /// each recording an event. With per-slot keys, neither write can overwrite the other.
    func test_recordEvent_twoStoreInstances_bothEventsArePersisted() throws {
        let store1 = AppGroupIPCStore(defaults: defaults, maxEventCount: 10)
        let store2 = AppGroupIPCStore(defaults: defaults, maxEventCount: 10)

        let event1 = AppGroupIPCEvent(
            kind: .watchdogHeartbeat,
            timestamp: Date(timeIntervalSince1970: 100),
            detail: WatchdogHeartbeatDetail.appForeground.rawValue
        )
        let event2 = AppGroupIPCEvent(
            kind: .watchdogHeartbeat,
            timestamp: Date(timeIntervalSince1970: 101),
            detail: WatchdogHeartbeatDetail.deviceActivityIntervalStarted.rawValue
        )

        // Write from each "process" independently — no coordination needed.
        try store1.recordEvent(event1)
        try store2.recordEvent(event2)

        // Both events must survive regardless of write order.
        let events = try store.readEvents()
        XCTAssertTrue(events.contains(event1), "event1 (from store1) must not be overwritten by store2")
        XCTAssertTrue(events.contains(event2), "event2 (from store2) must not be overwritten by store1")
    }

    /// Legacy event array written before migration is still readable after upgrade.
    func test_readEvents_legacyArrayKey_isIncludedInResults() throws {
        let legacyEvent = AppGroupIPCEvent(
            kind: .shieldStarted,
            timestamp: Date(timeIntervalSince1970: 50),
            detail: nil
        )
        let legacyData = try JSONEncoder().encode([legacyEvent])
        defaults.set(legacyData, forKey: AppGroupIPCKeys.eventLog)

        let newEvent = AppGroupIPCEvent(
            kind: .watchdogHeartbeat,
            timestamp: Date(timeIntervalSince1970: 60),
            detail: nil
        )
        try store.recordEvent(newEvent)

        let events = try store.readEvents()
        XCTAssertTrue(events.contains(legacyEvent), "Legacy event from old eventLog key must be readable")
        XCTAssertTrue(events.contains(newEvent), "New slot-key event must be readable alongside legacy events")
    }

    private func preservingStandardDefaults(for keys: [String], _ action: () throws -> Void) rethrows {
        let oldValues = Dictionary(uniqueKeysWithValues: keys.map { ($0, UserDefaults.standard.object(forKey: $0)) })
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        defer {
            for (key, oldValue) in oldValues {
                if let oldValue {
                    UserDefaults.standard.set(oldValue, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
        try action()
    }
}
