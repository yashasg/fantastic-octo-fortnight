import ComposableArchitecture
import SwiftUI

/// Thin compatibility wrapper around `RootView`.
///
/// `#755` Phase D promotes `RootView` to the canonical TCA root surface (it
/// owns the onboarding gate, destination sheets, and overlay cover). This
/// wrapper is retained so existing test fixtures and a future
/// `EyePostureReminderApp.body` keep referencing a stable `ContentView(store:)`
/// entry point during the in-flight Phase D / Phase E migration. The wrapper
/// has no behaviour of its own — every responsibility (gating, presentation,
/// `@AppStorage` bridge) lives in `RootView`.
struct ContentView: View {
    @Perception.Bindable var store: StoreOf<AppFeature>

    var body: some View {
        RootView(store: store)
    }
}

#Preview {
    ContentView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
