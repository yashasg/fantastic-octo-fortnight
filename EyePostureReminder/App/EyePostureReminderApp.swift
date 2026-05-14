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
        var initialState = AppFeature.State()
        initialState.hasSeenOnboarding = UserDefaults.standard.bool(
            forKey: AppStorageKey.hasSeenOnboarding
        )
        self.store = Store(initialState: initialState) { AppFeature() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .environmentObject(coordinator.settings)
                .environmentObject(coordinator)
                .task {
                    await store.send(.scheduling(.start)).finish()
                }
                .onChange(of: scenePhase) { phase in
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
