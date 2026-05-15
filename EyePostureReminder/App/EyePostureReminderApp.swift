import ComposableArchitecture
import SwiftUI

@main
struct EyePostureReminderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var coordinator = AppCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    /// Single TCA `Store` driving the app, introduced by `p0-tca-11` (#674).
    /// `AppCoordinator` is intentionally kept alongside the store so legacy
    /// MVVM surfaces (Settings/Home views consuming `@EnvironmentObject`)
    /// keep working until `p0-tca-14` (#677) decommissions them.
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
#endif
        var initialState = AppFeature.State()
        initialState.hasSeenOnboarding = UserDefaults.standard.bool(
            forKey: AppStorageKey.hasSeenOnboarding
        )
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
#endif

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .environmentObject(coordinator.settings)
                .environmentObject(coordinator)
                .task {
                    await store.send(.scheduling(.start)).finish()
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
    /// `#if DEBUG` ensures this backdoor is compiled out of Release builds
    /// (re: #350/#405).
    private func presentUITestOverlayIfNeeded() {
        Task { @MainActor in
            await Task.yield()
            if let type = appDelegate.consumeUITestOverlayType() {
                coordinator.handleNotification(for: type)
            }
        }
    }
#else
    private func presentUITestOverlayIfNeeded() {}
#endif
}
