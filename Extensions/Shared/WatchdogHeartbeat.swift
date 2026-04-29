import Foundation

public protocol AppGroupIPCEventRecording {
    func recordEvent(_ event: AppGroupIPCEvent) throws
}

extension AppGroupIPCStore: AppGroupIPCEventRecording {}

public enum WatchdogHeartbeatDetail: String, CaseIterable, Sendable {
    case coordinatorInitialized = "coordinator_initialized"
    case scheduleReminders = "schedule_reminders"
    case appForeground = "app_foreground"
    case appBackground = "app_background"
    case deviceActivityIntervalStarted = "device_activity_interval_started"
    case deviceActivityIntervalEnded = "device_activity_interval_ended"
}

public enum WatchdogHeartbeat {
    public static func event(
        _ detail: WatchdogHeartbeatDetail,
        timestamp: Date = Date()
    ) -> AppGroupIPCEvent {
        AppGroupIPCEvent(
            kind: .watchdogHeartbeat,
            timestamp: timestamp,
            detail: detail.rawValue
        )
    }

    public static func record(
        _ detail: WatchdogHeartbeatDetail,
        using recorder: AppGroupIPCEventRecording
    ) throws {
        try recorder.recordEvent(event(detail))
    }
}
