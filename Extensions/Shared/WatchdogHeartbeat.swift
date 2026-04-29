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

public enum WatchdogHeartbeatStatus: Equatable, Sendable {
    case missing
    case fresh(lastSeenAt: Date, detail: WatchdogHeartbeatDetail?)
    case stale(lastSeenAt: Date, detail: WatchdogHeartbeatDetail?)
}

public enum WatchdogHeartbeat {
    public typealias FailureLogger = (WatchdogHeartbeatDetail, Error) -> Void

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

    @discardableResult
    public static func record(
        _ detail: WatchdogHeartbeatDetail,
        using recorder: AppGroupIPCEventRecording,
        logFailure: FailureLogger
    ) -> Bool {
        do {
            try record(detail, using: recorder)
            return true
        } catch {
            logFailure(detail, error)
            return false
        }
    }

    public static func status(
        from events: [AppGroupIPCEvent],
        now: Date = Date(),
        staleAfter staleThreshold: TimeInterval
    ) -> WatchdogHeartbeatStatus {
        precondition(
            staleThreshold.isFinite && staleThreshold > 0,
            "Watchdog heartbeat stale threshold must be positive and finite"
        )

        guard let latest = events
            .filter({ $0.kind == .watchdogHeartbeat })
            .max(by: { $0.timestamp < $1.timestamp })
        else {
            return .missing
        }

        let detail = latest.detail.flatMap(WatchdogHeartbeatDetail.init(rawValue:))
        if now.timeIntervalSince(latest.timestamp) > staleThreshold {
            return .stale(lastSeenAt: latest.timestamp, detail: detail)
        }
        return .fresh(lastSeenAt: latest.timestamp, detail: detail)
    }
}
