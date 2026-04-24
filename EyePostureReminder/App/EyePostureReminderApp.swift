import SwiftUI

@main
struct EyePostureReminderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var coordinator = AppCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator.settings)
                .environmentObject(coordinator)
                .task {
                    await coordinator.scheduleReminders()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        coordinator.presentPendingOverlayIfNeeded()
                    }
                }
                .onAppear {
                    appDelegate.coordinator = coordinator
                }
        }
    }
}
