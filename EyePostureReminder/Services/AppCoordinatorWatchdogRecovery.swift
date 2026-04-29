import Foundation
import os
import ScreenTimeExtensionShared

extension AppCoordinator {
    @discardableResult
    func recoverStaleDeviceActivityWatchdogIfNeeded(now: Date = Date()) async -> Bool {
        guard deviceActivityMonitor.isAvailable else { return false }

        let session: ShieldSessionSnapshot
        do {
            session = try ipcStore.readShieldSession()
        } catch {
            Logger.scheduling.error("Watchdog recovery could not read shield session: \(error.localizedDescription)")
            return false
        }
        guard session.reason != nil, let triggeredAt = session.triggeredAt else { return false }

        let staleAfter = session.durationSeconds + watchdogHeartbeatGraceInterval
        guard staleAfter.isFinite && staleAfter > 0 else { return false }

        let events: [AppGroupIPCEvent]
        do {
            events = try ipcStore.readEvents()
        } catch {
            Logger.scheduling.error("Watchdog recovery could not read heartbeat events: \(error.localizedDescription)")
            return false
        }

        let status = WatchdogHeartbeat.status(
            from: events,
            now: now,
            staleAfter: staleAfter,
            matching: WatchdogHeartbeatDetail.deviceActivityLifecycleDetails
        )
        let recoveryDetail: String
        switch status {
        case .fresh:
            return false
        case .missing:
            guard now.timeIntervalSince(triggeredAt) > staleAfter else { return false }
            recoveryDetail = "watchdog_device_activity_heartbeat_missing"
        case .stale(_, let detail):
            recoveryDetail = "watchdog_device_activity_heartbeat_stale:\(detail?.rawValue ?? "unknown")"
        }

        recordIPCEvent(.watchdogRecoveryTriggered, reasonRaw: session.reasonRaw, detail: recoveryDetail)
        AnalyticsLogger.log(.watchdogRecoveryTriggered(reason: session.reasonRaw ?? "unknown", detail: recoveryDetail))
        let sessionCleared = ipcStore.clearShieldSession(endedAt: now)
        if !sessionCleared {
            Logger.scheduling.error("Watchdog recovery failed to clear stale shield session")
        }
        cancelDeviceActivityMonitoring()
        var fallbackScheduled = false
        if notificationAuthStatus == .authorized,
           settings.notificationFallbackEnabled,
           let fallbackType = session.reason?.reminderType {
            await scheduler.rescheduleReminder(for: fallbackType, using: settings)
            fallbackScheduled = true
        }
        AnalyticsLogger.log(.watchdogRecoveryCompleted(
            sessionCleared: sessionCleared,
            fallbackScheduled: fallbackScheduled
        ))
        return true
    }
}
