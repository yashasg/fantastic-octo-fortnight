import Foundation

public struct ShieldSessionSnapshot: Equatable {
    public let reasonRaw: String?
    public let durationSeconds: Double
    public let triggeredAt: Date?

    public init(reasonRaw: String?, durationSeconds: Double, triggeredAt: Date?) {
        self.reasonRaw = reasonRaw
        self.durationSeconds = durationSeconds
        self.triggeredAt = triggeredAt
    }

    public static func read(from defaults: UserDefaults?) -> ShieldSessionSnapshot {
        let timestamp = defaults?.object(forKey: ShieldSessionKeys.triggeredAt) as? Double
        return ShieldSessionSnapshot(
            reasonRaw: defaults?.string(forKey: ShieldSessionKeys.breakReason),
            durationSeconds: defaults?.double(forKey: ShieldSessionKeys.durationSeconds) ?? 0,
            triggeredAt: timestamp.map { Date(timeIntervalSince1970: $0) }
        )
    }

    public func remainingSeconds(at now: Date = Date()) -> Int? {
        guard durationSeconds > 0, let triggeredAt else { return nil }
        let remaining = durationSeconds - now.timeIntervalSince(triggeredAt)
        return max(0, Int(ceil(remaining)))
    }
}

public struct ShieldConfigurationCopy: Equatable {
    public let title: String
    public let subtitle: String

    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    public static func make(
        for snapshot: ShieldSessionSnapshot,
        now: Date = Date()
    ) -> ShieldConfigurationCopy {
        let action = actionCopy(for: snapshot.reasonRaw)
        if let remaining = snapshot.remainingSeconds(at: now), remaining > 5 {
            return ShieldConfigurationCopy(
                title: action.title,
                subtitle: "\(remaining) seconds remaining. \(action.subtitle)"
            )
        }
        return ShieldConfigurationCopy(title: action.title, subtitle: action.subtitle)
    }

    private static func actionCopy(for reasonRaw: String?) -> (title: String, subtitle: String) {
        switch reasonRaw {
        case "eyes":
            return ("Time for an eye break", "Look 20 feet away and soften your focus.")
        case "posture":
            return ("Time for a posture break", "Stand up, roll your shoulders, and reset.")
        default:
            return ("Time for a break", "Take a moment away from the screen.")
        }
    }
}
