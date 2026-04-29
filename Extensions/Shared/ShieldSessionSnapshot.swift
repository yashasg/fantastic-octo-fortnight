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
        now: Date = Date(),
        bundle: Bundle? = nil
    ) -> ShieldConfigurationCopy {
        let action = actionCopy(for: snapshot.reasonRaw, bundle: bundle)
        if let remaining = snapshot.remainingSeconds(at: now), remaining > 5 {
            return ShieldConfigurationCopy(
                title: action.title,
                subtitle: ShieldConfigurationCopyLocalization.countdownSubtitle(
                    remainingSeconds: remaining,
                    actionSubtitle: action.subtitle,
                    bundle: bundle
                )
            )
        }
        return ShieldConfigurationCopy(title: action.title, subtitle: action.subtitle)
    }

    private static func actionCopy(
        for reasonRaw: String?,
        bundle: Bundle?
    ) -> (title: String, subtitle: String) {
        switch reasonRaw {
        case "eyes":
            return (
                ShieldConfigurationCopyLocalization.localizedString(for: .eyesTitle, bundle: bundle),
                ShieldConfigurationCopyLocalization.localizedString(for: .eyesSubtitle, bundle: bundle)
            )
        case "posture":
            return (
                ShieldConfigurationCopyLocalization.localizedString(for: .postureTitle, bundle: bundle),
                ShieldConfigurationCopyLocalization.localizedString(for: .postureSubtitle, bundle: bundle)
            )
        default:
            return (
                ShieldConfigurationCopyLocalization.localizedString(for: .genericTitle, bundle: bundle),
                ShieldConfigurationCopyLocalization.localizedString(for: .genericSubtitle, bundle: bundle)
            )
        }
    }
}
