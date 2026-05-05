import Foundation

public enum ShieldIntervalEndSessionState: Equatable, Sendable {
    case valid
    case missingOrCorrupt
}

public struct ShieldIntervalEndCleanupDecision: Equatable, Sendable {
    public let shouldClearRestrictions: Bool
    public let sessionState: ShieldIntervalEndSessionState

    public init(
        shouldClearRestrictions: Bool,
        sessionState: ShieldIntervalEndSessionState
    ) {
        self.shouldClearRestrictions = shouldClearRestrictions
        self.sessionState = sessionState
    }
}

public enum ShieldIntervalEndCleanupPolicy {
    public static func decision(
        for snapshot: ShieldSessionSnapshot
    ) -> ShieldIntervalEndCleanupDecision {
        ShieldIntervalEndCleanupDecision(
            shouldClearRestrictions: true,
            sessionState: snapshot.triggeredAt == nil ? .missingOrCorrupt : .valid
        )
    }
}
