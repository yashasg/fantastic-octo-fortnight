import UIKit
import UserNotifications
import os

/// Central dependency owner and app-lifecycle coordinator.
///
/// `AppCoordinator` is the **single source of truth** for shared services:
/// - `SettingsStore` (user preferences)
/// - `ReminderScheduler` (notification scheduling)
///
/// It also manages:
/// - Notification authorization state tracking
/// - Pending-overlay queue (notification-tap race condition)
/// - Foreground fallback timers (when notifications are denied)
/// - Snooze state: cancels reminders during snooze and resumes automatically
///
/// **P1-2:** Uses injected `NotificationScheduling` for all auth management
/// instead of calling `UNUserNotificationCenter.current()` directly.
///
/// **P1-3:** Uses injected `OverlayPresenting` instead of `OverlayManager.shared` directly.
///
/// `AppCoordinator` conforms to `ReminderScheduling` so Views can pass it
/// directly to `SettingsViewModel`. The conformance routes every call through
/// the auth-aware `scheduleReminders()` / `reschedule(for:)` paths, ensuring
/// fallback timers stay in sync when notifications are denied.
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
    let scheduler: ReminderScheduler

    // MARK: - Injected Dependencies (P1-2, P1-3)

    /// Injected notification center — used for auth checks and snooze-wake
    /// scheduling. Defaults to `UNUserNotificationCenter.current()` in production.
    private let notificationCenter: NotificationScheduling

    /// Injected overlay manager — used to show overlays and clear the queue.
    /// Defaults to `OverlayManager.shared` in production.
    private let overlayManager: OverlayPresenting

    // MARK: - Published State

    /// Current notification authorization status, refreshed on every
    /// `scheduleReminders()` call and after explicit permission requests.
    @Published var notificationAuthStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Pending Overlay

    /// When a notification-tap launches the app, `didReceive` fires before any
    /// `UIWindowScene` reaches `.foregroundActive`. We stash the overlay here
    /// and present it once `scenePhase` transitions to `.active`.
    private var pendingOverlay: (type: ReminderType, duration: TimeInterval)?

    // MARK: - Foreground Fallback Timers

    /// Repeating timers that fire overlay breaks when the user has denied
    /// notification permissions. Only active while the app is in the foreground.
    private var fallbackTimers: [ReminderType: Timer] = [:]

    // MARK: - Reschedule Debounce

    /// Per-type debounce tasks — cancels a pending reschedule for the same type
    /// when a newer setting change arrives within the debounce window.
    private var rescheduleDebounce: [ReminderType: Task<Void, Never>] = [:]

    // MARK: - Snooze Wake

    /// In-process wake task — cancels the snooze and reschedules reminders
    /// when the snooze period expires while the app is in the foreground.
    private var snoozeWakeTask: Task<Void, Never>?

    // MARK: - Init

    init(
        settings: SettingsStore = SettingsStore(),
        scheduler: ReminderScheduler = ReminderScheduler(),
        notificationCenter: NotificationScheduling = UNUserNotificationCenter.current(),
        overlayManager: OverlayPresenting? = nil
    ) {
        self.settings = settings
        self.scheduler = scheduler
        self.notificationCenter = notificationCenter
        self.overlayManager = overlayManager ?? OverlayManager.shared
        Logger.lifecycle.info("AppCoordinator initialised")
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

    /// Master scheduling entrypoint — determines the right strategy based on
    /// notification authorisation and delegates accordingly.
    ///
    /// **P1-1 Snooze guard:** If a snooze is active, reminders are cancelled
    /// and a wake-up timer (in-process Task + silent UNNotification) is scheduled
    /// at `snoozeEnd`. Expired snoozes are cleared before proceeding normally.
    ///
    /// Call on launch (`.task`) and whenever settings change.
    func scheduleReminders() async {
        await refreshAuthStatus()

        // P1-1: Snooze guard — check before doing anything else.
        if let snoozeEnd = settings.snoozedUntil {
            if snoozeEnd > Date() {
                // Snooze is still active — cancel reminders and arm wake.
                scheduler.cancelAllReminders()
                stopFallbackTimers()
                scheduleSnoozeWakeTask(at: snoozeEnd)
                if notificationAuthStatus == .authorized {
                    await scheduleSnoozeWakeNotification(at: snoozeEnd)
                }
                Logger.scheduling.info("Snooze active until \(snoozeEnd) — reminders paused")
                return
            } else {
                // Snooze has expired — clear state and fall through to normal scheduling.
                settings.snoozedUntil = nil
                settings.snoozeCount  = 0
                Logger.scheduling.info("Snooze expired — clearing and resuming normal scheduling")
            }
        }

        // No active snooze — cancel any pending wake artifacts.
        cancelSnoozeWake()

        // First launch: prompt the user for permission
        if notificationAuthStatus == .notDetermined {
            await requestNotificationPermission()
        }

        if notificationAuthStatus == .authorized {
            // Happy path: use real UNNotifications
            await scheduler.scheduleReminders(using: settings)
            stopFallbackTimers()
            Logger.scheduling.info("Reminders scheduled via notifications")
        } else {
            // Denied / provisional / ephemeral — fall back to in-app timers
            scheduler.cancelAllReminders()
            startFallbackTimers()
            Logger.scheduling.info("Notifications unavailable — using foreground fallback timers")
        }
    }

    // MARK: - Per-Type Auth-Aware Reschedule

    /// Reschedule a single reminder type, respecting the current auth status.
    ///
    /// If notifications are authorized the UNNotification for `type` is
    /// cancelled and re-added with current settings. If notifications are
    /// denied the fallback timer for `type` is restarted instead.
    ///
    /// Calls are debounced per-type (300 ms) so rapid slider/picker changes
    /// don't flood UNUserNotificationCenter with add/remove requests.
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
            overlayManager.showOverlay(for: type, duration: duration, hapticsEnabled: settings.hapticsEnabled) {}
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
        overlayManager.showOverlay(for: pending.type, duration: pending.duration, hapticsEnabled: settings.hapticsEnabled) {}
    }

    // MARK: - App Lifecycle Hooks

    /// Called when the app returns to the foreground from background.
    ///
    /// Clears any expired snooze first. If snooze is still active, ensures the
    /// wake task is running. Otherwise refreshes auth status and ensures the
    /// correct scheduling strategy is active.
    func handleForegroundTransition() async {
        await refreshAuthStatus()

        // P1-1: Handle snooze state on foreground.
        if let snoozeEnd = settings.snoozedUntil {
            if snoozeEnd <= Date() {
                // Snooze expired while backgrounded — clear and reschedule.
                settings.snoozedUntil = nil
                settings.snoozeCount  = 0
                Logger.scheduling.info("Foreground transition: snooze expired — resuming normal scheduling")
                await scheduleReminders()
            } else {
                // Snooze still active — re-arm wake task in case it was lost.
                scheduleSnoozeWakeTask(at: snoozeEnd)
                Logger.scheduling.info("Foreground transition: snooze still active until \(snoozeEnd)")
            }
            return
        }

        switch notificationAuthStatus {
        case .authorized:
            if !fallbackTimers.isEmpty {
                // Auth was granted while we were in the background — switch strategies.
                stopFallbackTimers()
                await scheduler.scheduleReminders(using: settings)
                Logger.scheduling.info("Foreground transition: auth restored — switched to notifications")
            }
        case .denied:
            if fallbackTimers.isEmpty && settings.masterEnabled {
                // Timers were stopped on background transition — restart them.
                startFallbackTimers()
                Logger.scheduling.info("Foreground transition: restarted fallback timers")
            }
        default:
            break
        }
    }

    /// Called when the app moves to the background.
    ///
    /// Stops foreground-only fallback timers so they don't fire stale breaks
    /// on the next foreground resume. `handleForegroundTransition()` restarts
    /// them when the app becomes active again.
    func appWillResignActive() {
        stopFallbackTimers()
        Logger.lifecycle.debug("App resigned active — fallback timers stopped")
    }

    // MARK: - Foreground Fallback Timers

    /// Start repeating timers that show the overlay directly, bypassing
    /// the notification system. Only used when notifications are denied.
    func startFallbackTimers() {
        stopFallbackTimers()

        // Do not start fallback timers during an active snooze.
        guard settings.snoozedUntil == nil else {
            Logger.scheduling.debug("Skipping fallback timers — snooze is active")
            return
        }

        for type in ReminderType.allCases {
            guard settings.isEnabled(for: type) else { continue }
            startFallbackTimer(for: type)
        }
    }

    /// Invalidate and remove all fallback timers.
    func stopFallbackTimers() {
        for (type, timer) in fallbackTimers {
            timer.invalidate()
            Logger.scheduling.debug("Fallback timer stopped for \(type.rawValue)")
        }
        fallbackTimers.removeAll()
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
        content.title              = "Reminders Resumed"
        content.body               = "Your eye and posture reminders are now active again."
        content.sound              = nil   // silent — informational only
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
        await scheduleReminders()
        Logger.scheduling.info("Snooze wake — reminders resumed")
    }

    // MARK: - Private

    /// Execute a single-type reschedule after the debounce window has elapsed.
    private func performReschedule(for type: ReminderType) async {
        await refreshAuthStatus()

        if notificationAuthStatus == .authorized {
            fallbackTimers[type]?.invalidate()
            fallbackTimers.removeValue(forKey: type)
            await scheduler.rescheduleReminder(for: type, using: settings)
        } else {
            scheduler.cancelReminder(for: type)
            startFallbackTimer(for: type)
        }
    }

    /// Create (or replace) the repeating fallback timer for a single type.
    private func startFallbackTimer(for type: ReminderType) {
        fallbackTimers[type]?.invalidate()
        fallbackTimers.removeValue(forKey: type)

        guard settings.isEnabled(for: type) else {
            Logger.scheduling.debug("Skipping fallback timer for \(type.rawValue) — disabled")
            return
        }

        let reminderSettings = settings.settings(for: type)
        let timer = Timer.scheduledTimer(
            withTimeInterval: reminderSettings.interval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let duration = self.settings.settings(for: type).breakDuration
                self.overlayManager.showOverlay(for: type, duration: duration, hapticsEnabled: self.settings.hapticsEnabled) {}
            }
        }
        fallbackTimers[type] = timer
        Logger.scheduling.info("Fallback timer started for \(type.rawValue) every \(reminderSettings.interval)s")
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
        fallbackTimers[type]?.invalidate()
        fallbackTimers.removeValue(forKey: type)
    }

    func cancelAllReminders() {
        scheduler.cancelAllReminders()
        stopFallbackTimers()
        overlayManager.clearQueue()

        // If snooze was just applied (snoozedUntil set before this call),
        // arm the in-process wake task immediately so the app resumes on time
        // while staying in the foreground throughout the snooze period.
        if let snoozeEnd = settings.snoozedUntil, snoozeEnd > Date() {
            scheduleSnoozeWakeTask(at: snoozeEnd)
        }
    }
}
