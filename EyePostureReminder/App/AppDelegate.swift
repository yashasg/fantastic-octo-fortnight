import os
import UIKit
import UserNotifications

protocol UserNotificationCenterDelegating: AnyObject {
    var delegate: UNUserNotificationCenterDelegate? { get set }
}

extension UNUserNotificationCenter: UserNotificationCenterDelegating {}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    enum NotificationRoute: Equatable {
        case reminder(ReminderType)
        case snoozeWake
        case ignore
    }

    typealias ExceptionHandlerInstaller = () -> Void

    private let notificationCenter: UserNotificationCenterDelegating?
    private let metricKitSubscriber: MetricKitSubscribing?
    private let settingsStore: SettingsStore?
    private let installUncaughtExceptionHandlerImpl: ExceptionHandlerInstaller
    private let launchArguments: [String]
    private let uiTestDefaults: UserDefaults
    private let launchArgumentsProvider: () -> [String]
    private let makeUITestDefaults: () -> UserDefaults
    private let makeNotificationCenter: () -> UserNotificationCenterDelegating
    private let makeMetricKitSubscriber: () -> MetricKitSubscribing
    private let makeSettingsStore: @MainActor () -> SettingsStore
    private lazy var resolvedNotificationCenter: UserNotificationCenterDelegating =
        notificationCenter ?? makeNotificationCenter()
    private lazy var resolvedMetricKitSubscriber: MetricKitSubscribing =
        metricKitSubscriber ?? makeMetricKitSubscriber()
    private lazy var resolvedSettingsStore: SettingsStore =
        settingsStore ?? makeSettingsStore()

    override convenience init() {
        self.init(notificationCenter: nil)
    }

    init(
        notificationCenter: UserNotificationCenterDelegating? = nil,
        metricKitSubscriber: MetricKitSubscribing? = nil,
        settingsStore: SettingsStore? = nil,
        installUncaughtExceptionHandler: ExceptionHandlerInstaller? = nil,
        launchArguments: [String]? = nil,
        uiTestDefaults: UserDefaults? = nil,
        launchArgumentsProvider: @escaping () -> [String] = { CommandLine.arguments },
        makeUITestDefaults: @escaping () -> UserDefaults = { .standard },
        makeNotificationCenter: (() -> UserNotificationCenterDelegating)? = nil,
        makeMetricKitSubscriber: @escaping () -> MetricKitSubscribing = { MetricKitSubscriber.shared },
        makeSettingsStore: @escaping @MainActor () -> SettingsStore = { SettingsStore() }
    ) {
        self.notificationCenter = notificationCenter
        self.metricKitSubscriber = metricKitSubscriber
        self.settingsStore = settingsStore
        self.installUncaughtExceptionHandlerImpl =
            installUncaughtExceptionHandler ?? Self.installDefaultUncaughtExceptionHandler
        self.launchArgumentsProvider = launchArgumentsProvider
        self.launchArguments = launchArguments ?? launchArgumentsProvider()
        self.makeUITestDefaults = makeUITestDefaults
        self.uiTestDefaults = uiTestDefaults ?? makeUITestDefaults()
        let resolvedMakeNotificationCenter = makeNotificationCenter ?? { UNUserNotificationCenter.current() }
        self.makeNotificationCenter = resolvedMakeNotificationCenter
        self.makeMetricKitSubscriber = makeMetricKitSubscriber
        self.makeSettingsStore = makeSettingsStore
        super.init()
#if DEBUG
        preSeedUITestDefaults()
#endif
    }

    /// Set by `EyePostureReminderApp.onAppear` — bridges UIKit delegate
    /// callbacks into the SwiftUI-owned coordinator.
    var coordinator: AppCoordinator?

#if DEBUG
    /// Pre-seeds UI-test UserDefaults keys in `init()` — before `@StateObject
    /// AppCoordinator()` in `EyePostureReminderApp` can read them. Without this
    /// guard, `AppCoordinator.init()` races with `didFinishLaunchingWithOptions`
    /// and falls back to `ScreenTimeAuthorizationNoop(.unavailable)`, which
    /// prevents `TrueInterruptSkippedBanner` from ever rendering on the first
    /// cold launch (#457).
    private func preSeedUITestDefaults() {
        if launchArguments.contains("--simulate-screen-time-not-determined") {
            uiTestDefaults.set(
                ScreenTimeAuthorizationStatus.notDetermined.rawValue,
                forKey: AppStorageKey.uiTestScreenTimeStatus
            )
            // Ensure the banner-dismissed flag is clear so the banner renders.
            uiTestDefaults.set(false, forKey: AppStorageKey.trueInterruptSkippedBannerDismissed)
        } else {
            // Remove any stale stub key so non-True-Interrupt launches use the
            // real ScreenTimeAuthorizationNoop and don't accidentally show the banner.
            uiTestDefaults.removeObject(forKey: AppStorageKey.uiTestScreenTimeStatus)
        }
    }
#endif

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        resolvedNotificationCenter.delegate = self
        installUncaughtExceptionHandler()
        resolvedMetricKitSubscriber.register()
#if DEBUG
        applyUITestLaunchArguments()
#endif
        Logger.lifecycle.info("App did finish launching")
        return true
    }

    /// Installs `NSSetUncaughtExceptionHandler` so uncaught ObjC exceptions
    /// (NSInvalidArgumentException, KVO issues, UIKit assertions, out-of-bounds, etc.)
    /// are logged at fault level before the process terminates.
    /// Fault-level messages persist to disk immediately, surviving the crash.
    func installUncaughtExceptionHandler() {
        installUncaughtExceptionHandlerImpl()
    }

    private static func installDefaultUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            let name = exception.name.rawValue
            let reason = exception.reason ?? "nil"
            let info = String(describing: exception.userInfo)
            let stack = exception.callStackSymbols.joined(separator: "\n")
            Logger.lifecycle.fault("""
                Uncaught ObjC exception: \
                name=\(name, privacy: .public) \
                reason=\(reason, privacy: .public) \
                userInfo=\(info, privacy: .private)
                """)
            Logger.lifecycle.fault("Stack trace:\n\(stack, privacy: .private)")
        }
    }

    // MARK: - UI Test Support

    /// Handles launch arguments injected by XCUITest targets to control app state.
    /// `#if DEBUG` ensures these backdoors are compiled out of Release/TestFlight
    /// builds, closing the production-settings-reset vulnerability (re: #350/#405).
#if DEBUG
    private func applyUITestLaunchArguments() {
        let args = launchArguments
        let defaults = uiTestDefaults
        defaults.removeObject(forKey: AppStorageKey.uiTestOverlayType)
        if args.contains("--skip-onboarding") {
            defaults.set(true, forKey: AppStorageKey.hasSeenOnboarding)
            // Reset all settings to defaults so each test starts from a clean, known state.
            // Without this, toggling settings in one test pollutes the next test's launch state.
            resolvedSettingsStore.resetToDefaults()
        }
        if args.contains("--reset-onboarding") {
            defaults.removeObject(forKey: AppStorageKey.hasSeenOnboarding)
            resolvedSettingsStore.resetToDefaults()
        }
        if args.contains("--show-overlay-eyes") {
            defaults.set(true, forKey: AppStorageKey.hasSeenOnboarding)
            let settings = resolvedSettingsStore
            settings.resetToDefaults()
            settings.eyesBreakDuration = 120
            settings.postureBreakDuration = 120
            defaults.set(ReminderType.eyes.rawValue, forKey: AppStorageKey.uiTestOverlayType)
        }
        if args.contains("--show-overlay-posture") {
            defaults.set(true, forKey: AppStorageKey.hasSeenOnboarding)
            let settings = resolvedSettingsStore
            settings.resetToDefaults()
            settings.eyesBreakDuration = 120
            settings.postureBreakDuration = 120
            defaults.set(ReminderType.posture.rawValue, forKey: AppStorageKey.uiTestOverlayType)
        }
        if args.contains("--simulate-screen-time-not-determined") {
            defaults.set(true, forKey: AppStorageKey.hasSeenOnboarding)
            resolvedSettingsStore.resetToDefaults()
            defaults.set(
                ScreenTimeAuthorizationStatus.notDetermined.rawValue,
                forKey: AppStorageKey.uiTestScreenTimeStatus
            )
        }
    }

    /// Returns and clears a pending UI-test overlay request if present.
    /// Used by `EyePostureReminderApp` after the coordinator is active.
    func consumeUITestOverlayType() -> ReminderType? {
        guard let rawType = uiTestDefaults.string(forKey: AppStorageKey.uiTestOverlayType),
              let type = ReminderType(rawValue: rawType) else {
            return nil
        }
        uiTestDefaults.removeObject(forKey: AppStorageKey.uiTestOverlayType)
        return type
    }
#endif

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

    func notificationRoute(for categoryID: String) -> NotificationRoute {
        if let type = ReminderType(categoryIdentifier: categoryID) {
            return .reminder(type)
        }
        if categoryID == AppCoordinator.snoozeWakeCategory {
            return .snoozeWake
        }
        return .ignore
    }

    private func dispatchNotificationRoute(_ route: NotificationRoute) {
        switch route {
        case .reminder(let type):
            Task { @MainActor [weak self] in
                self?.coordinator?.handleNotification(for: type)
            }
        case .snoozeWake:
            Task { @MainActor [weak self] in
                self?.coordinator?.cancelSnoozeWakeTaskIfNeeded()
                await self?.coordinator?.scheduleReminders()
            }
        case .ignore:
            break
        }
    }

    /// Foreground delivery — show overlay immediately via coordinator.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let categoryID = notification.request.content.categoryIdentifier
        dispatchNotificationRoute(notificationRoute(for: categoryID))
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
        dispatchNotificationRoute(notificationRoute(for: categoryID))
        completionHandler()
    }
}
