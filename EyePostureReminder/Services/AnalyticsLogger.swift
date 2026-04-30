import Foundation
import os
import ScreenTimeExtensionShared

// MARK: - AnalyticsEvent

/// Structured analytics events for Xcode Instruments / Console.app debugging.
/// All events are emitted via `os.Logger` — no SDK, no network calls.
enum AnalyticsEvent: Sendable {

    // MARK: Session

    /// Fired at the start of a reminder session (scheduleReminders called).
    case appSessionStart(eyeEnabled: Bool, postureEnabled: Bool, snoozeActive: Bool)

    /// Fired when the app resigns active.
    case appSessionEnd(sessionDurationS: TimeInterval)

    // MARK: Reminders

    /// Fired when a reminder is triggered. `deliveryPath` records whether the reminder
    /// was surfaced via the foreground screen-time threshold or the notification fallback.
    case reminderTriggered(type: ReminderType, thresholdS: TimeInterval, deliveryPath: ReminderDeliveryPath)

    /// The mechanism that actually surfaced a reminder to the user.
    enum ReminderDeliveryPath: String {
        case screenTimeThreshold  = "screen_time_threshold"
        case notificationFallback = "notification_fallback"
        case unknown              = "unknown"
    }

    // MARK: Schedule Path Selection

    /// Fired when `scheduleReminders()` selects a delivery path.
    /// Emitted after IPC recording — provides the same routing decision in the analytics stream.
    case schedulePathSelected(path: SchedulePath, reason: SchedulePathReason)

    /// Non-PII code for the path chosen by `scheduleReminders()`.
    enum SchedulePath: String {
        case shield               = "shield"
        case notificationFallback = "notification_fallback"
    }

    /// Non-PII reason code explaining why a particular schedule path was selected.
    enum SchedulePathReason: String {
        case deviceActivityAvailable      = "device_activity_available"
        case shieldUnavailable            = "shield_unavailable"
        case trueInterruptDisabled        = "true_interrupt_disabled"
        case trueInterruptEmptySelection  = "true_interrupt_empty_selection"
        /// Defensive path: shield routing state became available between the
        /// `shouldScheduleNotificationFallback` check and `fallbackRoutingContext()`.
        case unexpectedShieldRoutingState = "unexpected_shield_routing_state"
    }

    // MARK: Shield Lifecycle

    /// Fired when a DeviceActivity shield session starts successfully.
    /// `reason` is the typed shield trigger reason.
    case shieldActivated(reason: ShieldTriggerReason)

    /// Fired when a DeviceActivity shield activation attempt fails.
    /// `reason` is the typed shield trigger reason.
    case shieldActivationFailed(reason: ShieldTriggerReason)

    /// Fired when a DeviceActivity shield session is cancelled/deactivated.
    case shieldDeactivated

    // MARK: Overlay

    /// Fired on manual dismissal of an overlay (button, swipe, or settings tap).
    case overlayDismissed(type: ReminderType, method: DismissMethod, elapsedS: TimeInterval)

    /// Fired when the countdown reaches zero and the overlay auto-dismisses.
    case overlayAutoDismissed(type: ReminderType, durationS: TimeInterval)

    /// The mechanism that triggered a manual overlay dismissal.
    enum DismissMethod: String {
        case button       = "button"
        case swipe        = "swipe"
        case settingsTap  = "settings_tap"
    }

    // MARK: Snooze
    /// Fired when the user activates a snooze.
    case snoozeActivated(durationOption: String)

    /// Fired when a snooze period expires and normal scheduling resumes.
    case snoozeExpired

    /// Fired when the user manually cancels an active snooze.
    case snoozeCancelled

    // MARK: Settings

    /// Fired when a user-facing setting is changed.
    case settingChanged(setting: SettingKey, oldValue: String, newValue: String)

    // MARK: Pause

    /// Fired when a pause condition (focus, driving, CarPlay) becomes active.
    case pauseActivated(conditionType: String)

    /// Fired when a pause condition is cleared and reminders resume.
    case pauseDeactivated(conditionType: String)

    // MARK: Watchdog Recovery

    /// Fired when a stale watchdog session is detected and recovery is initiated.
    /// `reason` is the typed shield trigger reason (nil if session had no recognisable reason);
    /// `detail` is the heartbeat staleness category.
    case watchdogRecoveryTriggered(reason: ShieldTriggerReason?, detail: String)

    /// Fired at the end of a watchdog recovery attempt.
    /// `sessionCleared` – whether the stale shield session was successfully cleared.
    /// `fallbackScheduled` – whether a fallback notification was rescheduled.
    case watchdogRecoveryCompleted(sessionCleared: Bool, fallbackScheduled: Bool)

    // MARK: IPC Health

    /// Fired when an App Group IPC read or write operation fails.
    /// Both fields are enumerated codes — no PII, no bundle identifiers, no raw errors.
    case ipcOperationFailed(operation: IPCOperation, reason: IPCFailureReason)

    /// Non-PII operation codes for IPC health events.
    enum IPCOperation: String {
        case readShieldSession  = "read_shield_session"
        case readEvents         = "read_events"
        case clearShieldSession = "clear_shield_session"
        case writeEvent         = "write_event"
        case writeShieldSession = "write_shield_session"
        case readSelection      = "read_selection"
    }

    /// Non-PII reason codes for IPC health events.
    enum IPCFailureReason: String {
        case unavailable = "unavailable"
        case corrupt     = "corrupt"
        case writeFailed = "write_failed"
        case unknown     = "unknown"
    }

    // MARK: Onboarding

    /// Fired when the user completes onboarding. `cta` records which exit button was tapped.
    case onboardingCompleted(cta: OnboardingCTA)

    /// Non-PII code for the onboarding exit CTA the user tapped.
    enum OnboardingCTA: String, CaseIterable {
        case getStarted = "get_started"
        case customize  = "customize"
    }

    // MARK: SettingKey

    // swiftlint:disable redundant_string_enum_value
    /// Non-PII key names for the `settingChanged` analytics event.
    enum SettingKey: String, CaseIterable {
        case globalEnabled               = "globalEnabled"
        case eyesEnabled                 = "eyesEnabled"
        case eyesInterval                = "eyesInterval"
        case eyesBreakDuration           = "eyesBreakDuration"
        case postureEnabled              = "postureEnabled"
        case postureInterval             = "postureInterval"
        case postureBreakDuration        = "postureBreakDuration"
        case pauseDuringFocus            = "pauseDuringFocus"
        case pauseWhileDriving           = "pauseWhileDriving"
        case hapticsEnabled              = "hapticsEnabled"
        case notificationFallbackEnabled = "notificationFallbackEnabled"
    }
    // swiftlint:enable redundant_string_enum_value
}

// MARK: - AnalyticsLogger

/// Lightweight analytics sink that writes structured events to `os.Logger`.
/// Visible in Xcode Instruments, Console.app, and TestFlight crash reports.
enum AnalyticsLogger {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yashasgujjar.eyeposture",
        category: "Analytics"
    )

#if DEBUG
    /// Test-only hook. Set in unit tests to intercept emitted events; must be
    /// reset to `nil` in `tearDown` to avoid cross-test contamination.
    static var testEventHandler: ((AnalyticsEvent) -> Void)?
#endif

    /// Emit an analytics event as a structured os.Logger entry.
    static func log(_ event: AnalyticsEvent) {
#if DEBUG
        testEventHandler?(event)
#endif
        switch event {

        case let .appSessionStart(eyeEnabled, postureEnabled, snoozeActive):
            logger.info("""
                event=app_session_start \
                eye_enabled=\(eyeEnabled, privacy: .public) \
                posture_enabled=\(postureEnabled, privacy: .public) \
                snooze_active=\(snoozeActive, privacy: .public)
                """)

        case let .appSessionEnd(durationS):
            logger.info("""
                event=app_session_end \
                session_duration_s=\(durationS, format: .fixed(precision: 1), privacy: .public)
                """)

        case let .reminderTriggered(type, thresholdS, deliveryPath):
            logger.info("""
                event=reminder_triggered \
                type=\(type.rawValue, privacy: .public) \
                threshold_s=\(thresholdS, format: .fixed(precision: 0), privacy: .public) \
                delivery_path=\(deliveryPath.rawValue, privacy: .public)
                """)

        case let .overlayDismissed(type, method, elapsedS):
            logger.info("""
                event=overlay_dismissed \
                type=\(type.rawValue, privacy: .public) \
                method=\(method.rawValue, privacy: .public) \
                elapsed_s=\(elapsedS, format: .fixed(precision: 1), privacy: .public)
                """)

        case let .overlayAutoDismissed(type, durationS):
            logger.info("""
                event=overlay_auto_dismissed \
                type=\(type.rawValue, privacy: .public) \
                duration_s=\(durationS, format: .fixed(precision: 0), privacy: .public)
                """)

        case let .snoozeActivated(durationOption):
            logger.info("""
                event=snooze_activated \
                duration_option=\(durationOption, privacy: .public)
                """)

        case .snoozeExpired:
            logger.info("event=snooze_expired")

        case .snoozeCancelled:
            logger.info("event=snooze_cancelled")

        case let .settingChanged(setting, oldValue, newValue):
            logger.info("""
                event=setting_changed \
                setting=\(setting.rawValue, privacy: .public) \
                old_value=\(oldValue, privacy: .private) \
                new_value=\(newValue, privacy: .private)
                """)

        default:
            logExtended(event)
        }
    }

    // Logs extended event cases to keep `log(_:)` within cyclomatic-complexity limits.
    private static func logExtended(_ event: AnalyticsEvent) {
        switch event {

        case let .pauseActivated(conditionType):
            logger.info("""
                event=pause_activated \
                condition_type=\(conditionType, privacy: .public)
                """)

        case let .pauseDeactivated(conditionType):
            logger.info("""
                event=pause_deactivated \
                condition_type=\(conditionType, privacy: .public)
                """)

        case let .watchdogRecoveryTriggered(reason, detail):
            logger.info("""
                event=watchdog_recovery_triggered \
                reason=\(reason?.rawValue ?? "unknown", privacy: .public) \
                detail=\(detail, privacy: .public)
                """)

        case let .watchdogRecoveryCompleted(sessionCleared, fallbackScheduled):
            logger.info("""
                event=watchdog_recovery_completed \
                session_cleared=\(sessionCleared, privacy: .public) \
                fallback_scheduled=\(fallbackScheduled, privacy: .public)
                """)

        case let .schedulePathSelected(path, reason):
            logger.info("""
                event=schedule_path_selected \
                path=\(path.rawValue, privacy: .public) \
                reason=\(reason.rawValue, privacy: .public)
                """)

        case let .shieldActivated(reason):
            logger.info("""
                event=shield_activated \
                reason=\(reason.rawValue, privacy: .public)
                """)

        case let .shieldActivationFailed(reason):
            logger.error("""
                event=shield_activation_failed \
                reason=\(reason.rawValue, privacy: .public)
                """)

        case .shieldDeactivated:
            logger.info("event=shield_deactivated")

        case let .ipcOperationFailed(operation, reason):
            logger.error("""
                event=ipc_operation_failed \
                operation=\(operation.rawValue, privacy: .public) \
                reason=\(reason.rawValue, privacy: .public)
                """)

        case let .onboardingCompleted(cta):
            logger.info("""
                event=onboarding_completed \
                cta=\(cta.rawValue, privacy: .public)
                """)

        default:
            assertionFailure("Unhandled analytics event — add a case to logExtended(_:): \(event)")
        }
    }
}
