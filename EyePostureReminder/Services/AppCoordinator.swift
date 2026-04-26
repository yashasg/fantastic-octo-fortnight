import os
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
/// **Trigger model:** Reminders fire after CONTINUOUS screen-on time (not wall-clock time).
/// `ScreenTimeTracker` increments per-type counters while the app is active and resets
/// them to zero whenever the screen turns off (`willResignActiveNotification`). When a
/// counter reaches its threshold it fires the overlay — identical to the old fallback-timer
/// callback, but now the only trigger path for both authorized and denied notification states.
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

    /// Category identifier for the one-time snooze-wake notification.
    /// `AppDelegate` checks this to route snooze-wake notifications separately
    /// from real reminder notifications.
    static let snoozeWakeCategory = "com.yashasgujjar.epr.snooze-wake"
    private static let snoozeWakeIdentifier = "com.yashasgujjar.epr.snooze-wake"

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
    private let overlayManager: OverlayPresenting

    // MARK: - Screen-Time Tracker

    /// Tracks continuous screen-on time per reminder type and fires callbacks
    /// when each type's threshold is reached. Replaces both UNNotification
    /// periodic triggers and the legacy foreground fallback timers.
    private let screenTimeTracker: ScreenTimeTracking

    // MARK: - Pause Condition Manager

    /// Aggregates Focus mode, CarPlay, and driving-activity signals. When any
    /// condition becomes active (and its corresponding setting is enabled) the
    /// screen-time tracker is paused until all conditions clear AND snooze is clear.
    private let pauseConditionManager: PauseConditionProviding

    // MARK: - Published State

    /// Current notification authorization status, refreshed on every
    /// `scheduleReminders()` call and after explicit permission requests.
    @Published var notificationAuthStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Pending Overlay

    /// When a notification-tap launches the app, `didReceive` fires before any
    /// `UIWindowScene` reaches `.foregroundActive`. We stash the overlay here
    /// and present it once `scenePhase` transitions to `.active`.
    private var pendingOverlay: (type: ReminderType, duration: TimeInterval)?

    // MARK: - Reschedule Debounce

    /// Per-type debounce tasks — cancels a pending reschedule for the same type
    /// when a newer setting change arrives within the debounce window.
    private var rescheduleDebounce: [ReminderType: Task<Void, Never>] = [:]

    // MARK: - Snooze Wake

    /// In-process wake task — cancels the snooze and reschedules reminders
    /// when the snooze period expires while the app is in the foreground.
    private var snoozeWakeTask: Task<Void, Never>?

    // MARK: - Session Timing

    /// Records the time when a reminder session starts (scheduleReminders completes successfully).
    /// Used to compute session duration for the appSessionEnd analytics event.
    private var sessionStartTime: Date?

    // MARK: - Init

    init(
        settings: SettingsStore? = nil,
        scheduler: ReminderScheduling? = nil,
        notificationCenter: NotificationScheduling = UNUserNotificationCenter.current(),
        overlayManager: OverlayPresenting? = nil,
        screenTimeTracker: ScreenTimeTracking? = nil,
        pauseConditionProvider: PauseConditionProviding? = nil
    ) {
        self.settings = settings ?? SettingsStore()
        self.scheduler = scheduler ?? ReminderScheduler()
        self.notificationCenter = notificationCenter
        self.overlayManager = overlayManager ?? OverlayManager()
        self.screenTimeTracker = screenTimeTracker ?? ScreenTimeTracker()
        self.pauseConditionManager = pauseConditionProvider ?? PauseConditionManager(settings: self.settings)
        Logger.lifecycle.info("AppCoordinator initialised")

        // Wire ScreenTimeTracker callback — fires on main thread when a type's
        // continuous screen-on threshold is reached.
        self.screenTimeTracker.onThresholdReached = { [weak self] type in
            guard let self else { return }
            // New reminder cycle — reset consecutive snooze count so the user
            // gets a fresh snooze budget on every threshold fire.
            self.settings.snoozeCount = 0
            let duration = self.settings.settings(for: type).breakDuration
            let thresholdS = self.settings.settings(for: type).interval
            self.overlayManager.showOverlay(
                for: type,
                duration: duration,
                hapticsEnabled: self.settings.hapticsEnabled,
                pauseMediaEnabled: self.settings.pauseMediaDuringBreaks) {}
            AnalyticsLogger.log(.reminderTriggered(type: type, thresholdS: thresholdS))
            Logger.scheduling.info("Reminder triggered by screen-time threshold: \(type.rawValue)")
        }

        // Wire PauseConditionManager — pauses/resumes tracker when conditions change.
        // Critical invariant: only call resumeAll() if BOTH snooze is clear AND no
        // pause conditions are active.
        self.pauseConditionManager.onPauseStateChanged = { [weak self] isPaused in
            guard let self else { return }
            if isPaused {
                self.screenTimeTracker.pauseAll()
                // Dismiss any overlay that is currently on screen and drop queued ones.
                // CarPlay/driving contexts should never show a break overlay.
                if self.overlayManager.isOverlayVisible {
                    self.overlayManager.dismissOverlay()
                }
                self.overlayManager.clearQueue()
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
        self.pauseConditionManager.startMonitoring()
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
            Logger.lifecycle.error("Notification authorisation request failed: \(error.localizedDescription)")
        }
        await refreshAuthStatus()
    }

    /// Re-read the current authorisation status from the system.
    func refreshAuthStatus() async {
        notificationAuthStatus = await notificationCenter.getAuthorizationStatus()
        Logger.lifecycle.debug("Notification auth status: \(self.notificationAuthStatus.rawValue)")
    }

    // MARK: - Scheduling Entrypoint

    /// Master scheduling entrypoint — configures the `ScreenTimeTracker` with
    /// current settings so reminders fire after continuous screen-on time.
    ///
    /// **Trigger model:** Reminders are no longer driven by fixed-interval
    /// `UNNotification` repeats or wall-clock `Timer`s. Instead, `ScreenTimeTracker`
    /// increments per-type counters each second the app is active and fires the
    /// overlay callback when a counter reaches its threshold. The counter resets
    /// to zero whenever the screen turns off, enforcing the "continuous screen-on
    /// time" contract.
    ///
    /// **P1-1 Snooze guard:** If a snooze is active, the tracker is paused and
    /// a wake-up task (in-process Task + silent UNNotification) is armed at
    /// `snoozeEnd`. Expired snoozes are cleared before normal configuration.
    ///
    /// Call on launch (`.task`) and whenever settings change.
    func scheduleReminders() async {
        await refreshAuthStatus()

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
                Logger.scheduling.info("Snooze active until \(snoozeEnd) — screen-time tracker paused")
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
        if notificationAuthStatus == .notDetermined {
            await requestNotificationPermission()
        }

        // Cancel any legacy periodic UNNotifications (safety net after app update).
        // Reminders are now driven exclusively by ScreenTimeTracker.
        scheduler.cancelAllReminders()

        // Configure ScreenTimeTracker with current thresholds and start counting.
        configureScreenTimeTracker()
        // #71: Only fire appSessionStart once per real session — guard against
        // re-entry from snooze-cancel or snooze-wake paths that call scheduleReminders()
        // while a session is already in progress.
        if sessionStartTime == nil {
            sessionStartTime = Date()
            AnalyticsLogger.log(.appSessionStart(
                eyeEnabled: settings.isEnabled(for: .eyes),
                postureEnabled: settings.isEnabled(for: .posture),
                snoozeActive: settings.snoozedUntil.map { $0 > Date() } ?? false
            ))
        }
        Logger.scheduling.info("ScreenTimeTracker configured — reminders fire after continuous screen-on time")
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

        let duration = settings.settings(for: type).breakDuration

        let hasActiveScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .contains { $0.activationState == .foregroundActive }

        if hasActiveScene {
            overlayManager.showOverlay(
                for: type,
                duration: duration,
                hapticsEnabled: settings.hapticsEnabled,
                pauseMediaEnabled: settings.pauseMediaDuringBreaks) {}
        } else {
            pendingOverlay = (type: type, duration: duration)
            Logger.lifecycle.info("Queued pending overlay for \(type.rawValue) (no active scene)")
        }
    }

    /// Present any queued overlay. Called by `EyePostureReminderApp` when
    /// `scenePhase` becomes `.active`.
    func presentPendingOverlayIfNeeded() {
        guard let pending = pendingOverlay else { return }
        pendingOverlay = nil
        Logger.lifecycle.info("Presenting queued overlay for \(pending.type.rawValue)")
        overlayManager.showOverlay(
            for: pending.type,
            duration: pending.duration,
            hapticsEnabled: settings.hapticsEnabled,
            pauseMediaEnabled: settings.pauseMediaDuringBreaks) {}
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
        await refreshAuthStatus()

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
                Logger.scheduling.info("Foreground transition: snooze still active until \(snoozeEnd)")
            }
            return
        }

        // ScreenTimeTracker starts via didBecomeActiveNotification automatically.
        // #65: Record session start so appSessionEnd can compute duration correctly
        // on subsequent foreground returns (scheduleReminders is not re-called here).
        if sessionStartTime == nil {
            sessionStartTime = Date()
            AnalyticsLogger.log(.appSessionStart(
                eyeEnabled: settings.isEnabled(for: .eyes),
                postureEnabled: settings.isEnabled(for: .posture),
                snoozeActive: settings.snoozedUntil.map { $0 > Date() } ?? false
            ))
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
        Logger.lifecycle.debug("App resigned active — ScreenTimeTracker will auto-reset elapsed counters")
    }

    // MARK: - Fallback Timer Shims (backward compatibility)

    /// Configure the `ScreenTimeTracker` with current settings and start counting.
    ///
    /// Retained for call-site compatibility. The "fallback timer" concept is
    /// superseded by `ScreenTimeTracker` which handles both notification-authorized
    /// and notification-denied paths uniformly.
    func startFallbackTimers() {
        configureScreenTimeTracker()
    }

    /// Stop the `ScreenTimeTracker` and reset all elapsed counters.
    ///
    /// Retained for call-site compatibility (e.g., test `tearDown`).
    func stopFallbackTimers() {
        screenTimeTracker.stopMonitoring()
    }

    // MARK: - Snooze Wake (Private)

    /// Schedule an in-process `Task` that wakes and resumes reminders when the
    /// snooze period expires. Safe to call multiple times — cancels the previous task first.
    private func scheduleSnoozeWakeTask(at date: Date) {
        snoozeWakeTask?.cancel()
        snoozeWakeTask = Task { [weak self] in
            let interval = max(0, date.timeIntervalSinceNow)
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.handleSnoozeWake()
        }
        Logger.scheduling.debug("Snooze wake task armed for \(date)")
    }

    /// Cancel the in-process snooze wake task without removing the pending
    /// notification. Called by `AppDelegate` when the snooze-wake notification
    /// is delivered while the app is in the foreground, so the task and the
    /// notification delivery path don't both call `handleSnoozeWake()` and
    /// double-fire `.snoozeExpired` analytics + double-reschedule.
    func cancelSnoozeWakeTaskIfNeeded() {
        snoozeWakeTask?.cancel()
        snoozeWakeTask = nil
    }

    /// Cancel both the in-process wake task and the one-time wake notification.
    private func cancelSnoozeWake() {
        snoozeWakeTask?.cancel()
        snoozeWakeTask = nil
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [Self.snoozeWakeIdentifier]
        )
    }

    /// Schedule a silent one-time UNNotification that fires when the snooze
    /// period expires. Wakes the app even if it was killed and relaunched.
    private func scheduleSnoozeWakeNotification(at date: Date) async {
        let interval = max(1, date.timeIntervalSinceNow)

        let content = UNMutableNotificationContent()
        // Truly silent wake notification — no banner, no sound, no badge.
        // iOS 15+ .passive level suppresses lock-screen display and sound entirely.
        content.title              = ""
        content.body               = ""
        content.sound              = nil
        content.badge              = nil
        if #available(iOS 15, *) {
            content.interruptionLevel = .passive
        }
        content.categoryIdentifier = Self.snoozeWakeCategory

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.snoozeWakeIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            Logger.scheduling.debug("Snooze wake notification scheduled in \(interval)s")
        } catch {
            Logger.scheduling.error("Failed to schedule snooze wake notification: \(error.localizedDescription)")
        }
    }

    /// Called when the snooze period expires (either via Task or notification tap).
    /// Clears snooze state and resumes normal scheduling.
    private func handleSnoozeWake() async {
        settings.snoozedUntil = nil
        settings.snoozeCount  = 0
        AnalyticsLogger.log(.snoozeExpired)
        await scheduleReminders()
        Logger.scheduling.info("Snooze wake — reminders resumed")
    }

    // MARK: - Private

    /// Update the ScreenTimeTracker threshold for a single type after the
    /// debounce window has elapsed.
    private func performReschedule(for type: ReminderType) async {
        // #74: Skip tracker restart when snooze is active — settings changes
        // during a snooze must not override the explicit pauseAll() applied at snooze start.
        guard (settings.snoozedUntil ?? .distantPast) <= Date() else {
            Logger.scheduling.debug("performReschedule skipped — snooze still active")
            return
        }
        await refreshAuthStatus()

        if settings.isEnabled(for: type) {
            let interval = settings.settings(for: type).interval
            screenTimeTracker.setThreshold(interval, for: type)
            screenTimeTracker.startMonitoring()
            Logger.scheduling.info("Rescheduled \(type.rawValue): screen-time threshold → \(interval)s")
        } else {
            screenTimeTracker.disableTracking(for: type)
            Logger.scheduling.info("Rescheduled \(type.rawValue): disabled, tracking cleared")
        }

        // Cancel any pending UNNotification for this type (safety net from legacy system).
        scheduler.cancelReminder(for: type)
    }

    /// Configure all `ScreenTimeTracker` thresholds from current settings
    /// and start counting if the app is active.
    ///
    /// Called from `scheduleReminders()` after the snooze guard clears.
    /// Only calls `resumeAll()` if no pause condition is currently active —
    /// preserves the invariant that PauseConditionManager and snooze are
    /// independent pause axes.
    private func configureScreenTimeTracker() {
        for type in ReminderType.allCases {
            if settings.isEnabled(for: type) {
                let interval = settings.settings(for: type).interval
                screenTimeTracker.setThreshold(interval, for: type)
            } else {
                screenTimeTracker.disableTracking(for: type)
            }
        }
        guard !pauseConditionManager.isPaused else {
            Logger.scheduling.debug("configureScreenTimeTracker: pause condition active — skipping resumeAll")
            return
        }
        screenTimeTracker.resumeAll()
        screenTimeTracker.startMonitoring()
    }
}

// MARK: - ReminderScheduling Conformance

/// `AppCoordinator` conforms to `ReminderScheduling` so `SettingsViewModel`
/// can treat it as its scheduler. Every method routes through the
/// auth-aware coordinator paths, keeping fallback timers in sync when
/// notifications are denied.
extension AppCoordinator: ReminderScheduling {

    func scheduleReminders(using settings: SettingsStore) async {
        // Delegate to the coordinator's full auth-aware entrypoint.
        await scheduleReminders()
    }

    func rescheduleReminder(for type: ReminderType, using settings: SettingsStore) async {
        // Debounced, auth-aware single-type reschedule.
        await reschedule(for: type)
    }

    func cancelReminder(for type: ReminderType) {
        scheduler.cancelReminder(for: type)
        screenTimeTracker.disableTracking(for: type)
        overlayManager.clearQueue(for: type)
        if pendingOverlay?.type == type { pendingOverlay = nil }
    }

    func cancelAllReminders() {
        scheduler.cancelAllReminders()
        screenTimeTracker.pauseAll()
        if overlayManager.isOverlayVisible {
            overlayManager.dismissOverlay()
        }
        overlayManager.clearQueue()
        pendingOverlay = nil

        // If snooze was just applied (snoozedUntil set before this call),
        // arm the in-process wake task immediately so the app resumes on time
        // while staying in the foreground throughout the snooze period.
        // #73: Also schedule the silent background notification so a backgrounded
        // app can wake even if the in-process task is killed by the OS.
        if let snoozeEnd = settings.snoozedUntil, snoozeEnd > Date() {
            scheduleSnoozeWakeTask(at: snoozeEnd)
            if notificationAuthStatus == .authorized {
                Task { [weak self] in await self?.scheduleSnoozeWakeNotification(at: snoozeEnd) }
            }
        }
    }
}
