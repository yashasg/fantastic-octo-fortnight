import ComposableArchitecture
import SwiftUI

@main
struct EyePostureReminderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    /// Single TCA `Store` driving the app (`#755` Phase D). Every SwiftUI
    /// view in the tree (`HomeView`, `SettingsView`, `OnboardingView`,
    /// `OnboardingSetupView`, `RootView`) reads from a store scope or
    /// `@AppStorage` directly.
    private let store: StoreOf<AppFeature>

    init() {
        AppTypography.registerFonts()
#if DEBUG
        // Mirror onboarding-affecting launch args into UserDefaults BEFORE the
        // initial state seed below reads them. `AppDelegate.init()` runs too
        // late under `@UIApplicationDelegateAdaptor` (UIKit only instantiates
        // the delegate as part of `UIApplicationMain`, after this `App.init`
        // returns), so deferring the sync to `AppDelegate` left the store on
        // the stale `true` value left in UserDefaults from the previous test
        // launch and onboarding tests landed on Home (#707).
        Self.preSeedHasSeenOnboardingFromLaunchArgsIfNeeded()
        // Mirror overlay-affecting launch args into UserDefaults BEFORE the
        // settings seed below reads them, for the same UIApplicationMain
        // ordering reason. Without this, `--show-overlay-eyes` /
        // `--show-overlay-posture` would leave `state.scheduling.settings`
        // stuck on the previous test launch's value (or `defaultEyes`) and
        // `reminderNotificationEffect` would race with the
        // `SettingsClient.stream` first emission, intermittently showing
        // overlays at `breakDuration: 0` (#737).
        Self.preSeedReminderSettingsFromLaunchArgsIfNeeded()
#endif
        var initialState = AppFeature.State()
        initialState.hasSeenOnboarding = UserDefaults.standard.bool(
            forKey: AppStorageKey.hasSeenOnboarding
        )
        // Seed scheduling.settings synchronously from UserDefaults so the TCA
        // root state observes the persisted (or `--show-overlay-*`-inflated)
        // `breakDuration` immediately, before `SchedulingFeature.start`
        // installs the `SettingsClient` stream subscription. Closes the
        // settings-load race documented in #737.
        initialState.scheduling.settings = SettingsStore.eyesSnapshotFromUserDefaults()
        self.store = Store(initialState: initialState) { AppFeature() }
    }

#if DEBUG
    /// Synchronizes the `hasSeenOnboarding` UserDefaults key with the
    /// onboarding-affecting launch arguments before `init()` reads it to seed
    /// `AppFeature.State` (#707).
    ///
    /// `--reset-onboarding` clears the key; the four "skip past onboarding"
    /// launch arguments (used by tests that need to start on Home/overlay
    /// screens) set it to `true`. The full `AppDelegate.applyUITestLaunch
    /// Arguments()` pass still runs from `didFinishLaunchingWithOptions` and
    /// handles `SettingsStore` resets and overlay-type seeding — this hook
    /// only mirrors the onboarding gate so the TCA root state starts on the
    /// correct branch. `#if DEBUG` keeps the launch-arg backdoor out of
    /// Release/TestFlight builds (re: #350/#405).
    private static func preSeedHasSeenOnboardingFromLaunchArgsIfNeeded() {
        let args = CommandLine.arguments
        if args.contains("--reset-onboarding") {
            UserDefaults.standard.removeObject(forKey: AppStorageKey.hasSeenOnboarding)
            return
        }
        let skipsOnboarding =
            args.contains("--skip-onboarding") ||
            args.contains("--show-overlay-eyes") ||
            args.contains("--show-overlay-posture") ||
            args.contains("--simulate-screen-time-not-determined")
        if skipsOnboarding {
            UserDefaults.standard.set(true, forKey: AppStorageKey.hasSeenOnboarding)
        }
    }

    /// Mirrors the `--show-overlay-eyes` / `--show-overlay-posture` launch
    /// arguments into the `kshana.eyes.breakDuration` /
    /// `kshana.posture.breakDuration` UserDefaults keys before
    /// `SettingsStore.eyesSnapshotFromUserDefaults()` reads them in `init()`.
    ///
    /// Mirrors the inflation that `AppDelegate.applyUITestLaunchArguments`
    /// applies via `SettingsStore.eyesBreakDuration = uiTestOverlayBreakDuration`,
    /// but runs synchronously in `App.init` so the seed picks it up — the
    /// `AppDelegate` pass runs from `didFinishLaunchingWithOptions`, after
    /// `App.init` has already returned. Without this guard the TCA root
    /// `state.scheduling.settings.breakDuration` would race with
    /// `SettingsClient.stream`'s first emission and the UI-test overlay
    /// backdoor (now dispatched through `store.send(.notificationRouted)`)
    /// would intermittently show 0-second overlays that auto-dismiss before
    /// `OverlayUITests` can interact with them (#737).
    ///
    /// `#if DEBUG` keeps the launch-arg backdoor out of Release/TestFlight
    /// builds (re: #350/#405).
    private static func preSeedReminderSettingsFromLaunchArgsIfNeeded() {
        let args = CommandLine.arguments
        let inflateForOverlayLaunchArg =
            args.contains("--show-overlay-eyes") ||
            args.contains("--show-overlay-posture")
        guard inflateForOverlayLaunchArg else { return }
        UserDefaults.standard.set(
            AppDelegate.uiTestOverlayBreakDuration,
            forKey: SettingsStore.Keys.eyesBreakDuration
        )
        UserDefaults.standard.set(
            AppDelegate.uiTestOverlayBreakDuration,
            forKey: SettingsStore.Keys.postureBreakDuration
        )
    }
#endif

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .task {
                    // `.onAppear` is the AppFeature entry-point action.
                    // It triggers `.scheduling(.start)` *and* subscribes to
                    // `overlayClient.lifecycleEvents()` so the overlay →
                    // Settings handoff (#786) is wired before the user can
                    // tap anything. Pre-#786 this call went straight to
                    // `.scheduling(.start)`, which left the lifecycle
                    // subscription dead.
                    await store.send(.onAppear).finish()
                }
                .onChangeCompat(of: scenePhase) { phase in
                    if phase == .active {
                        presentUITestOverlayIfNeeded()
                    }
                    store.send(.scenePhaseChanged(phase))
                }
                .onAppear {
                    appDelegate.store = store
                    presentUITestOverlayIfNeeded()
                }
        }
    }

#if DEBUG
    /// UI test mode: if a specific overlay type was requested via launch
    /// arguments, trigger it after SwiftUI has attached/activated the window.
    ///
    /// Routes through `store.send(.notificationRouted(.reminder(type)))` —
    /// the same path UNUserNotificationCenter delivery takes via
    /// `AppDelegate.dispatchNotificationRoute` — so the backdoor exercises
    /// the production reducer code added in `#755` Phase E rather than any
    /// out-of-band shim. The synchronous `state.scheduling.settings` seed in
    /// `init()` plus the `--show-overlay-*` UserDefaults inflation guarantees
    /// the reducer reads the inflated `breakDuration` immediately, without
    /// racing the `SettingsClient.stream` first emission (#737).
    ///
    /// `#if DEBUG` ensures this backdoor is compiled out of Release builds
    /// (re: #350/#405).
    private func presentUITestOverlayIfNeeded() {
        Task { @MainActor in
            await Task.yield()
            if let type = appDelegate.consumeUITestOverlayType() {
                store.send(.notificationRouted(.reminder(type)))
            }
        }
    }
#else
    private func presentUITestOverlayIfNeeded() {}
#endif
}
