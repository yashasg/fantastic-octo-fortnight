/// Why a Screen Time shield was triggered.
///
/// Shared by the main app and Screen Time extensions so shield routing cannot
/// drift through duplicated raw-string comparisons.
public enum ShieldTriggerReason: String, CaseIterable, Codable, Equatable, Sendable {
    /// A scheduled eye-strain break (20-20-20 rule or configured interval).
    case scheduledEyesBreak = "eyes"
    /// A scheduled posture/movement break.
    case scheduledPostureBreak = "posture"
}
