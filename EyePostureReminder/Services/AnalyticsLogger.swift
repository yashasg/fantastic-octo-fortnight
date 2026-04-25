import Foundation
import os

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

    /// Fired when the screen-time tracker crosses a threshold and triggers an overlay.
    case reminderTriggered(type: ReminderType, thresholdS: TimeInterval)

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
    case settingChanged(setting: String, oldValue: String, newValue: String)

    // MARK: Pause

    /// Fired when a pause condition (focus, driving, CarPlay) becomes active.
    case pauseActivated(conditionType: String)

    /// Fired when a pause condition is cleared and reminders resume.
    case pauseDeactivated(conditionType: String)
}

// MARK: - AnalyticsLogger

/// Lightweight analytics sink that writes structured events to `os.Logger`.
/// Visible in Xcode Instruments, Console.app, and TestFlight crash reports.
enum AnalyticsLogger {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yashasgujjar.eyeposture",
        category: "Analytics"
    )

    /// Emit an analytics event as a structured os.Logger entry.
    static func log(_ event: AnalyticsEvent) {
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

        case let .reminderTriggered(type, thresholdS):
            logger.info("""
                event=reminder_triggered \
                type=\(type.rawValue, privacy: .public) \
                threshold_s=\(thresholdS, format: .fixed(precision: 0), privacy: .public)
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
                setting=\(setting, privacy: .public) \
                old_value=\(oldValue, privacy: .public) \
                new_value=\(newValue, privacy: .public)
                """)

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
        }
    }
}
