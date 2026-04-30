import Foundation
import os

public enum AppGroupIPCKeys {
    public static let appGroupID = ShieldSessionKeys.appGroupID
    public static let selectionMetadata = "trueInterrupt.selectionMetadata"
    public static let trueInterruptEnabled = "trueInterrupt.enabled"
    /// Legacy key — read for backward compat; new events are written to per-event slot keys.
    public static let eventLog = "trueInterrupt.ipc.eventLog"
    /// Prefix for per-event slot keys: `trueInterrupt.ipc.event.<UUID>`.
    /// Each recordEvent call writes exactly one key, making writes cross-process safe.
    public static let eventSlotPrefix = "trueInterrupt.ipc.event."
    public static let lastShieldStartedAt = "shield.lastStartedAt"
    public static let lastShieldEndedAt = "shield.lastEndedAt"
    public static let lastAccessRequestAt = "shield.lastAccessRequestAt"
}

public struct AppGroupSelectionSnapshot: Codable, Equatable, Sendable {
    public let categoryCount: Int
    public let appCount: Int
    public let lastUpdated: Date

    public var isEmpty: Bool { categoryCount == 0 && appCount == 0 }

    public static let empty = AppGroupSelectionSnapshot(
        categoryCount: 0,
        appCount: 0,
        lastUpdated: .distantPast
    )

    public init(categoryCount: Int, appCount: Int, lastUpdated: Date) {
        self.categoryCount = categoryCount
        self.appCount = appCount
        self.lastUpdated = lastUpdated
    }
}

public enum AppGroupIPCEventKind: String, Codable, Sendable {
    case shieldStarted
    case shieldEnded
    case shieldPathSelected
    case notificationFallbackScheduled
    case notificationFallbackSuppressed
    case notificationFallbackDelivered
    case accessRequested
    case watchdogHeartbeat
    case watchdogRecoveryTriggered
}

public struct AppGroupIPCEvent: Codable, Equatable, Sendable {
    public let id: UUID
    public let kind: AppGroupIPCEventKind
    public let reasonRaw: String?
    public let timestamp: Date
    public let detail: String?

    public init(
        id: UUID = UUID(),
        kind: AppGroupIPCEventKind,
        reasonRaw: String? = nil,
        timestamp: Date = Date(),
        detail: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.reasonRaw = reasonRaw
        self.timestamp = timestamp
        self.detail = detail
    }
}

public final class AppGroupIPCStore {
    public static let trueInterruptEnabledDidChangeNotification = Notification.Name(
        "AppGroupIPCStore.trueInterruptEnabledDidChange"
    )
    public static let trueInterruptEnabledValueUserInfoKey = "enabled"

    public enum StoreError: Error, Equatable {
        case appGroupSuiteUnavailable
        case corruptEventLog
        case corruptSelectionMetadata
        case corruptShieldSession
    }

    private static let log = Logger(
        subsystem: "com.yashasgujjar.kshana",
        category: "AppGroupIPC"
    )

    private let defaults: UserDefaults?
    private let maxEventCount: Int
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    /// In-process count of event slots written since the store was initialized.
    /// Initialized once from existing defaults; incremented on each `recordEvent`;
    /// reset to 0 on `clearEvents`. Serialized under `lock`.
    private var eventSlotCount: Int

    public init(
        defaults: UserDefaults? = AppGroupDefaults.resolve(consumer: "AppGroupIPCStore"),
        maxEventCount: Int = 100
    ) {
        self.defaults = defaults
        self.maxEventCount = max(1, maxEventCount)
        // One-time scan at startup to seed the counter from any pre-existing slots.
        if let defaults {
            self.eventSlotCount = defaults.dictionaryRepresentation().keys
                .filter { $0.hasPrefix(AppGroupIPCKeys.eventSlotPrefix) }
                .count
        } else {
            self.eventSlotCount = 0
        }
    }

    public var isAvailable: Bool {
        defaults != nil
    }

    @discardableResult
    public func setTrueInterruptEnabled(_ enabled: Bool) -> Bool {
        var changedValue: Bool?
        let didSet = withLock {
            guard let defaults else { return false }
            let previousValue = defaults.bool(forKey: AppGroupIPCKeys.trueInterruptEnabled)
            func writeEnabled(_ value: Bool) {
                defaults.set(value, forKey: AppGroupIPCKeys.trueInterruptEnabled)
                if previousValue != value {
                    changedValue = value
                }
            }

            if enabled {
                do {
                    guard try !readSelectionLocked(from: defaults).isEmpty else {
                        writeEnabled(false)
                        return false
                    }
                } catch {
                    writeEnabled(false)
                    return false
                }
            }
            writeEnabled(enabled)
            return true
        }
        if let changedValue {
            NotificationCenter.default.post(
                name: Self.trueInterruptEnabledDidChangeNotification,
                object: self,
                userInfo: [Self.trueInterruptEnabledValueUserInfoKey: changedValue]
            )
        }
        return didSet
    }

    public func isTrueInterruptEnabled() -> Bool {
        withLock {
            defaults?.bool(forKey: AppGroupIPCKeys.trueInterruptEnabled) ?? false
        }
    }

    public func writeSelection(_ snapshot: AppGroupSelectionSnapshot) throws {
        try withLock {
            guard let defaults else { throw StoreError.appGroupSuiteUnavailable }
            defaults.set(try encoder.encode(snapshot), forKey: AppGroupIPCKeys.selectionMetadata)
        }
    }

    public func readSelection() throws -> AppGroupSelectionSnapshot {
        try withLock {
            guard let defaults else { throw StoreError.appGroupSuiteUnavailable }
            return try readSelectionLocked(from: defaults)
        }
    }

    @discardableResult
    public func writeShieldSession(
        reasonRaw: String,
        durationSeconds: Double,
        triggeredAt: Date
    ) -> Bool {
        withLock {
            guard let defaults else { return false }
            guard let data = try? ShieldSessionSnapshot.encodedData(
                reasonRaw: reasonRaw,
                durationSeconds: durationSeconds,
                triggeredAt: triggeredAt,
                encoder: encoder
            ) else {
                return false
            }
            defaults.set(data, forKey: ShieldSessionKeys.sessionData)
            removeLegacyShieldSessionKeys(from: defaults)
            defaults.set(triggeredAt.timeIntervalSince1970, forKey: AppGroupIPCKeys.lastShieldStartedAt)
            return true
        }
    }

    public func readShieldSession() throws -> ShieldSessionSnapshot {
        try withLock {
            guard let defaults else { throw StoreError.appGroupSuiteUnavailable }
            if let data = defaults.data(forKey: ShieldSessionKeys.sessionData) {
                do {
                    return try ShieldSessionSnapshot.decode(from: data, decoder: decoder)
                } catch {
                    throw StoreError.corruptShieldSession
                }
            }
            return ShieldSessionSnapshot.read(from: defaults)
        }
    }

    @discardableResult
    public func clearShieldSession(endedAt: Date = Date()) -> Bool {
        withLock {
            guard let defaults else { return false }
            removeLegacyShieldSessionKeys(from: defaults)
            defaults.removeObject(forKey: ShieldSessionKeys.sessionData)
            defaults.set(endedAt.timeIntervalSince1970, forKey: AppGroupIPCKeys.lastShieldEndedAt)
            return true
        }
    }

    /// Records an event by writing it to a unique per-event slot key.
    ///
    /// Each call writes exactly one UserDefaults key (`trueInterrupt.ipc.event.<UUID>`),
    /// eliminating the read-modify-write cycle that was not safe across process boundaries.
    /// NSLock still provides in-process thread safety for the encoder and side-effect keys.
    public func recordEvent(_ event: AppGroupIPCEvent) throws {
        try withLock {
            guard let defaults else { throw StoreError.appGroupSuiteUnavailable }
            let slotKey = AppGroupIPCKeys.eventSlotPrefix + event.id.uuidString
            defaults.set(try encoder.encode(event), forKey: slotKey)
            if event.kind == .accessRequested {
                defaults.set(event.timestamp.timeIntervalSince1970, forKey: AppGroupIPCKeys.lastAccessRequestAt)
            }
            eventSlotCount += 1
            if eventSlotCount > maxEventCount {
                pruneEventSlots(defaults: defaults)
                // After pruning we hold exactly maxEventCount slots.
                eventSlotCount = maxEventCount
            }
        }
    }

    /// Reads all events by aggregating per-event slot keys and the legacy array key.
    public func readEvents() throws -> [AppGroupIPCEvent] {
        try withLock {
            guard let defaults else { throw StoreError.appGroupSuiteUnavailable }
            return try readEventsCombined(from: defaults)
        }
    }

    @discardableResult
    public func clearEvents() -> Bool {
        withLock {
            guard let defaults else { return false }
            defaults.removeObject(forKey: AppGroupIPCKeys.eventLog)
            for key in defaults.dictionaryRepresentation().keys
                where key.hasPrefix(AppGroupIPCKeys.eventSlotPrefix) {
                defaults.removeObject(forKey: key)
            }
            eventSlotCount = 0
            return true
        }
    }

    /// Aggregates events from per-event slot keys and the legacy array key,
    /// sorted by timestamp, capped to `maxEventCount`.
    private func readEventsCombined(from defaults: UserDefaults) throws -> [AppGroupIPCEvent] {
        var events: [AppGroupIPCEvent] = []

        // Backward compat: read legacy event array if present.
        if let data = defaults.data(forKey: AppGroupIPCKeys.eventLog) {
            do {
                events.append(contentsOf: try decoder.decode([AppGroupIPCEvent].self, from: data))
            } catch {
                Self.log.warning("Corrupt legacy eventLog key — skipping; continuing with per-slot reads")
            }
        }

        // Aggregate per-event slot keys (cross-process safe writes land here).
        for (key, value) in defaults.dictionaryRepresentation() {
            guard key.hasPrefix(AppGroupIPCKeys.eventSlotPrefix), let data = value as? Data else { continue }
            if let event = try? decoder.decode(AppGroupIPCEvent.self, from: data) {
                events.append(event)
            }
            // Corrupt individual slots are skipped to avoid failing the full read.
        }

        events.sort { $0.timestamp < $1.timestamp }
        if events.count > maxEventCount {
            events = Array(events.suffix(maxEventCount))
        }
        return events
    }

    /// Best-effort pruning: deletes the oldest slot keys when total exceeds `maxEventCount`.
    /// This is in-process only; the correctness guarantee comes from per-slot atomic writes.
    private func pruneEventSlots(defaults: UserDefaults) {
        var slots: [(key: String, timestamp: Date)] = []
        for (key, value) in defaults.dictionaryRepresentation() {
            guard key.hasPrefix(AppGroupIPCKeys.eventSlotPrefix), let data = value as? Data,
                  let event = try? decoder.decode(AppGroupIPCEvent.self, from: data)
            else { continue }
            slots.append((key, event.timestamp))
        }
        guard slots.count > maxEventCount else { return }
        let toDelete = slots.sorted { $0.timestamp < $1.timestamp }.prefix(slots.count - maxEventCount)
        for item in toDelete {
            defaults.removeObject(forKey: item.key)
        }
    }

    private func readSelectionLocked(from defaults: UserDefaults) throws -> AppGroupSelectionSnapshot {
        guard let data = defaults.data(forKey: AppGroupIPCKeys.selectionMetadata) else {
            return .empty
        }
        do {
            return try decoder.decode(AppGroupSelectionSnapshot.self, from: data)
        } catch {
            throw StoreError.corruptSelectionMetadata
        }
    }

    private func removeLegacyShieldSessionKeys(from defaults: UserDefaults) {
        defaults.removeObject(forKey: ShieldSessionKeys.breakReason)
        defaults.removeObject(forKey: ShieldSessionKeys.durationSeconds)
        defaults.removeObject(forKey: ShieldSessionKeys.triggeredAt)
    }

    private func withLock<T>(_ action: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try action()
    }
}
