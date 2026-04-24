import UIKit
import UserNotifications
import os

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
        Logger.lifecycle.info("App did finish launching")
        return true
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
        }
        // Suppress the system banner — our overlay is the UI.
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
        }
        completionHandler()
    }
}
