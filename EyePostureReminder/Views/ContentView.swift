import ComposableArchitecture
import SwiftUI

/// Root SwiftUI surface that gates between `OnboardingView` and `HomeView`.
///
/// `p0-tca-11` (#674) wires this view to the TCA `Store` so the gate decision
/// reads from `AppFeature.State.hasSeenOnboarding`. The legacy
/// `@AppStorage(AppStorageKey.hasSeenOnboarding)` is bridged into the store
/// via `.onChange` so `OnboardingView`'s `UserDefaults` write (which still
/// owns persistence until `p0-tca-14`) propagates to the TCA state and flips
/// the gate without an MVVM-side observer.
///
/// `HomeView` is scoped onto `AppFeature.State.home` here as part of `#755`
/// Phase A. `OnboardingView` keeps its `@EnvironmentObject` graph until
/// Phase C migrates it onto `OnboardingFeature`.
struct ContentView: View {
    @Perception.Bindable var store: StoreOf<AppFeature>
    @AppStorage(AppStorageKey.hasSeenOnboarding) private var persistedHasSeenOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WithPerceptionTracking {
            ZStack {
                if store.hasSeenOnboarding {
                    NavigationStack {
                        HomeView(store: store.scope(state: \.home, action: \.home))
                    }
                    .transition(.opacity)
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
            .animation(
                reduceMotion ? nil : AppAnimation.onboardingTransition,
                value: store.hasSeenOnboarding
            )
            .onChangeCompat(of: persistedHasSeenOnboarding) { newValue in
                if store.hasSeenOnboarding != newValue {
                    store.send(.hasSeenOnboardingChanged(newValue))
                }
            }
        }
    }
}

#Preview {
    ContentView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
