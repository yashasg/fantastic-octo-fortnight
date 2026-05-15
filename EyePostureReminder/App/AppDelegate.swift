import ComposableArchitecture
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
#if DEBUG
    static let uiTestOverlayBreakDuration: TimeInterval = 600
#endif

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
    /// callbacks into the TCA root `Store`. Held weakly so the store's
    /// lifetime is owned exclusively by `EyePostureReminderApp` (`p0-tca-12`
    /// / #675).
    weak var store: StoreOf<AppFeature>? {
        didSet {
            guard store != nil else { return }
            Task { @MainActor [weak self] in
                self?.flushPendingNotificationRoutes()
            }
        }
    }
    private var pendingNotificationRoutes: [NotificationRoute] = []

#if DEBUG
    /// Pre-seeds UI-test UserDefaults keys before the SwiftUI store seed
    /// in `EyePostureReminderApp.init()` reads them. Without this guard,
    /// the seed (which historically lived on `@StateObject AppCoordinator`,
    /// deleted in `#755` Phase E) raced with `didFinishLaunchingWithOptions`
    /// and fell back to `ScreenTimeAuthorizationNoop(.unavailable)`, which
    /// prevented `TrueInterruptSkippedBanner` from ever rendering on the
    /// first cold launch (#457).
    ///
    /// `hasSeenOnboarding` is pre-seeded earlier — directly in
    /// `EyePostureReminderApp.init()` — because `@UIApplicationDelegateAdaptor`
    /// only instantiates this delegate as part of `UIApplicationMain`, which
    /// runs *after* the App struct's `init()` body returns. See #707.
    ///
    /// Overlay launch arguments (`--show-overlay-eyes` / `--show-overlay-posture`)
    /// are also seeded here so the `uiTestOverlayType` key and inflated break
    /// durations land before the TCA root state's initial seed reads
    /// `eyes.breakDuration` / `posture.breakDuration` from `UserDefaults`.
    /// Without this, `applyUITestLaunchArguments()` — which runs from
    /// `didFinishLaunchingWithOptions`, after the SwiftUI state seed in
    /// some launch orderings — wrote inflated values into a settings store
    /// the active overlay was no longer using, causing the overlay to
    /// auto-dismiss before tests asserted on it (#711).
    private func preSeedUITestDefaults() {
        if launchArguments.contains("--simulate-screen-time-not-determined") {
            uiTestDefaults.set(
                ScreenTimeAuthorizationStatus.notDetermined.rawValue,
                forKey: AppStorageKey.uiTestScreenTimeStatus
            )
            uiTestDefaults.set(
                launchArguments.contains("--dismiss-true-interrupt-banner") &&
                    !launchArguments.contains("--show-true-interrupt-banner"),
                forKey: AppStorageKey.trueInterruptSkippedBannerDismissed
            )
        } else {
            // Remove any stale stub key so non-True-Interrupt launches use the
            // real ScreenTimeAuthorizationNoop and don't accidentally show the banner.
            uiTestDefaults.removeObject(forKey: AppStorageKey.uiTestScreenTimeStatus)
            if launchArguments.contains("--skip-onboarding"),
               !launchArguments.contains("--dismiss-true-interrupt-banner") {
                uiTestDefaults.set(false, forKey: AppStorageKey.trueInterruptSkippedBannerDismissed)
            }
        }

        if launchArguments.contains("--show-overlay-eyes") {
            seedOverlayLaunchDefaults(for: .eyes)
        } else if launchArguments.contains("--show-overlay-posture") {
            seedOverlayLaunchDefaults(for: .posture)
        }
        // Stale `uiTestOverlayType` (no overlay launch arg present) is wiped
        // by `applyUITestLaunchArguments()` in `didFinishLaunchingWithOptions`,
        // before SwiftUI's `.onAppear` calls `consumeUITestOverlayType()`.
    }

    /// Writes the UserDefaults keys consumed by the `--show-overlay-{eyes,posture}`
    /// UI-test launch arguments. Inflated break durations keep the overlay
    /// on-screen long enough for assertions to run.
    ///
    /// `applyUITestLaunchArguments()` re-applies the same writes after calling
    /// `SettingsStore.resetToDefaults()` (which would otherwise wipe these
    /// pre-seeds back to their build-time defaults).
    private func seedOverlayLaunchDefaults(for type: ReminderType) {
        uiTestDefaults.set(true, forKey: AppStorageKey.hasSeenOnboarding)
        uiTestDefaults.set(type.rawValue, forKey: AppStorageKey.uiTestOverlayType)
        uiTestDefaults.set(
            Self.uiTestOverlayBreakDuration,
            forKey: SettingsStore.Keys.eyesBreakDuration
        )
        uiTestDefaults.set(
            Self.uiTestOverlayBreakDuration,
            forKey: SettingsStore.Keys.postureBreakDuration
        )
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
    ///
    /// `preSeedUITestDefaults()` (called from `init()`) is the first writer for
    /// the overlay-launch-arg keys (`uiTestOverlayType`, inflated break
    /// durations, `hasSeenOnboarding`); this method re-applies the same writes
    /// after `SettingsStore.resetToDefaults()` because the reset clobbers the
    /// pre-seeded break durations back to their build-time defaults (#711).
#if DEBUG
    private func applyUITestLaunchArguments() {
        let args = launchArguments
        let defaults = uiTestDefaults
        // Clear any stale overlay-type seed before re-applying any launch-arg
        // intent. `preSeedUITestDefaults()` writes the new value (when an
        // overlay launch arg is present) earlier in `init()`; the
        // overlay-launch-arg branches below repeat the write so the value
        // survives the `SettingsStore.resetToDefaults()` call inside
        // `applyOverlayLaunchArgument(for:)`.
        if !args.contains("--show-overlay-eyes") && !args.contains("--show-overlay-posture") {
            defaults.removeObject(forKey: AppStorageKey.uiTestOverlayType)
        }
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
            applyOverlayLaunchArgument(for: .eyes)
        }
        if args.contains("--show-overlay-posture") {
            applyOverlayLaunchArgument(for: .posture)
        }
        if args.contains("--simulate-screen-time-not-determined") {
            defaults.set(true, forKey: AppStorageKey.hasSeenOnboarding)
            resolvedSettingsStore.resetToDefaults()
            defaults.set(
                ScreenTimeAuthorizationStatus.notDetermined.rawValue,
                forKey: AppStorageKey.uiTestScreenTimeStatus
            )
            defaults.set(
                args.contains("--dismiss-true-interrupt-banner") &&
                    !args.contains("--show-true-interrupt-banner"),
                forKey: AppStorageKey.trueInterruptSkippedBannerDismissed
            )
        }
    }

    /// Resets the live `SettingsStore` and re-applies the inflated overlay
    /// break durations + `uiTestOverlayType` seed previously written by
    /// `preSeedUITestDefaults()`. The reset is required to scrub stale settings
    /// from prior test launches, but it would otherwise overwrite the inflated
    /// break durations with the build-time defaults (#711).
    private func applyOverlayLaunchArgument(for type: ReminderType) {
        let defaults = uiTestDefaults
        defaults.set(true, forKey: AppStorageKey.hasSeenOnboarding)
        let settings = resolvedSettingsStore
        settings.resetToDefaults()
        settings.eyesBreakDuration = Self.uiTestOverlayBreakDuration
        settings.postureBreakDuration = Self.uiTestOverlayBreakDuration
        defaults.set(type.rawValue, forKey: AppStorageKey.uiTestOverlayType)
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
        // ⚠️ On the very first cold launch, `store` is nil here because
        // SwiftUI's `.onAppear` (which sets it) has not fired yet. The optional-
        // chain silently exits — this is safe because the `.scheduling(.start)`
        // task in `EyePostureReminderApp` also checks for and clears expired
        // snooze state via `scheduleRemindersEffect`.
        Task { @MainActor [weak self] in
            self?.store?.send(.scheduling(.clearExpiredSnoozeIfNeeded))
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func notificationRoute(for categoryID: String) -> NotificationRoute {
        if let type = ReminderType(categoryIdentifier: categoryID) {
            return .reminder(type)
        }
        if categoryID == SchedulingFeature.snoozeWakeCategory {
            return .snoozeWake
        }
        return .ignore
    }

    func dispatchNotificationRoute(_ route: NotificationRoute) {
        Task { @MainActor [weak self] in
            self?.dispatchNotificationRouteOnMainActor(route)
        }
    }

    @MainActor
    private func dispatchNotificationRouteOnMainActor(_ route: NotificationRoute) {
        guard let store else {
            if route != .ignore {
                pendingNotificationRoutes.append(route)
            }
            return
        }

        switch route {
        case .reminder, .snoozeWake:
            store.send(.notificationRouted(route))
        case .ignore:
            break
        }
    }

    @MainActor
    private func flushPendingNotificationRoutes() {
        guard store != nil, !pendingNotificationRoutes.isEmpty else { return }

        let routes = pendingNotificationRoutes
        pendingNotificationRoutes.removeAll()
        for route in routes {
            dispatchNotificationRouteOnMainActor(route)
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
