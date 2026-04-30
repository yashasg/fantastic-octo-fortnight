@testable import EyePostureReminder
import ScreenTimeExtensionShared
import XCTest

/// Tests for `AnalyticsEvent` enum — validates associated values, exhaustiveness,
/// and the `DismissMethod` nested enum.
final class AnalyticsEventTests: XCTestCase {

    // MARK: - DismissMethod: Exhaustiveness

    func test_dismissMethod_allCases_areThree() {
        let all: [AnalyticsEvent.DismissMethod] = [.button, .swipe, .settingsTap]
        XCTAssertEqual(all.count, 3)
    }

    func test_dismissMethod_switchExhaustiveness() {
        let methods: [AnalyticsEvent.DismissMethod] = [.button, .swipe, .settingsTap]
        for method in methods {
            switch method {
            case .button:      XCTAssertEqual(method.rawValue, "button")
            case .swipe:       XCTAssertEqual(method.rawValue, "swipe")
            case .settingsTap: XCTAssertEqual(method.rawValue, "settings_tap")
            }
        }
    }

    // MARK: - DismissMethod: Init from rawValue

    func test_dismissMethod_initFromRawValue_button() {
        XCTAssertEqual(AnalyticsEvent.DismissMethod(rawValue: "button"), .button)
    }

    func test_dismissMethod_initFromRawValue_swipe() {
        XCTAssertEqual(AnalyticsEvent.DismissMethod(rawValue: "swipe"), .swipe)
    }

    func test_dismissMethod_initFromRawValue_settingsTap() {
        XCTAssertEqual(AnalyticsEvent.DismissMethod(rawValue: "settings_tap"), .settingsTap)
    }

    func test_dismissMethod_initFromRawValue_unknownReturnsNil() {
        XCTAssertNil(AnalyticsEvent.DismissMethod(rawValue: "unknown"))
    }

    func test_dismissMethod_initFromRawValue_emptyReturnsNil() {
        XCTAssertNil(AnalyticsEvent.DismissMethod(rawValue: ""))
    }

    // MARK: - AnalyticsEvent: Session Events

    func test_appSessionStart_allCombinations() {
        let bools: [Bool] = [true, false]
        for eye in bools {
            for posture in bools {
                for snooze in bools {
                    let event = AnalyticsEvent.appSessionStart(
                        eyeEnabled: eye, postureEnabled: posture, snoozeActive: snooze)
                    AnalyticsLogger.log(event) // crash-safety
                }
            }
        }
    }

    func test_appSessionEnd_zeroAndNegative() {
        AnalyticsLogger.log(.appSessionEnd(sessionDurationS: 0))
        AnalyticsLogger.log(.appSessionEnd(sessionDurationS: -1))
    }

    func test_appSessionEnd_veryLarge() {
        AnalyticsLogger.log(.appSessionEnd(sessionDurationS: 86400))
    }

    // MARK: - AnalyticsEvent: Reminder Events

    func test_reminderTriggered_allTypes() {
        for type in ReminderType.allCases {
            AnalyticsLogger.log(.reminderTriggered(type: type, thresholdS: 1200, deliveryPath: .screenTimeThreshold))
        }
    }

    func test_reminderTriggered_zeroThreshold() {
        AnalyticsLogger.log(.reminderTriggered(type: .eyes, thresholdS: 0, deliveryPath: .unknown))
    }

    // MARK: - AnalyticsEvent: Overlay Events

    func test_overlayDismissed_allTypesAndMethods() {
        let methods: [AnalyticsEvent.DismissMethod] = [.button, .swipe, .settingsTap]
        for type in ReminderType.allCases {
            for method in methods {
                AnalyticsLogger.log(.overlayDismissed(type: type, method: method, elapsedS: 5.0))
            }
        }
    }

    func test_overlayAutoDismissed_allTypes() {
        for type in ReminderType.allCases {
            AnalyticsLogger.log(.overlayAutoDismissed(type: type, durationS: 20))
        }
    }

    // MARK: - AnalyticsEvent: Snooze Events

    func test_snoozeCancelled_canBeLogged() {
        AnalyticsLogger.log(.snoozeCancelled)
    }

    func test_snoozeActivated_emptyString() {
        AnalyticsLogger.log(.snoozeActivated(durationOption: ""))
    }

    // MARK: - AnalyticsEvent: Settings Events

    func test_settingChanged_emptyValues() {
        AnalyticsLogger.log(.settingChanged(setting: "", oldValue: "", newValue: ""))
    }

    // MARK: - AnalyticsEvent: Pause Events

    func test_pauseActivated_emptyType() {
        AnalyticsLogger.log(.pauseActivated(conditionType: ""))
    }

    func test_pauseDeactivated_emptyType() {
        AnalyticsLogger.log(.pauseDeactivated(conditionType: ""))
    }

    // MARK: - AnalyticsEvent: Watchdog Recovery Events

    func test_watchdogRecoveryTriggered_canBeConstructed() {
        let event = AnalyticsEvent.watchdogRecoveryTriggered(
            reason: .scheduledEyesBreak,
            detail: "watchdog_device_activity_heartbeat_missing"
        )
        _ = event
    }

    func test_watchdogRecoveryTriggered_staleDetail_canBeLogged() {
        AnalyticsLogger.log(.watchdogRecoveryTriggered(
            reason: .scheduledPostureBreak,
            detail: "watchdog_device_activity_heartbeat_stale:device_activity_interval_started"
        ))
    }

    func test_watchdogRecoveryTriggered_missingDetail_canBeLogged() {
        AnalyticsLogger.log(.watchdogRecoveryTriggered(
            reason: .scheduledEyesBreak,
            detail: "watchdog_device_activity_heartbeat_missing"
        ))
    }

    func test_watchdogRecoveryTriggered_nilReason_canBeLogged() {
        AnalyticsLogger.log(.watchdogRecoveryTriggered(
            reason: nil,
            detail: "watchdog_device_activity_heartbeat_missing"
        ))
    }

    func test_watchdogRecoveryCompleted_allCombinations() {
        AnalyticsLogger.log(.watchdogRecoveryCompleted(sessionCleared: true, fallbackScheduled: true))
        AnalyticsLogger.log(.watchdogRecoveryCompleted(sessionCleared: true, fallbackScheduled: false))
        AnalyticsLogger.log(.watchdogRecoveryCompleted(sessionCleared: false, fallbackScheduled: false))
        AnalyticsLogger.log(.watchdogRecoveryCompleted(sessionCleared: false, fallbackScheduled: true))
    }

    // MARK: - AnalyticsEvent: IPC Health

    func test_ipcOperationFailed_canBeConstructed() {
        let event = AnalyticsEvent.ipcOperationFailed(operation: .readShieldSession, reason: .unavailable)
        _ = event
    }

    func test_ipcOperation_rawValues() {
        XCTAssertEqual(AnalyticsEvent.IPCOperation.readShieldSession.rawValue, "read_shield_session")
        XCTAssertEqual(AnalyticsEvent.IPCOperation.readEvents.rawValue, "read_events")
        XCTAssertEqual(AnalyticsEvent.IPCOperation.clearShieldSession.rawValue, "clear_shield_session")
        XCTAssertEqual(AnalyticsEvent.IPCOperation.writeEvent.rawValue, "write_event")
        XCTAssertEqual(AnalyticsEvent.IPCOperation.writeShieldSession.rawValue, "write_shield_session")
        XCTAssertEqual(AnalyticsEvent.IPCOperation.readSelection.rawValue, "read_selection")
    }

    func test_ipcFailureReason_rawValues() {
        XCTAssertEqual(AnalyticsEvent.IPCFailureReason.unavailable.rawValue, "unavailable")
        XCTAssertEqual(AnalyticsEvent.IPCFailureReason.corrupt.rawValue, "corrupt")
        XCTAssertEqual(AnalyticsEvent.IPCFailureReason.writeFailed.rawValue, "write_failed")
        XCTAssertEqual(AnalyticsEvent.IPCFailureReason.unknown.rawValue, "unknown")
    }

    func test_ipcOperationFailed_allCombinations_doNotCrash() {
        let operations: [AnalyticsEvent.IPCOperation] = [
            .readShieldSession, .readEvents, .clearShieldSession,
            .writeEvent, .writeShieldSession, .readSelection
        ]
        let reasons: [AnalyticsEvent.IPCFailureReason] = [.unavailable, .corrupt, .writeFailed, .unknown]
        for op in operations {
            for reason in reasons {
                AnalyticsLogger.log(.ipcOperationFailed(operation: op, reason: reason))
            }
        }
    }

    // MARK: - ReminderDeliveryPath

    func test_reminderDeliveryPath_rawValues() {
        XCTAssertEqual(AnalyticsEvent.ReminderDeliveryPath.screenTimeThreshold.rawValue, "screen_time_threshold")
        XCTAssertEqual(AnalyticsEvent.ReminderDeliveryPath.notificationFallback.rawValue, "notification_fallback")
        XCTAssertEqual(AnalyticsEvent.ReminderDeliveryPath.unknown.rawValue, "unknown")
    }

    func test_reminderTriggered_allDeliveryPaths_canBeConstructed() {
        let paths: [AnalyticsEvent.ReminderDeliveryPath] = [
            .screenTimeThreshold, .notificationFallback, .unknown
        ]
        for path in paths {
            let event = AnalyticsEvent.reminderTriggered(type: .eyes, thresholdS: 1200, deliveryPath: path)
            _ = event
        }
    }

    // MARK: - SchedulePath / SchedulePathReason

    func test_schedulePath_rawValues() {
        XCTAssertEqual(AnalyticsEvent.SchedulePath.shield.rawValue, "shield")
        XCTAssertEqual(AnalyticsEvent.SchedulePath.notificationFallback.rawValue, "notification_fallback")
    }

    func test_schedulePathReason_rawValues() {
        XCTAssertEqual(AnalyticsEvent.SchedulePathReason.deviceActivityAvailable.rawValue, "device_activity_available")
        XCTAssertEqual(AnalyticsEvent.SchedulePathReason.shieldUnavailable.rawValue, "shield_unavailable")
        XCTAssertEqual(AnalyticsEvent.SchedulePathReason.trueInterruptDisabled.rawValue, "true_interrupt_disabled")
        XCTAssertEqual(
            AnalyticsEvent.SchedulePathReason.trueInterruptEmptySelection.rawValue,
            "true_interrupt_empty_selection"
        )
    }

    func test_schedulePathSelected_allCombinations_doNotCrash() {
        let paths: [AnalyticsEvent.SchedulePath] = [.shield, .notificationFallback]
        let reasons: [AnalyticsEvent.SchedulePathReason] = [
            .deviceActivityAvailable, .shieldUnavailable,
            .trueInterruptDisabled, .trueInterruptEmptySelection
        ]
        for path in paths {
            for reason in reasons {
                AnalyticsLogger.log(.schedulePathSelected(path: path, reason: reason))
            }
        }
    }

    // MARK: - Shield Lifecycle

    func test_shieldActivated_canBeConstructed() {
        let event = AnalyticsEvent.shieldActivated(reason: .scheduledEyesBreak)
        _ = event
    }

    func test_shieldActivationFailed_canBeConstructed() {
        let event = AnalyticsEvent.shieldActivationFailed(reason: .scheduledPostureBreak)
        _ = event
    }

    func test_shieldDeactivated_canBeConstructed() {
        let event = AnalyticsEvent.shieldDeactivated
        _ = event
    }

    func test_shieldLifecycle_allCases_doNotCrash() {
        AnalyticsLogger.log(.shieldActivated(reason: .scheduledEyesBreak))
        AnalyticsLogger.log(.shieldActivated(reason: .scheduledPostureBreak))
        AnalyticsLogger.log(.shieldActivationFailed(reason: .scheduledEyesBreak))
        AnalyticsLogger.log(.shieldDeactivated)
    }
}
