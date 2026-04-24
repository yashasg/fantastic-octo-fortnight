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

    // MARK: - Owned Dependencies

    let settings: SettingsStore
    let scheduler: ReminderScheduler

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

    // MARK: - Init

    init(
        settings: SettingsStore = SettingsStore(),
        scheduler: ReminderScheduler = ReminderScheduler()
    ) {
        self.settings = settings
        self.scheduler = scheduler
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
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            Logger.lifecycle.info("Notification authorisation \(granted ? "granted" : "denied")")
        } catch {
            Logger.lifecycle.error("Notification authorisation request failed: \(error.localizedDescription)")
        }
        await refreshAuthStatus()
    }

    /// Re-read the current authorisation status from the system.
    func refreshAuthStatus() async {
        let currentSettings = await UNUserNotificationCenter.current().notificationSettings()
        notificationAuthStatus = currentSettings.authorizationStatus
        Logger.lifecycle.debug("Notification auth status: \(self.notificationAuthStatus.rawValue)")
    }

    // MARK: - Scheduling Entrypoint

    /// Master scheduling entrypoint — determines the right strategy based on
    /// notification authorisation and delegates accordingly.
    ///
    /// Call on launch (`.task`) and whenever settings change.
    func scheduleReminders() async {
        await refreshAuthStatus()

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
    /// Reads the break duration from `SettingsStore` instead of hardcoding.
    /// If no window scene is active yet (notification-tap race), the overlay is
    /// queued and presented when `presentPendingOverlayIfNeeded()` is called.
    func handleNotification(for type: ReminderType) {
        let duration = settings.settings(for: type).breakDuration

        let hasActiveScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .contains { $0.activationState == .foregroundActive }

        if hasActiveScene {
            OverlayManager.shared.showOverlay(for: type, duration: duration, hapticsEnabled: settings.hapticsEnabled) {}
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
        OverlayManager.shared.showOverlay(for: pending.type, duration: pending.duration, hapticsEnabled: settings.hapticsEnabled) {}
    }

    // MARK: - App Lifecycle Hooks

    /// Called when the app returns to the foreground from background.
    ///
    /// Refreshes auth status and ensures the correct scheduling strategy is
    /// running. If permission was granted while the app was backgrounded,
    /// switches from fallback timers to real notifications. If still denied
    /// and no timers are running, restarts them.
    func handleForegroundTransition() async {
        await refreshAuthStatus()

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
                OverlayManager.shared.showOverlay(for: type, duration: duration, hapticsEnabled: self.settings.hapticsEnabled) {}
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
        OverlayManager.shared.clearQueue()
    }
}
