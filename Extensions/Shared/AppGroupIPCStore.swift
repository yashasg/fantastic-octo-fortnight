import Foundation

public enum AppGroupIPCKeys {
    public static let appGroupID = ShieldSessionKeys.appGroupID
    public static let selectionMetadata = "trueInterrupt.selectionMetadata"
    public static let trueInterruptEnabled = "trueInterrupt.enabled"
    public static let eventLog = "trueInterrupt.ipc.eventLog"
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
    public enum StoreError: Error, Equatable {
        case appGroupSuiteUnavailable
        case corruptEventLog
        case corruptSelectionMetadata
        case corruptShieldSession
    }

    private let defaults: UserDefaults?
    private let maxEventCount: Int
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        defaults: UserDefaults? = AppGroupDefaults.resolve(consumer: "AppGroupIPCStore"),
        maxEventCount: Int = 100
    ) {
        self.defaults = defaults
        self.maxEventCount = max(1, maxEventCount)
    }

    public var isAvailable: Bool {
        defaults != nil
    }

    @discardableResult
    public func setTrueInterruptEnabled(_ enabled: Bool) -> Bool {
        withLock {
            guard let defaults else { return false }
            defaults.set(enabled, forKey: AppGroupIPCKeys.trueInterruptEnabled)
            return true
        }
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
            guard let data = defaults.data(forKey: AppGroupIPCKeys.selectionMetadata) else {
                return .empty
            }
            do {
                return try decoder.decode(AppGroupSelectionSnapshot.self, from: data)
            } catch {
                throw StoreError.corruptSelectionMetadata
            }
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

    public func recordEvent(_ event: AppGroupIPCEvent) throws {
        try withLock {
            guard let defaults else { throw StoreError.appGroupSuiteUnavailable }
            var events = try readEventsLocked()
            events.append(event)
            if events.count > maxEventCount {
                events.removeFirst(events.count - maxEventCount)
            }
            if event.kind == .accessRequested {
                defaults.set(event.timestamp.timeIntervalSince1970, forKey: AppGroupIPCKeys.lastAccessRequestAt)
            }
            defaults.set(try encoder.encode(events), forKey: AppGroupIPCKeys.eventLog)
        }
    }

    public func readEvents() throws -> [AppGroupIPCEvent] {
        try withLock {
            guard defaults != nil else { throw StoreError.appGroupSuiteUnavailable }
            return try readEventsLocked()
        }
    }

    @discardableResult
    public func clearEvents() -> Bool {
        withLock {
            guard let defaults else { return false }
            defaults.removeObject(forKey: AppGroupIPCKeys.eventLog)
            return true
        }
    }

    private func readEventsLocked() throws -> [AppGroupIPCEvent] {
        guard let defaults else { throw StoreError.appGroupSuiteUnavailable }
        guard let data = defaults.data(forKey: AppGroupIPCKeys.eventLog) else { return [] }
        do {
            return try decoder.decode([AppGroupIPCEvent].self, from: data)
        } catch {
            throw StoreError.corruptEventLog
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
