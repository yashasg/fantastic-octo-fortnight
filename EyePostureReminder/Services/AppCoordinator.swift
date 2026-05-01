import os
import ScreenTimeExtensionShared
import UIKit
import UserNotifications

/// Central dependency owner and app-lifecycle coordinator.
///
/// `AppCoordinator` is the **single source of truth** for shared services:
/// - `SettingsStore` (user preferences)
/// - `ReminderScheduler` (notification scheduling)
/// - `ScreenTimeTracker` (screen-on-time-based reminder trigger)
///
/// It also manages:
/// - Notification authorization state tracking
/// - Pending-overlay queue (notification-tap race condition)
/// - Snooze state: pauses the screen-time tracker during snooze and resumes automatically
///
/// **Trigger model (hybrid):** Two complementary paths fire reminders.
/// 1. **Background:** Periodic `UNNotificationRequest` (when authorized) wakes the user in
///    other apps. `AppDelegate.willPresent`/`didReceive` routes delivery to `handleNotification`.
/// 2. **Foreground:** `ScreenTimeTracker` increments per-type counters while the app is active
///    and fires the overlay callback when a counter reaches its threshold. When the foreground
///    overlay fires, the background notification is rescheduled from now so the two paths stay
///    in sync and do not double-trigger.
/// When notification permission is denied, `ScreenTimeTracker` remains the sole reminder path.
///
/// **P1-2:** Uses injected `NotificationScheduling` for all auth management
/// instead of calling `UNUserNotificationCenter.current()` directly.
///
/// **P1-3:** Uses injected `OverlayPresenting` instead of a shared singleton.
///
/// `AppCoordinator` conforms to `ReminderScheduling` so Views can pass it
/// directly to `SettingsViewModel`. The conformance routes every call through
/// the auth-aware `scheduleReminders()` / `reschedule(for:)` paths, ensuring
/// the screen-time tracker stays in sync on every settings change.
///
/// Created once by `EyePostureReminderApp` as a `@StateObject` and injected
/// into the SwiftUI environment. `AppDelegate` receives a weak-ish reference
/// so notification callbacks can route through the coordinator.
@MainActor
final class AppCoordinator: ObservableObject {

    // MARK: - Snooze Wake Constants

    /// Shared identifier used as both the `UNNotificationRequest.identifier` and
    /// the `content.categoryIdentifier` for the one-time snooze-wake notification.
    /// `AppDelegate` checks this to route snooze-wake notifications separately
    /// from real reminder notifications.
    static let snoozeWakeCategory = "com.yashasgujjar.kshana.snooze-wake"

    // MARK: - Owned Dependencies

    let settings: SettingsStore
    let scheduler: ReminderScheduling

    // MARK: - Injected Dependencies (P1-2, P1-3)

    /// Injected notification center — used for auth checks and snooze-wake
    /// scheduling. Defaults to `UNUserNotificationCenter.current()` in production.
    /// `internal` (not `private`) so `OnboardingView` can pass it to
    /// `OnboardingPermissionView` for DI-friendly onboarding permission requests.
    let notificationCenter: NotificationScheduling

    /// Injected overlay manager — used to show overlays and clear the queue.
    /// Defaults to a fresh `OverlayManager()` in production.
    let overlayManager: OverlayPresenting

    // MARK: - Screen-Time Authorization

    /// Manages FamilyControls authorization for True Interrupt Mode.
    /// Defaults to `ScreenTimeAuthorizationNoop` until the entitlement from #201
    /// is provisioned. Exposed so the Settings and onboarding UI can observe status.
    let screenTimeAuthorization: ScreenTimeAuthorizationProviding

    // MARK: - DeviceActivity Monitor

    /// Schedules and cancels OS-level DeviceActivity monitoring windows for break sessions.
    /// Defaults to `DeviceActivityMonitorNoop` until the FamilyControls entitlement (#201)
    /// is provisioned and the user has granted authorization.
    let deviceActivityMonitor: DeviceActivityMonitorProviding

    /// Records shield/notification routing events into the App Group container so
    /// app extensions and watchdog diagnostics can observe the selected path.
    let ipcStore: AppGroupIPCProviding
    private var trueInterruptEnabledObserver: NSObjectProtocol?
    let watchdogHeartbeatGraceInterval: TimeInterval

    // MARK: - Screen-Time Tracker

    /// Tracks continuous screen-on time per reminder type and fires callbacks
    /// when each type's threshold is reached. Replaces both UNNotification
    /// periodic triggers and the legacy foreground fallback timers.
    let screenTimeTracker: ScreenTimeTracking

    // MARK: - Pause Condition Manager

    /// Aggregates Focus mode, CarPlay, and driving-activity signals. When any
    /// condition becomes active (and its corresponding setting is enabled) the
    /// screen-time tracker is paused until all conditions clear AND snooze is clear.
    let pauseConditionManager: PauseConditionProviding

    // MARK: - Published State

    /// Current notification authorization status, refreshed on every
    /// `scheduleReminders()` call and after explicit permission requests.
    @Published var notificationAuthStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Pending Overlay

    /// A stashed overlay request awaiting an active scene.
    struct PendingOverlay {
        let type: ReminderType
        let duration: TimeInterval
    }

    enum DeviceActivityMonitorOperation: Sendable {
        case schedule(ShieldSession, presentationID: UUID)
        case cancel(presentationID: UUID?)

        var logDescription: String {
            switch self {
            case .schedule(let session, _):
                "schedule \(session.reason.rawValue)"
            case .cancel:
                "cancel"
            }
        }
    }

    /// When a notification-tap launches the app, `didReceive` fires before any
    /// `UIWindowScene` reaches `.foregroundActive`. We stash the overlay here
    /// and present it once `scenePhase` transitions to `.active`.
    var pendingOverlay: PendingOverlay?

    // MARK: - Reschedule Debounce

    /// Per-type debounce tasks — cancels a pending reschedule for the same type
    /// when a newer setting change arrives within the debounce window.
    private var rescheduleDebounce: [ReminderType: Task<Void, Never>] = [:]

    // MARK: - Snooze Wake

    /// In-process wake task — cancels the snooze and reschedules reminders
    /// when the snooze period expires while the app is in the foreground.
    var snoozeWakeTask: Task<Void, Never>?

    /// Serializes DeviceActivity start/cancel operations so a fast dismiss cannot
    /// race an in-flight schedule call and leave OS-level monitoring active.
    var deviceActivityMonitorTask: Task<Void, Never>?
    var dismissedDeviceActivityPresentationIDs: Set<UUID> = []

    // MARK: - Session Timing

    /// Records the time when a reminder session starts (scheduleReminders completes successfully).
    /// Used to compute session duration for the appSessionEnd analytics event.
    private var sessionStartTime: Date?

    // MARK: - Launch Readiness Tracking (#446)

    /// Records the time when the app entered the foreground (cold or warm).
    /// Set at the top of `handleForegroundTransition()` for warm launches and lazily
    /// at the start of `scheduleReminders()` for cold launches. Reset after the
    /// `appLaunchReadiness` event is emitted so each cycle is measured independently.
    private var foregroundEntryTime: Date?

    /// Whether the current launch/foreground cycle is cold (first scheduleReminders call)
    /// or warm (foreground return via handleForegroundTransition).
    private var pendingLaunchType: AnalyticsEvent.LaunchType = .cold

    /// Whether `recoverStaleDeviceActivityWatchdogIfNeeded()` triggered recovery
    /// during the most recent `handleForegroundTransition()`.
    private var watchdogRecoveryNeededAtForeground = false

    // MARK: - Init

    init(
        settings: SettingsStore? = nil,
        scheduler: ReminderScheduling? = nil,
        notificationCenter: NotificationScheduling = UNUserNotificationCenter.current(),
        overlayManager: OverlayPresenting? = nil,
        screenTimeTracker: ScreenTimeTracking? = nil,
        pauseConditionProvider: PauseConditionProviding? = nil,
        screenTimeAuthorization: ScreenTimeAuthorizationProviding? = nil,
        deviceActivityMonitor: DeviceActivityMonitorProviding? = nil,
        ipcStore: AppGroupIPCProviding = AppGroupIPCStore(),
        watchdogHeartbeatGraceInterval: TimeInterval = 10
    ) {
        precondition(
            watchdogHeartbeatGraceInterval.isFinite && watchdogHeartbeatGraceInterval >= 0,
            "Watchdog heartbeat grace interval must be finite and non-negative"
        )
        self.settings = Self.resolveSettings(settings)
        self.scheduler = Self.resolveScheduler(scheduler)
        self.notificationCenter = notificationCenter
        self.overlayManager = Self.resolveOverlayManager(overlayManager)
        self.screenTimeAuthorization = Self.resolveScreenTimeAuthorization(screenTimeAuthorization)
        self.deviceActivityMonitor = Self.resolveDeviceActivityMonitor(deviceActivityMonitor)
        self.ipcStore = ipcStore
        self.watchdogHeartbeatGraceInterval = watchdogHeartbeatGraceInterval
        // In UI test mode, use no-op stubs for services that register UIKit lifecycle
        // observers and start 1-second timers — they prevent XCUITest from settling
        // the accessibility tree between interactions, causing stale element reads.
        self.screenTimeTracker = Self.resolveScreenTimeTracker(screenTimeTracker)
        self.pauseConditionManager = Self.resolvePauseConditionManager(
            pauseConditionProvider,
            settings: self.settings
        )
        Logger.lifecycle.info("AppCoordinator initialised")
        recordWatchdogHeartbeat(.coordinatorInitialized)

        // Wire ScreenTimeTracker callback — fires on main thread when a type's
        // continuous screen-on threshold is reached.
        self.screenTimeTracker.onThresholdReached = { [weak self] type in
            MainActor.assumeIsolated {
                guard let self else { return }
                // #407: Guard against the 300 ms per-type disable debounce window.
                // If the user just toggled this type off, `disableTracking(for:)` is
                // still in-flight; the tracker can still fire the callback before it
                // is cancelled. Skip entirely so no overlay appears and snoozeCount
                // is not reset for a reminder type the user disabled.
                guard self.settings.isEnabled(for: type) else { return }
                // New reminder cycle — reset consecutive snooze count so the user
                // gets a fresh snooze budget on every threshold fire.
                self.settings.snoozeCount = 0
                let duration = self.settings.settings(for: type).breakDuration
                let thresholdS = self.settings.settings(for: type).interval
                self.showBreakOverlay(for: type, duration: duration)
                AnalyticsLogger.log(.reminderTriggered(
                    type: type, thresholdS: thresholdS, deliveryPath: .screenTimeThreshold
                ))
                Logger.scheduling.info("Reminder triggered by screen-time threshold: \(type.rawValue)")
                // Reschedule the background notification from now so its interval restarts
                // at the same moment the foreground overlay fires, preventing a near-
                // simultaneous double-trigger when the user returns to another app.
                if self.notificationAuthStatus == .authorized, self.shouldScheduleNotificationFallback {
                    Task { [weak self] in
                        guard let self else { return }
                        await self.scheduler.rescheduleReminder(for: type, using: self.settings)
                    }
                }
            }
        }

        // Wire PauseConditionManager — pauses/resumes tracker when conditions change.
        // Critical invariant: only call resumeAll() if BOTH snooze is clear AND no
        // pause conditions are active.
        self.pauseConditionManager.onPauseStateChanged = { [weak self] isPaused in
            MainActor.assumeIsolated {
                guard let self else { return }
                if isPaused {
                    self.screenTimeTracker.pauseAll()
                    // Dismiss any overlay that is currently on screen and drop queued ones.
                    // CarPlay/driving contexts should never show a break overlay.
                    self.overlayManager.clearQueue()
                    if self.overlayManager.isOverlayVisible {
                        self.overlayManager.dismissOverlay()
                    }
                    self.pendingOverlay = nil
                    Logger.scheduling.info("PauseConditionManager: pausing reminders (active condition)")
                } else {
                    guard (self.settings.snoozedUntil ?? .distantPast) <= Date() else {
                        Logger.scheduling.debug(
                            "PauseConditionManager: pause cleared but snooze still active — not resuming")
                        return
                    }
                    self.screenTimeTracker.resumeAll()
                    Logger.scheduling.info("PauseConditionManager: resuming reminders (no active conditions)")
                }
            }
        }
        self.pauseConditionManager.startMonitoring()
        self.trueInterruptEnabledObserver = NotificationCenter.default.addObserver(
            forName: AppGroupIPCStore.trueInterruptEnabledDidChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.scheduleReminders()
            }
        }
    }

    deinit {
        rescheduleDebounce.values.forEach { $0.cancel() }
        snoozeWakeTask?.cancel()
        deviceActivityMonitorTask?.cancel()
        if let trueInterruptEnabledObserver {
            NotificationCenter.default.removeObserver(trueInterruptEnabledObserver)
        }
    }

    // MARK: - Notification Permission

    /// Request notification permission from the user.
    ///
    /// Safe to call multiple times — the system prompt only appears once.
    /// After the request completes (granted or denied) `notificationAuthStatus`
    /// is refreshed automatically.
    func requestNotificationPermission() async {
        do {
            let granted = try await notificationCenter
                .requestAuthorization(options: [.alert, .sound, .badge])
            Logger.lifecycle.info("Notification authorisation \(granted ? "granted" : "denied")")
        } catch {
            // swiftlint:disable:next line_length
            Logger.lifecycle.error("Notification authorisation request failed: \(error.localizedDescription, privacy: .public)")
        }
        await refreshAuthStatus()
    }

    /// Re-read the current authorisation status from the system.
    func refreshAuthStatus() async {
        // Skip the system async call in UI test mode — it suspends the main actor,
        // which can prevent a Toggle binding update from executing before XCUITest
        // reads the element's accessibility value immediately after tap().
        guard !AppCoordinator.isUITestMode else { return }
        notificationAuthStatus = await notificationCenter.getAuthorizationStatus()
        Logger.lifecycle.debug("Notification auth status: \(self.notificationAuthStatus.rawValue)")
    }

    // MARK: - Scheduling Entrypoint

    /// Master scheduling entrypoint — configures the `ScreenTimeTracker` with
    /// current settings and, when notification permission is authorized, schedules
    /// periodic `UNNotificationRequest`s for background delivery.
    ///
    /// **Hybrid trigger model:**
    /// - `UNNotificationRequest` (repeating, ≥ 60 s interval): fires reminders while the
    ///   user is in other apps. Requires notification permission.
    /// - `ScreenTimeTracker`: foreground precision supplement — fires the in-app overlay
    ///   after continuous screen-on time. When it fires it reschedules the matching
    ///   background notification so the two paths stay synchronized.
    ///
    /// **P1-1 Snooze guard:** If a snooze is active, the tracker is paused and
    /// a wake-up task (in-process Task + silent UNNotification) is armed at
    /// `snoozeEnd`. Expired snoozes are cleared before normal configuration.
    ///
    /// Call on launch (`.task`) and whenever settings change.
    func scheduleReminders() async {
        await refreshAuthStatus()
        recordWatchdogHeartbeat(.scheduleReminders)

        // Cold-launch proxy: handleForegroundTransition() sets this for warm paths.
        // For true cold launch (EyePostureReminderApp .task), capture the time here.
        if foregroundEntryTime == nil {
            foregroundEntryTime = Date()
        }

        // P1-1: Snooze guard — check before doing anything else.
        if let snoozeEnd = settings.snoozedUntil {
            if snoozeEnd > Date() {
                // Snooze still active — pause screen-time tracking and arm wake.
                screenTimeTracker.pauseAll()
                scheduler.cancelAllReminders()
                scheduleSnoozeWakeTask(at: snoozeEnd)
                if notificationAuthStatus == .authorized {
                    await scheduleSnoozeWakeNotification(at: snoozeEnd)
                }
                // swiftlint:disable:next line_length
                Logger.scheduling.info("Snooze active — screen-time tracker paused; expires in \(snoozeEnd.timeIntervalSinceNow, format: .fixed(precision: 0), privacy: .public)s")
                return
            } else {
                // Snooze has expired — clear state and fall through to normal scheduling.
                settings.snoozedUntil = nil
                settings.snoozeCount  = 0
                AnalyticsLogger.log(.snoozeExpired)
                Logger.scheduling.info("Snooze expired — clearing and resuming normal scheduling")
            }
        }

        // No active snooze — cancel any pending wake artifacts.
        cancelSnoozeWake()

        // First launch: prompt the user for notification permission.
        // Permission is still used for the snooze-wake silent notification.
        // Skip in UI test mode — the system alert would block the accessibility
        // hierarchy and cause all XCUITest element lookups to fail.
        if notificationAuthStatus == .notDetermined && !AppCoordinator.isUITestMode {
            await requestNotificationPermission()
        }

        // Schedule periodic background UNNotifications only as the fallback path
        // while Screen Time shielding is unavailable.
        if notificationAuthStatus == .authorized, shouldScheduleNotificationFallback {
            // Capture before await — IPC state may change across the suspension point.
            let (fallbackDetail, analyticsReason) = fallbackRoutingContext()
            await scheduler.scheduleReminders(using: settings)
            recordIPCEvent(
                .notificationFallbackScheduled,
                detail: fallbackDetail
            )
            AnalyticsLogger.log(.schedulePathSelected(path: .notificationFallback, reason: analyticsReason))
        } else {
            scheduler.cancelAllReminders()
            if shouldUseShieldPath {
                recordIPCEvent(.shieldPathSelected, detail: "device_activity_available")
                AnalyticsLogger.log(.schedulePathSelected(path: .shield, reason: .deviceActivityAvailable))
            }
        }

        // Skip the 1-second tick timer in UI test mode — continuous main-thread
        // activity prevents XCUITest from settling the accessibility tree between
        // interactions, causing stale value reads on Toggles and other controls.
        guard !AppCoordinator.isUITestMode else { return }

        // Configure ScreenTimeTracker with current thresholds and start counting.
        configureScreenTimeTracker()
        // #71: Only fire appSessionStart once per real session — guard against
        // re-entry from snooze-cancel or snooze-wake paths that call scheduleReminders()
        // while a session is already in progress.
        if sessionStartTime == nil {
            sessionStartTime = Date()
            let latency = foregroundEntryTime.map { Date().timeIntervalSince($0) } ?? 0
            AnalyticsLogger.log(.appLaunchReadiness(.init(
                launchType: pendingLaunchType,
                notificationAuth: notificationAuthCode(from: notificationAuthStatus),
                screenTimeAvailable: screenTimeAuthorization.authorizationStatus == .approved,
                watchdogRecoveryNeeded: watchdogRecoveryNeededAtForeground,
                latencyS: max(0, latency)
            )))
            AnalyticsLogger.log(.appSessionStart(
                eyeEnabled: settings.isEnabled(for: .eyes),
                postureEnabled: settings.isEnabled(for: .posture),
                snoozeActive: settings.snoozedUntil.map { $0 > Date() } ?? false
            ))
            foregroundEntryTime = nil
            pendingLaunchType = .cold
            watchdogRecoveryNeededAtForeground = false
        }
        Logger.scheduling.info("Hybrid scheduling configured — background notifications + foreground screen-time tracker active")
    }

    // MARK: - Per-Type Auth-Aware Reschedule

    /// Reschedule a single reminder type after a settings change.
    ///
    /// Updates the `ScreenTimeTracker` threshold for the type. If the type is
    /// disabled the tracker counter is cleared and no callback will fire.
    ///
    /// Calls are debounced per-type (300 ms) so rapid slider/picker changes
    /// don't thrash the tracker on every value change.
    func reschedule(for type: ReminderType) async {
        rescheduleDebounce[type]?.cancel()
        let task = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
            guard let self, !Task.isCancelled else { return }
            await self.performReschedule(for: type)
        }
        rescheduleDebounce[type] = task
    }

    // MARK: - Notification Handling

    /// Unified handler for both foreground delivery (`willPresent`) and
    /// background-tap delivery (`didReceive`).
    ///
    /// Resets the consecutive snooze count since a real reminder has fired.
    /// Reads the break duration from `SettingsStore` instead of hardcoding.
    /// If no window scene is active yet (notification-tap race), the overlay is
    /// queued and presented when `presentPendingOverlayIfNeeded()` is called.
    func handleNotification(for type: ReminderType) {
        // A real reminder fired — reset consecutive snooze count.
        settings.snoozeCount = 0
        recordIPCEvent(.notificationFallbackDelivered, reasonRaw: type.shieldReason.rawValue)
        AnalyticsLogger.log(.reminderTriggered(
            type: type,
            thresholdS: settings.settings(for: type).interval,
            deliveryPath: .notificationFallback
        ))

        let duration = settings.settings(for: type).breakDuration

        let hasActiveScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .contains { $0.activationState == .foregroundActive }

        if hasActiveScene {
            showBreakOverlay(for: type, duration: duration)
        } else {
            pendingOverlay = PendingOverlay(type: type, duration: duration)
            Logger.lifecycle.info("Queued pending overlay for \(type.rawValue) (no active scene)")
        }

        // Reset the in-app elapsed counter so the foreground tracker doesn't fire
        // an additional overlay immediately after this notification-triggered one.
        screenTimeTracker.reset(for: type)
    }

    /// Present any queued overlay. Called by `EyePostureReminderApp` when
    /// `scenePhase` becomes `.active`.
    func presentPendingOverlayIfNeeded() {
        guard let pending = pendingOverlay else { return }
        pendingOverlay = nil
        Logger.lifecycle.info("Presenting queued overlay for \(pending.type.rawValue)")
        showBreakOverlay(for: pending.type, duration: pending.duration)
    }

    // MARK: - App Lifecycle Hooks

    /// Clears `snoozedUntil` if it has already passed.
    ///
    /// Called by `AppDelegate.applicationDidBecomeActive` so that a stale
    /// `snoozedUntil` (left by a swiped-away snooze-wake notification on a
    /// killed app) is cleaned up before `scheduleReminders()` runs.
    func clearExpiredSnoozeIfNeeded() async {
        guard let snoozeEnd = settings.snoozedUntil, snoozeEnd <= Date() else { return }
        settings.snoozedUntil = nil
        settings.snoozeCount  = 0
        AnalyticsLogger.log(.snoozeExpired)
        Logger.scheduling.info("clearExpiredSnoozeIfNeeded: stale snoozedUntil cleared")
    }

    /// Called when the app returns to the foreground from background.
    ///
    /// Clears any expired snooze and re-arms the wake task if snooze is still
    /// active. `ScreenTimeTracker` starts counting automatically via
    /// `UIApplication.didBecomeActiveNotification` — no explicit timer
    /// restart is required here.
    func handleForegroundTransition() async {
        foregroundEntryTime = Date()
        pendingLaunchType = .warm
        await refreshAuthStatus()
        let recoveryNeeded = await recoverStaleDeviceActivityWatchdogIfNeeded()
        watchdogRecoveryNeededAtForeground = recoveryNeeded
        recordWatchdogHeartbeat(.appForeground)

        // P1-1: Handle snooze state on foreground.
        if let snoozeEnd = settings.snoozedUntil {
            if snoozeEnd <= Date() {
                // Snooze expired while backgrounded — clear and reschedule.
                settings.snoozedUntil = nil
                settings.snoozeCount  = 0
                AnalyticsLogger.log(.snoozeExpired)
                Logger.scheduling.info("Foreground transition: snooze expired — resuming normal scheduling")
                await scheduleReminders()
            } else {
                // Snooze still active — re-arm wake task and notification in case
                // they were lost while the app was backgrounded (#73).
                scheduleSnoozeWakeTask(at: snoozeEnd)
                if notificationAuthStatus == .authorized {
                    await scheduleSnoozeWakeNotification(at: snoozeEnd)
                }
                // swiftlint:disable:next line_length
                Logger.scheduling.info("Foreground transition: snooze still active; expires in \(snoozeEnd.timeIntervalSinceNow, format: .fixed(precision: 0), privacy: .public)s")
            }
            return
        }

        // ScreenTimeTracker starts via didBecomeActiveNotification automatically.
        // #65: Record session start so appSessionEnd can compute duration correctly
        // on subsequent foreground returns (scheduleReminders is not re-called here).
        if sessionStartTime == nil {
            sessionStartTime = Date()
            let latency = foregroundEntryTime.map { Date().timeIntervalSince($0) } ?? 0
            AnalyticsLogger.log(.appLaunchReadiness(.init(
                launchType: pendingLaunchType,
                notificationAuth: notificationAuthCode(from: notificationAuthStatus),
                screenTimeAvailable: screenTimeAuthorization.authorizationStatus == .approved,
                watchdogRecoveryNeeded: watchdogRecoveryNeededAtForeground,
                latencyS: max(0, latency)
            )))
            AnalyticsLogger.log(.appSessionStart(
                eyeEnabled: settings.isEnabled(for: .eyes),
                postureEnabled: settings.isEnabled(for: .posture),
                snoozeActive: settings.snoozedUntil.map { $0 > Date() } ?? false
            ))
            foregroundEntryTime = nil
            pendingLaunchType = .cold
            watchdogRecoveryNeededAtForeground = false
        }
        Logger.scheduling.debug("Foreground transition: ScreenTimeTracker will resume via didBecomeActive")
    }

    /// Called when the app moves to the background.
    ///
    /// `ScreenTimeTracker` resets all elapsed counters automatically via
    /// `UIApplication.willResignActiveNotification`. This method is kept as
    /// a lifecycle hook for any future foreground-only cleanup.
    func appWillResignActive() {
        // ScreenTimeTracker observes willResignActiveNotification directly and
        // resets all elapsed counters — no explicit action needed here.
        let sessionDuration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        AnalyticsLogger.log(.appSessionEnd(sessionDurationS: sessionDuration))
        sessionStartTime = nil
        recordWatchdogHeartbeat(.appBackground)
        Logger.lifecycle.debug("App resigned active — ScreenTimeTracker will auto-reset elapsed counters")
    }

}

private extension AppCoordinator {
    static func resolveSettings(_ settings: SettingsStore?) -> SettingsStore {
        settings ?? SettingsStore()
    }

    static func resolveScheduler(_ scheduler: ReminderScheduling?) -> ReminderScheduling {
        scheduler ?? ReminderScheduler()
    }

    static func resolveOverlayManager(_ overlayManager: OverlayPresenting?) -> OverlayPresenting {
        overlayManager ?? OverlayManager()
    }

    static func resolveScreenTimeAuthorization(
        _ screenTimeAuthorization: ScreenTimeAuthorizationProviding?
    ) -> ScreenTimeAuthorizationProviding {
        guard let screenTimeAuthorization else {
            #if DEBUG
            if let raw = UserDefaults.standard.string(forKey: AppStorageKey.uiTestScreenTimeStatus),
               let status = ScreenTimeAuthorizationStatus(rawValue: raw) {
                return ScreenTimeAuthorizationStub(status: status)
            }
            #endif
            return ScreenTimeAuthorizationNoop()
        }
        return screenTimeAuthorization
    }

    static func resolveDeviceActivityMonitor(
        _ deviceActivityMonitor: DeviceActivityMonitorProviding?
    ) -> DeviceActivityMonitorProviding {
        deviceActivityMonitor ?? DeviceActivityMonitorNoop()
    }

    static func resolveScreenTimeTracker(_ screenTimeTracker: ScreenTimeTracking?) -> ScreenTimeTracking {
        guard let screenTimeTracker else {
            return AppCoordinator.isUITestMode ? NoopScreenTimeTracker() : ScreenTimeTracker()
        }
        return screenTimeTracker
    }

    static func resolvePauseConditionManager(
        _ pauseConditionProvider: PauseConditionProviding?,
        settings: SettingsStore
    ) -> PauseConditionProviding {
        guard let pauseConditionProvider else {
            return AppCoordinator.isUITestMode
                ? NoopPauseConditionManager()
                : PauseConditionManager(
                    settings: settings,
                    focusDetector: LiveFocusStatusDetector(),
                    carPlayDetector: LiveCarPlayDetector(),
                    drivingDetector: LiveDrivingActivityDetector()
                )
        }
        return pauseConditionProvider
    }
}
