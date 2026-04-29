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
    public enum StoreError: Error {
        case corruptEventLog
        case corruptSelectionMetadata
    }

    private let defaults: UserDefaults
    private let maxEventCount: Int
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        defaults: UserDefaults = UserDefaults(suiteName: AppGroupIPCKeys.appGroupID) ?? .standard,
        maxEventCount: Int = 100
    ) {
        self.defaults = defaults
        self.maxEventCount = max(1, maxEventCount)
    }

    public func setTrueInterruptEnabled(_ enabled: Bool) {
        withLock {
            defaults.set(enabled, forKey: AppGroupIPCKeys.trueInterruptEnabled)
        }
    }

    public func isTrueInterruptEnabled() -> Bool {
        withLock {
            defaults.bool(forKey: AppGroupIPCKeys.trueInterruptEnabled)
        }
    }

    public func writeSelection(_ snapshot: AppGroupSelectionSnapshot) throws {
        try withLock {
            defaults.set(try encoder.encode(snapshot), forKey: AppGroupIPCKeys.selectionMetadata)
        }
    }

    public func readSelection() throws -> AppGroupSelectionSnapshot {
        try withLock {
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

    public func writeShieldSession(
        reasonRaw: String,
        durationSeconds: Double,
        triggeredAt: Date
    ) {
        withLock {
            defaults.set(reasonRaw, forKey: ShieldSessionKeys.breakReason)
            defaults.set(durationSeconds, forKey: ShieldSessionKeys.durationSeconds)
            defaults.set(triggeredAt.timeIntervalSince1970, forKey: ShieldSessionKeys.triggeredAt)
            defaults.set(triggeredAt.timeIntervalSince1970, forKey: AppGroupIPCKeys.lastShieldStartedAt)
        }
    }

    public func readShieldSession() -> ShieldSessionSnapshot {
        withLock {
            ShieldSessionSnapshot.read(from: defaults)
        }
    }

    public func clearShieldSession(endedAt: Date = Date()) {
        withLock {
            defaults.removeObject(forKey: ShieldSessionKeys.breakReason)
            defaults.removeObject(forKey: ShieldSessionKeys.durationSeconds)
            defaults.removeObject(forKey: ShieldSessionKeys.triggeredAt)
            defaults.set(endedAt.timeIntervalSince1970, forKey: AppGroupIPCKeys.lastShieldEndedAt)
        }
    }

    public func recordEvent(_ event: AppGroupIPCEvent) throws {
        try withLock {
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
            try readEventsLocked()
        }
    }

    public func clearEvents() {
        withLock {
            defaults.removeObject(forKey: AppGroupIPCKeys.eventLog)
        }
    }

    private func readEventsLocked() throws -> [AppGroupIPCEvent] {
        guard let data = defaults.data(forKey: AppGroupIPCKeys.eventLog) else { return [] }
        do {
            return try decoder.decode([AppGroupIPCEvent].self, from: data)
        } catch {
            throw StoreError.corruptEventLog
        }
    }

    private func withLock<T>(_ action: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try action()
    }
}
