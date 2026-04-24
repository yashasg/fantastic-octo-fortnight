import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            SettingsView()
        }
    }
}

#Preview {
    let coordinator = AppCoordinator()
    ContentView()
        .environmentObject(coordinator.settings)
        .environmentObject(coordinator)
}
