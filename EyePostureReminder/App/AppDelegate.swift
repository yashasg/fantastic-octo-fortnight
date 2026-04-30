import os
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Set by `EyePostureReminderApp.onAppear` — bridges UIKit delegate
    /// callbacks into the SwiftUI-owned coordinator.
    var coordinator: AppCoordinator?

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        installUncaughtExceptionHandler()
        MetricKitSubscriber.shared.register()
        applyUITestLaunchArguments()
        Logger.lifecycle.info("App did finish launching")
        return true
    }

    /// Installs `NSSetUncaughtExceptionHandler` so uncaught ObjC exceptions
    /// (NSInvalidArgumentException, KVO issues, UIKit assertions, out-of-bounds, etc.)
    /// are logged at fault level before the process terminates.
    /// Fault-level messages persist to disk immediately, surviving the crash.
    func installUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            let name = exception.name.rawValue
            let reason = exception.reason ?? "nil"
            let info = String(describing: exception.userInfo)
            let stack = exception.callStackSymbols.joined(separator: "\n")
            Logger.lifecycle.fault("""
                Uncaught ObjC exception: \
                name=\(name, privacy: .public) \
                reason=\(reason, privacy: .private) \
                userInfo=\(info, privacy: .private)
                """)
            Logger.lifecycle.fault("Stack trace:\n\(stack, privacy: .private)")
        }
    }

    // MARK: - UI Test Support

    /// Handles launch arguments injected by XCUITest targets to control app state.
    private func applyUITestLaunchArguments() {
        let args = CommandLine.arguments
        if args.contains("--skip-onboarding") {
            UserDefaults.standard.set(true, forKey: AppStorageKey.hasSeenOnboarding)
            // Reset all settings to defaults so each test starts from a clean, known state.
            // Without this, toggling settings in one test pollutes the next test's launch state.
            SettingsStore().resetToDefaults()
        }
        if args.contains("--reset-onboarding") {
            UserDefaults.standard.removeObject(forKey: AppStorageKey.hasSeenOnboarding)
        }
        if args.contains("--show-overlay-eyes") {
            UserDefaults.standard.set(true, forKey: AppStorageKey.hasSeenOnboarding)
            SettingsStore().resetToDefaults()
            UserDefaults.standard.set(ReminderType.eyes.rawValue, forKey: AppStorageKey.uiTestOverlayType)
        }
        if args.contains("--show-overlay-posture") {
            UserDefaults.standard.set(true, forKey: AppStorageKey.hasSeenOnboarding)
            SettingsStore().resetToDefaults()
            UserDefaults.standard.set(ReminderType.posture.rawValue, forKey: AppStorageKey.uiTestOverlayType)
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Safety net: if the snooze-wake notification was swiped away on a killed
        // app the in-process Task never fires. Clear any stale snoozedUntil so the
        // first scheduleReminders() call (via EyePostureReminderApp .task) sees a
        // clean slate. handleForegroundTransition() handles the background→foreground
        // path; this covers cold-launch after a dismissed snooze-wake notification.
        //
        // ⚠️ On the very first cold launch, `coordinator` is nil here because
        // SwiftUI's `.onAppear` (which sets it) has not fired yet. The optional-
        // chain silently exits — this is safe because `scheduleReminders()` in
        // `.task` also checks for and clears expired snooze state.
        Task { @MainActor [weak self] in
            await self?.coordinator?.clearExpiredSnoozeIfNeeded()
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Foreground delivery — show overlay immediately via coordinator.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let categoryID = notification.request.content.categoryIdentifier
        if let type = ReminderType(categoryIdentifier: categoryID) {
            Task { @MainActor [weak self] in
                self?.coordinator?.handleNotification(for: type)
            }
        } else if categoryID == AppCoordinator.snoozeWakeCategory {
            // Snooze has expired — cancel the in-process wake Task first so it
            // doesn't also call handleSnoozeWake() and double-fire analytics.
            Task { @MainActor [weak self] in
                self?.coordinator?.cancelSnoozeWakeTaskIfNeeded()
                await self?.coordinator?.scheduleReminders()
            }
        }
        // Suppress the system banner — our overlay (or no-op) is the UI.
        completionHandler([])
    }

    /// Background tap — queue via coordinator (scene may not be active yet).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let categoryID = response.notification.request.content.categoryIdentifier
        if let type = ReminderType(categoryIdentifier: categoryID) {
            Task { @MainActor [weak self] in
                self?.coordinator?.handleNotification(for: type)
            }
        } else if categoryID == AppCoordinator.snoozeWakeCategory {
            // Snooze notification tapped (or delivered silently) — cancel the in-process
            // wake Task before resuming so the two paths don't double-reschedule.
            Task { @MainActor [weak self] in
                self?.coordinator?.cancelSnoozeWakeTaskIfNeeded()
                await self?.coordinator?.scheduleReminders()
            }
        }
        completionHandler()
    }
}
