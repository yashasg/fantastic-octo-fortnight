import SwiftUI

@main
struct EyePostureReminderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var coordinator = AppCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    /// Tracks whether the previous `scenePhase` was `.background` so we only
    /// call `handleForegroundTransition()` on true background → foreground
    /// transitions, not on every brief `.inactive` interruption (e.g. task
    /// switcher, control centre).
    @State private var wasInBackground = false

    init() {
        AppTypography.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator.settings)
                .environmentObject(coordinator)
                .task {
                    await coordinator.scheduleReminders()
                }
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        presentUITestOverlayIfNeeded()
                        coordinator.presentPendingOverlayIfNeeded()
                        if wasInBackground {
                            wasInBackground = false
                            Task { await coordinator.handleForegroundTransition() }
                        }
                    case .background:
                        wasInBackground = true
                        coordinator.appWillResignActive()
                    default:
                        break
                    }
                }
                .onAppear {
                    appDelegate.coordinator = coordinator
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
