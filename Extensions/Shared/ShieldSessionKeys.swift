/// Shared UserDefaults keys for Screen Time extension ↔ main app communication.
///
/// Keys **must** match the static constants defined in
/// `EyePostureReminder/Services/ScreenTimeShieldTypes.swift` (`ShieldSession`).
/// Duplicated here because App Extension targets cannot import the main app module.
///
/// App Group: `group.com.yashasgujjar.kshana`

public enum ShieldSessionKeys {
    /// Encoded `ShieldSessionSnapshot` payload for atomic cross-process session reads.
    public static let sessionData = "shield.session"
    /// Raw string value of `ShieldTriggerReason` ("eyes" or "posture").
    public static let breakReason = "shield.breakReason"
    /// Break duration in seconds (`TimeInterval` stored as Double).
    public static let durationSeconds = "shield.durationSeconds"
    /// Wall-clock trigger time stored as `timeIntervalSince1970` (`Double`).
    public static let triggeredAt = "shield.triggeredAt"
    /// Shared App Group suite name.
    public static let appGroupID = "group.com.yashasgujjar.kshana"
}
