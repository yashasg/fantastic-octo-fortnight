import Foundation

public enum ShieldSessionSnapshotEncodingError: Error, Equatable {
    case invalidDurationSeconds(Double)
}

public struct ShieldSessionSnapshot: Equatable, Sendable {
    public let reasonRaw: String?
    public let durationSeconds: Double
    public let triggeredAt: Date?

    public init(reasonRaw: String?, durationSeconds: Double, triggeredAt: Date?) {
        self.reasonRaw = reasonRaw
        self.durationSeconds = durationSeconds
        self.triggeredAt = triggeredAt
    }

    public static let empty = ShieldSessionSnapshot(reasonRaw: nil, durationSeconds: 0, triggeredAt: nil)

    public var reason: ShieldTriggerReason? {
        reasonRaw.flatMap(ShieldTriggerReason.init(rawValue:))
    }

    public static func isValidDurationSeconds(_ durationSeconds: Double) -> Bool {
        durationSeconds.isFinite && durationSeconds > 0
    }

    public static func encodedData(
        reasonRaw: String,
        durationSeconds: Double,
        triggeredAt: Date,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Data {
        guard isValidDurationSeconds(durationSeconds) else {
            throw ShieldSessionSnapshotEncodingError.invalidDurationSeconds(durationSeconds)
        }
        return try encoder.encode(
            ShieldSessionPayload(
                reasonRaw: reasonRaw,
                durationSeconds: durationSeconds,
                triggeredAtSeconds: triggeredAt.timeIntervalSince1970
            )
        )
    }

    public static func decode(from data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> ShieldSessionSnapshot {
        let payload = try decoder.decode(ShieldSessionPayload.self, from: data)
        guard isValidDurationSeconds(payload.durationSeconds), payload.triggeredAtSeconds.isFinite else {
            throw ShieldSessionSnapshotEncodingError.invalidDurationSeconds(payload.durationSeconds)
        }
        return payload.snapshot
    }

    public static func read(from defaults: UserDefaults?) -> ShieldSessionSnapshot {
        guard let defaults else { return .empty }
        if let data = defaults.data(forKey: ShieldSessionKeys.sessionData) {
            return (try? decode(from: data)) ?? .empty
        }
        return readLegacySnapshot(from: defaults)
    }

    private static func readLegacySnapshot(from defaults: UserDefaults) -> ShieldSessionSnapshot {
        guard
            let reasonRaw = defaults.string(forKey: ShieldSessionKeys.breakReason),
            let durationSeconds = defaults.object(forKey: ShieldSessionKeys.durationSeconds) as? Double,
            let timestamp = defaults.object(forKey: ShieldSessionKeys.triggeredAt) as? Double,
            isValidDurationSeconds(durationSeconds),
            timestamp.isFinite
        else {
            return .empty
        }
        return ShieldSessionSnapshot(
            reasonRaw: reasonRaw,
            durationSeconds: durationSeconds,
            triggeredAt: Date(timeIntervalSince1970: timestamp)
        )
    }

    public func remainingSeconds(at now: Date = Date()) -> Int? {
        guard Self.isValidDurationSeconds(durationSeconds), let triggeredAt else { return nil }
        let remaining = durationSeconds - now.timeIntervalSince(triggeredAt)
        return max(0, Int(ceil(remaining)))
    }

    /// Returns `true` when `activityName` matches this session's trigger reason,
    /// or when no active session is present (`reasonRaw` is `nil`).
    ///
    /// The DeviceActivity naming convention encodes the session reason as the
    /// activity's `rawValue` (e.g. `"eyes"` or `"posture"`).  This guards
    /// `intervalDidEnd` against stale OS callbacks for already-cancelled or
    /// mismatched activity windows.
    public func activityMatchesOrAbsent(activityName: String) -> Bool {
        guard let reasonRaw else { return true }
        return activityName == reasonRaw
    }
}

private struct ShieldSessionPayload: Codable {
    let reasonRaw: String
    let durationSeconds: Double
    let triggeredAtSeconds: Double

    var snapshot: ShieldSessionSnapshot {
        ShieldSessionSnapshot(
            reasonRaw: reasonRaw,
            durationSeconds: durationSeconds,
            triggeredAt: Date(timeIntervalSince1970: triggeredAtSeconds)
        )
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
        let action = actionCopy(for: snapshot.reason, bundle: bundle)
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
        for reason: ShieldTriggerReason?,
        bundle: Bundle?
    ) -> (title: String, subtitle: String) {
        guard let reason else {
            return (
                ShieldConfigurationCopyLocalization.localizedString(for: .genericTitle, bundle: bundle),
                ShieldConfigurationCopyLocalization.localizedString(for: .genericSubtitle, bundle: bundle)
            )
        }

        switch reason {
        case .scheduledEyesBreak:
            return (
                ShieldConfigurationCopyLocalization.localizedString(for: .eyesTitle, bundle: bundle),
                ShieldConfigurationCopyLocalization.localizedString(for: .eyesSubtitle, bundle: bundle)
            )
        case .scheduledPostureBreak:
            return (
                ShieldConfigurationCopyLocalization.localizedString(for: .postureTitle, bundle: bundle),
                ShieldConfigurationCopyLocalization.localizedString(for: .postureSubtitle, bundle: bundle)
            )
        }
    }
}
