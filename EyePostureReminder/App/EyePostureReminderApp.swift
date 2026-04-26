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
                }
        }
    }
}
