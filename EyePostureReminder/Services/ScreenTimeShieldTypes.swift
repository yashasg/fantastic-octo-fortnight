/// Domain types for the Screen Time shield integration.
///
/// These types are used by `ScreenTimeShieldProviding` and written to the shared
/// App Group `UserDefaults` so the `DeviceActivityMonitorExtension` can read them
/// without importing the main app module.
///
/// **Entitlement status:** The types compile unconditionally. The real
/// `FamilyControls`/`ManagedSettings` integration is gated behind `#201` and
/// lives in a separate extension target (not expressible in SPM alone).

import Foundation
import ScreenTimeExtensionShared

// MARK: - ShieldTriggerReason

/// Why the Screen Time shield was triggered.
///
/// Drives the copy shown inside the `ShieldConfigurationExtension`
/// (title, subtitle, icon) and is stored in the shared App Group so
/// the extension can read it without importing the main app module.
enum ShieldTriggerReason: String, Sendable, Equatable {
    /// A scheduled eye-strain break (20-20-20 rule or configured interval).
    case scheduledEyesBreak = "eyes"
    /// A scheduled posture/movement break.
    case scheduledPostureBreak = "posture"

    var reminderType: ReminderType? {
        switch self {
        case .scheduledEyesBreak:
            return .eyes
        case .scheduledPostureBreak:
            return .posture
        }
    }
}

// MARK: - ShieldSession

/// Describes a single, discrete screen-time shielding session.
///
/// Created by `AppCoordinator` when a break begins and passed to
/// `ScreenTimeShieldProviding.beginShield(for:)` and
/// `DeviceActivityMonitorProviding.scheduleBreakMonitoring(for:)`.
struct ShieldSession: Sendable, Equatable {
    /// The reason the shield is being applied.
    let reason: ShieldTriggerReason
    /// How long the shield should remain active, in seconds.
    let durationSeconds: TimeInterval
    /// Wall-clock time at which the break was triggered.
    let triggeredAt: Date

    // MARK: Shared UserDefaults keys (App Group: group.com.yashasgujjar.kshana)

    static let sessionDataKey = ShieldSessionKeys.sessionData
    static let reasonKey = ShieldSessionKeys.breakReason
    static let durationKey = ShieldSessionKeys.durationSeconds
    /// Wall-clock trigger time stored as `timeIntervalSince1970` (`Double`).
    static let triggeredAtKey = ShieldSessionKeys.triggeredAt
}

// MARK: - ShieldSession + ReminderType

extension ShieldSession {
    /// Convenience initialiser that derives the `ShieldTriggerReason` from a `ReminderType`.
    ///
    /// Used by `AppCoordinator` when bridging the `ScreenTimeTracker.onThresholdReached`
    /// callback into a `DeviceActivityMonitorProviding.scheduleBreakMonitoring(for:)` call.
    ///
    /// - Parameters:
    ///   - type: The reminder type that reached its threshold.
    ///   - durationSeconds: Break duration in seconds (read from `SettingsStore`).
    ///   - triggeredAt: Wall-clock trigger time. Defaults to `Date()`.
    init(type: ReminderType, durationSeconds: TimeInterval, triggeredAt: Date = Date()) {
        self.init(reason: type.shieldReason, durationSeconds: durationSeconds, triggeredAt: triggeredAt)
    }
}

extension ReminderType {
    var shieldReason: ShieldTriggerReason {
        switch self {
        case .eyes:
            return .scheduledEyesBreak
        case .posture:
            return .scheduledPostureBreak
        }
    }
}
