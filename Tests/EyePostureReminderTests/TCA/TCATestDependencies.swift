import ComposableArchitecture
import Foundation
import UserNotifications

@testable import EyePostureReminder

/// Shared dependency-override helpers for the TCA `TestStore` test files
/// living under `Tests/EyePostureReminderTests/TCA/`.
///
/// `liveValue` factories for several Phase-1 dependency clients
/// (`NotificationClient`, `OverlayClient`, `IPCClient`, …) touch production
/// singletons that crash inside the SwiftPM xctest bundle —
/// `UNUserNotificationCenter.current()` requires a hosted app context,
/// `UIApplication.shared` cannot be reached, etc. Every reducer test in this
/// directory must therefore override **all** Phase-1 clients on the
/// `TestStore`'s `withDependencies` block, even ones that never get called by
/// the action under test, because TCA's `Scope` evaluation reaches into each
/// child reducer's body during state diffing.
///
/// The helpers below provide silent, no-op stubs sized for the AppFeature
/// scopes: `SettingsClient`, `NotificationClient`, `ReminderSchedulerClient`,
/// `OverlayClient`, `ScreenTimeTrackerClient`, `PauseConditionClient`,
/// `IPCClient`, `DeviceActivityMonitorClient`,
/// `ScreenTimeAuthorizationClient`, `AnalyticsClient`, and
/// `SessionTimingClient`.
enum TCATestDependencies {

    static func silentSettingsClient() -> SettingsClient {
        SettingsClient(
            snapshot: { ReminderSettings(interval: 0, breakDuration: 0) },
            stream: { .finished },
            postureSnapshot: { ReminderSettings(interval: 0, breakDuration: 0) },
            postureStream: { .finished },
            enabledFlagsSnapshot: { .allEnabled },
            enabledFlagsStream: { .finished },
            updateGlobalEnabled: { _ in },
            updateEyesEnabled: { _ in },
            updatePostureEnabled: { _ in },
            updateEyesInterval: { _ in },
            updatePostureInterval: { _ in },
            updateEyesBreakDuration: { _ in },
            updatePostureBreakDuration: { _ in },
            updatePauseMediaDuringBreaks: { _ in },
            updateHapticsEnabled: { _ in },
            updatePauseDuringFocus: { _ in },
            updatePauseWhileDriving: { _ in },
            updateNotificationFallbackEnabled: { _ in },
            setSnoozedUntil: { _ in },
            setSnoozeCount: { _ in },
            resetToDefaults: {}
        )
    }

    static func silentNotificationClient(
        authorizationStatus: UNAuthorizationStatus = .notDetermined
    ) -> NotificationClient {
        NotificationClient(
            requestAuthorization: { _ in false },
            authorizationStatus: { authorizationStatus },
            add: { _ in },
            removePending: { _ in },
            removeAllPending: {},
            pendingRequests: { [] },
            deliveredNotifications: { [] }
        )
    }

    static func silentReminderSchedulerClient() -> ReminderSchedulerClient {
        ReminderSchedulerClient(
            scheduleReminders: { _, _ in },
            rescheduleReminder: { _, _ in },
            cancelReminder: { _ in },
            cancelAllReminders: {}
        )
    }

    static func silentOverlayClient() -> OverlayClient {
        OverlayClient(
            show: { _, _, _, _ in },
            dismiss: {},
            clearQueue: {},
            clearQueueForType: { _ in },
            isVisible: { false },
            lifecycleEvents: { .finished }
        )
    }

    static func silentScreenTimeTrackerClient() -> ScreenTimeTrackerClient {
        ScreenTimeTrackerClient(
            setThreshold: { _, _ in },
            enableTracking: { _ in },
            disableTracking: { _ in },
            pauseAll: {},
            resumeAll: {},
            reset: { _ in },
            thresholdReached: { .finished }
        )
    }

    static func silentPauseConditionClient() -> PauseConditionClient {
        PauseConditionClient(
            isPaused: { false },
            pauseChanges: { .finished },
            startMonitoring: {},
            stopMonitoring: {}
        )
    }

    static func silentIPCClient() -> IPCClient {
        IPCClient(
            isTrueInterruptEnabled: { false },
            setTrueInterruptEnabled: { _ in false },
            readSelection: { .empty },
            writeSelection: { _ in false },
            record: { _, _ in },
            trueInterruptChanges: { .finished },
            selectionChanges: { .finished },
            recentEvents: { [] },
            fallbackRoute: { _ in nil }
        )
    }

    static func silentDeviceActivityMonitorClient() -> DeviceActivityMonitorClient {
        DeviceActivityMonitorClient(
            schedule: { _, _ in },
            cancel: { _ in },
            startScheduleForOverlay: { _ in }
        )
    }

    static func silentSessionTimingClient() -> SessionTimingClient {
        SessionTimingClient(
            sessionStarted: { _, _ in },
            sessionEnded: { _, _ in },
            launchReady: { _ in }
        )
    }

    /// Applies every silent client to the supplied `DependencyValues`. Use as
    /// the body of a `withDependencies:` trailing closure on a `TestStore`
    /// (or production `Store`) constructed for `AppFeature` so child-reducer
    /// scopes never reach into a `liveValue` that crashes the xctest bundle.
    static func applyAllSilentClients(_ dependencies: inout DependencyValues) {
        dependencies.settingsClient = silentSettingsClient()
        dependencies.notificationClient = silentNotificationClient()
        dependencies.reminderSchedulerClient = silentReminderSchedulerClient()
        dependencies.overlayClient = silentOverlayClient()
        dependencies.screenTimeTrackerClient = silentScreenTimeTrackerClient()
        dependencies.pauseConditionClient = silentPauseConditionClient()
        dependencies.ipcClient = silentIPCClient()
        dependencies.deviceActivityMonitorClient = silentDeviceActivityMonitorClient()
        dependencies.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient()
        dependencies.analyticsClient = AnalyticsClient(log: { _ in })
        dependencies.sessionTimingClient = silentSessionTimingClient()
    }
}
