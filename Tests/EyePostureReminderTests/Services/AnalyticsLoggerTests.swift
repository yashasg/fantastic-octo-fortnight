@testable import EyePostureReminder
import ScreenTimeExtensionShared
import XCTest

/// Tests for `AnalyticsLogger` and `AnalyticsEvent`.
///
/// Every event case must be constructable and loggable without crashing.
/// `os.Logger` writes are fire-and-forget — these tests verify crash-safety
/// and that all enum branches compile and execute without throwing.
final class AnalyticsLoggerTests: XCTestCase {

    // MARK: - AnalyticsEvent Construction

    func test_appSessionStart_canBeConstructed() {
        let event = AnalyticsEvent.appSessionStart(eyeEnabled: true, postureEnabled: false, snoozeActive: false)
        _ = event
    }

    func test_appSessionEnd_canBeConstructed() {
        let event = AnalyticsEvent.appSessionEnd(sessionDurationS: 42.5)
        _ = event
    }

    func test_reminderTriggered_eyes_canBeConstructed() {
        let event = AnalyticsEvent.reminderTriggered(type: .eyes, thresholdS: 1200, deliveryPath: .screenTimeThreshold)
        _ = event
    }

    func test_reminderTriggered_posture_canBeConstructed() {
        let event = AnalyticsEvent.reminderTriggered(
            type: .posture, thresholdS: 900, deliveryPath: .notificationFallback
        )
        _ = event
    }

    func test_overlayDismissed_button_canBeConstructed() {
        let event = AnalyticsEvent.overlayDismissed(type: .eyes, method: .button, elapsedS: 15.0)
        _ = event
    }

    func test_overlayDismissed_swipe_canBeConstructed() {
        let event = AnalyticsEvent.overlayDismissed(type: .posture, method: .swipe, elapsedS: 5.0)
        _ = event
    }

    func test_overlayDismissed_settingsTap_canBeConstructed() {
        let event = AnalyticsEvent.overlayDismissed(type: .eyes, method: .settingsTap, elapsedS: 2.0)
        _ = event
    }

    func test_overlayAutoDismissed_canBeConstructed() {
        let event = AnalyticsEvent.overlayAutoDismissed(type: .eyes, durationS: 20)
        _ = event
    }

    func test_snoozeActivated_canBeConstructed() {
        let event = AnalyticsEvent.snoozeActivated(durationOption: "15m")
        _ = event
    }

    func test_snoozeExpired_canBeConstructed() {
        let event = AnalyticsEvent.snoozeExpired
        _ = event
    }

    func test_settingChanged_canBeConstructed() {
        let event = AnalyticsEvent.settingChanged(setting: .eyesInterval, oldValue: "20", newValue: "30")
        _ = event
    }

    func test_pauseActivated_canBeConstructed() {
        let event = AnalyticsEvent.pauseActivated(conditionType: "focusMode")
        _ = event
    }

    func test_pauseDeactivated_canBeConstructed() {
        let event = AnalyticsEvent.pauseDeactivated(conditionType: "all_cleared")
        _ = event
    }

    // MARK: - DismissMethod Raw Values

    func test_dismissMethod_button_rawValue() {
        XCTAssertEqual(AnalyticsEvent.DismissMethod.button.rawValue, "button")
    }

    func test_dismissMethod_swipe_rawValue() {
        XCTAssertEqual(AnalyticsEvent.DismissMethod.swipe.rawValue, "swipe")
    }

    func test_dismissMethod_settingsTap_rawValue() {
        XCTAssertEqual(AnalyticsEvent.DismissMethod.settingsTap.rawValue, "settings_tap")
    }

    // MARK: - AnalyticsLogger.log — crash-safety

    func test_log_appSessionStart_doesNotCrash() {
        AnalyticsLogger.log(.appSessionStart(eyeEnabled: true, postureEnabled: true, snoozeActive: false))
    }

    func test_log_appSessionStart_allCombinations_doNotCrash() {
        AnalyticsLogger.log(.appSessionStart(eyeEnabled: false, postureEnabled: false, snoozeActive: true))
        AnalyticsLogger.log(.appSessionStart(eyeEnabled: true, postureEnabled: false, snoozeActive: false))
        AnalyticsLogger.log(.appSessionStart(eyeEnabled: false, postureEnabled: true, snoozeActive: true))
    }

    func test_log_appSessionEnd_doesNotCrash() {
        AnalyticsLogger.log(.appSessionEnd(sessionDurationS: 0))
        AnalyticsLogger.log(.appSessionEnd(sessionDurationS: 3600))
    }

    func test_log_reminderTriggered_eyes_doesNotCrash() {
        AnalyticsLogger.log(.reminderTriggered(type: .eyes, thresholdS: 1200, deliveryPath: .screenTimeThreshold))
    }

    func test_log_reminderTriggered_posture_doesNotCrash() {
        AnalyticsLogger.log(.reminderTriggered(type: .posture, thresholdS: 900, deliveryPath: .notificationFallback))
    }

    func test_log_overlayDismissed_allMethods_doNotCrash() {
        AnalyticsLogger.log(.overlayDismissed(type: .eyes, method: .button, elapsedS: 10.0))
        AnalyticsLogger.log(.overlayDismissed(type: .posture, method: .swipe, elapsedS: 5.0))
        AnalyticsLogger.log(.overlayDismissed(type: .eyes, method: .settingsTap, elapsedS: 1.0))
    }

    func test_log_overlayAutoDismissed_doesNotCrash() {
        AnalyticsLogger.log(.overlayAutoDismissed(type: .eyes, durationS: 20))
        AnalyticsLogger.log(.overlayAutoDismissed(type: .posture, durationS: 30))
    }

    func test_log_snoozeActivated_doesNotCrash() {
        AnalyticsLogger.log(.snoozeActivated(durationOption: "5m"))
        AnalyticsLogger.log(.snoozeActivated(durationOption: "30m"))
        AnalyticsLogger.log(.snoozeActivated(durationOption: "custom"))
    }

    func test_log_snoozeExpired_doesNotCrash() {
        AnalyticsLogger.log(.snoozeExpired)
    }

    func test_log_settingChanged_doesNotCrash() {
        AnalyticsLogger.log(.settingChanged(setting: .eyesInterval, oldValue: "20", newValue: "30"))
        AnalyticsLogger.log(.settingChanged(setting: .postureEnabled, oldValue: "true", newValue: "false"))
    }

    func test_log_pauseActivated_doesNotCrash() {
        AnalyticsLogger.log(.pauseActivated(conditionType: "focusMode"))
        AnalyticsLogger.log(.pauseActivated(conditionType: "carPlay,driving"))
    }

    func test_log_pauseDeactivated_doesNotCrash() {
        AnalyticsLogger.log(.pauseDeactivated(conditionType: "all_cleared"))
    }

    func test_log_watchdogRecoveryTriggered_doesNotCrash() {
        AnalyticsLogger.log(.watchdogRecoveryTriggered(
            reason: .scheduledEyesBreak,
            detail: "watchdog_device_activity_heartbeat_stale:device_activity_interval_started"
        ))
    }

    func test_log_watchdogRecoveryCompleted_cleared_doesNotCrash() {
        AnalyticsLogger.log(.watchdogRecoveryCompleted(sessionCleared: true, fallbackScheduled: true))
    }

    func test_log_watchdogRecoveryCompleted_failed_doesNotCrash() {
        AnalyticsLogger.log(.watchdogRecoveryCompleted(sessionCleared: false, fallbackScheduled: false))
    }

    // MARK: - IPC Health

    func test_log_ipcOperationFailed_unavailable_doesNotCrash() {
        AnalyticsLogger.log(.ipcOperationFailed(operation: .readShieldSession, reason: .unavailable))
    }

    func test_log_ipcOperationFailed_corrupt_doesNotCrash() {
        AnalyticsLogger.log(.ipcOperationFailed(operation: .readEvents, reason: .corrupt))
    }

    func test_log_ipcOperationFailed_writeFailed_doesNotCrash() {
        AnalyticsLogger.log(.ipcOperationFailed(operation: .clearShieldSession, reason: .writeFailed))
    }

    func test_log_ipcOperationFailed_allOperations_doNotCrash() {
        let operations: [AnalyticsEvent.IPCOperation] = [
            .readShieldSession, .readEvents, .clearShieldSession,
            .writeEvent, .writeShieldSession, .readSelection
        ]
        for op in operations {
            AnalyticsLogger.log(.ipcOperationFailed(operation: op, reason: .unavailable))
        }
    }

    func test_log_ipcOperationFailed_allReasons_doNotCrash() {
        let reasons: [AnalyticsEvent.IPCFailureReason] = [.unavailable, .corrupt, .writeFailed, .unknown]
        for reason in reasons {
            AnalyticsLogger.log(.ipcOperationFailed(operation: .readShieldSession, reason: reason))
        }
    }

    // MARK: - Schedule Path Selection

    func test_log_schedulePathSelected_shield_doesNotCrash() {
        AnalyticsLogger.log(.schedulePathSelected(path: .shield, reason: .deviceActivityAvailable))
    }

    func test_log_schedulePathSelected_notificationFallback_allReasons_doNotCrash() {
        let reasons: [AnalyticsEvent.SchedulePathReason] = [
            .shieldUnavailable, .trueInterruptDisabled, .trueInterruptEmptySelection
        ]
        for reason in reasons {
            AnalyticsLogger.log(.schedulePathSelected(path: .notificationFallback, reason: reason))
        }
    }

    // MARK: - Shield Lifecycle

    func test_log_shieldActivated_doesNotCrash() {
        AnalyticsLogger.log(.shieldActivated(reason: .scheduledEyesBreak))
        AnalyticsLogger.log(.shieldActivated(reason: .scheduledPostureBreak))
    }

    func test_log_shieldActivationFailed_doesNotCrash() {
        AnalyticsLogger.log(.shieldActivationFailed(reason: .scheduledEyesBreak))
    }

    func test_log_shieldDeactivated_doesNotCrash() {
        AnalyticsLogger.log(.shieldDeactivated)
    }

    // MARK: - ReminderDeliveryPath

    func test_log_reminderTriggered_allDeliveryPaths_doNotCrash() {
        let paths: [AnalyticsEvent.ReminderDeliveryPath] = [
            .screenTimeThreshold, .notificationFallback
        ]
        for path in paths {
            AnalyticsLogger.log(.reminderTriggered(type: .eyes, thresholdS: 1200, deliveryPath: path))
        }
    }

    // MARK: - #446: AppLaunchReadiness crash-safety

    func test_log_appLaunchReadiness_cold_doesNotCrash() {
        AnalyticsLogger.log(.appLaunchReadiness(
            launchType: .cold,
            notificationAuth: .authorized,
            screenTimeAvailable: false,
            watchdogRecoveryNeeded: false,
            latencyS: 0.25
        ))
    }

    func test_log_appLaunchReadiness_warm_doesNotCrash() {
        AnalyticsLogger.log(.appLaunchReadiness(
            launchType: .warm,
            notificationAuth: .denied,
            screenTimeAvailable: true,
            watchdogRecoveryNeeded: true,
            latencyS: 1.50
        ))
    }

    func test_log_appLaunchReadiness_allAuthCodes_doNotCrash() {
        let codes: [AnalyticsEvent.NotificationAuthCode] = [
            .authorized, .denied, .notDetermined, .provisional, .ephemeral, .unknown
        ]
        for code in codes {
            AnalyticsLogger.log(.appLaunchReadiness(
                launchType: .cold,
                notificationAuth: code,
                screenTimeAvailable: false,
                watchdogRecoveryNeeded: false,
                latencyS: 0.1
            ))
        }
    }

    // MARK: - Repeated logging

    func test_log_calledRepeatedly_doesNotCrash() {
        for _ in 0..<20 {
            AnalyticsLogger.log(.appSessionEnd(sessionDurationS: 1.0))
        }
    }
}
