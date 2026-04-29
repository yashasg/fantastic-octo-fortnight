/// Shared UserDefaults keys for Screen Time extension ↔ main app communication.
///
/// Keys **must** match the static constants defined in
/// `EyePostureReminder/Services/ScreenTimeShieldTypes.swift` (`ShieldSession`).
/// Duplicated here because App Extension targets cannot import the main app module.
///
/// App Group: `group.com.yashasgujjar.kshana`

enum ShieldSessionKeys {
    /// Raw string value of `ShieldTriggerReason` ("eyes" or "posture").
    static let breakReason = "shield.breakReason"
    /// Break duration in seconds (`TimeInterval` stored as Double).
    static let durationSeconds = "shield.durationSeconds"
    /// Wall-clock trigger time stored as `timeIntervalSince1970` (`Double`).
    static let triggeredAt = "shield.triggeredAt"
    /// Shared App Group suite name.
    static let appGroupID = "group.com.yashasgujjar.kshana"
}
