import Foundation

struct ShieldSessionSnapshot: Equatable {
    let reasonRaw: String?
    let durationSeconds: Double
    let triggeredAt: Date?

    static func read(from defaults: UserDefaults?) -> ShieldSessionSnapshot {
        let timestamp = defaults?.object(forKey: ShieldSessionKeys.triggeredAt) as? Double
        return ShieldSessionSnapshot(
            reasonRaw: defaults?.string(forKey: ShieldSessionKeys.breakReason),
            durationSeconds: defaults?.double(forKey: ShieldSessionKeys.durationSeconds) ?? 0,
            triggeredAt: timestamp.map { Date(timeIntervalSince1970: $0) }
        )
    }

    func remainingSeconds(at now: Date = Date()) -> Int? {
        guard durationSeconds > 0, let triggeredAt else { return nil }
        let remaining = durationSeconds - now.timeIntervalSince(triggeredAt)
        return max(0, Int(ceil(remaining)))
    }
}

struct ShieldConfigurationCopy: Equatable {
    let title: String
    let subtitle: String

    static func make(
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
