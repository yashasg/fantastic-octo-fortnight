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
            OverlayManager.shared.showOverlay(for: type, duration: duration) {}
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
        OverlayManager.shared.showOverlay(for: pending.type, duration: pending.duration) {}
    }

    // MARK: - Foreground Fallback Timers

    /// Start repeating timers that show the overlay directly, bypassing
    /// the notification system. Only used when notifications are denied.
    func startFallbackTimers() {
        stopFallbackTimers()

        for type in ReminderType.allCases {
            guard settings.isEnabled(for: type) else { continue }

            let reminderSettings = settings.settings(for: type)
            let timer = Timer.scheduledTimer(
                withTimeInterval: reminderSettings.interval,
                repeats: true
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let duration = self.settings.settings(for: type).breakDuration
                    OverlayManager.shared.showOverlay(for: type, duration: duration) {}
                }
            }
            fallbackTimers[type] = timer
            Logger.scheduling.info("Fallback timer started for \(type.rawValue) every \(reminderSettings.interval)s")
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
}
