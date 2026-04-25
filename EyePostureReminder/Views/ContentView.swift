import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if hasSeenOnboarding {
            NavigationStack {
                HomeView()
            }
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    let coordinator = AppCoordinator()
    ContentView()
        .environmentObject(coordinator.settings)
        .environmentObject(coordinator)
}
