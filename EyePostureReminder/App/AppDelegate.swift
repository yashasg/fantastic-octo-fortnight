import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Logger.lifecycle.info("App did finish launching")
        return true
    }

    // Show overlay when a notification fires while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let categoryID = notification.request.content.categoryIdentifier
        if let type = ReminderType(categoryIdentifier: categoryID) {
            Task { @MainActor in
                OverlayManager.shared.showOverlay(for: type, duration: 20) {}
            }
        }
        // Suppress the system banner — our overlay is the UI.
        completionHandler([])
    }

    // Show overlay when the user taps a notification to open the app from background.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let categoryID = response.notification.request.content.categoryIdentifier
        if let type = ReminderType(categoryIdentifier: categoryID) {
            Task { @MainActor in
                OverlayManager.shared.showOverlay(for: type, duration: 20) {}
            }
        }
        completionHandler()
    }
}
