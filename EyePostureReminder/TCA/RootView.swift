import ComposableArchitecture
import SwiftUI

/// Phase-0 root SwiftUI surface for the TCA migration of the Eye & Posture
/// Reminder app.
///
/// This view exists solely to give Phase 1 issues a concrete attachment
/// point for sheet, picker, and overlay presentations. Every destination
/// body deliberately renders `EmptyView()` for now — Phase 1 issues
/// (#668–#673) will replace each placeholder with the real SwiftUI body
/// when the corresponding feature reducer is filled in.
///
/// `RootView` is **not** wired into `EyePostureReminderApp.swift` yet.
/// Phase 2 issue `p0-tca-11` (#674) takes ownership of swapping it in for
/// the legacy MVVM `AppCoordinator` stack.
struct RootView: View {
    @Perception.Bindable var store: StoreOf<AppFeature>

    var body: some View {
        WithPerceptionTracking {
            Group {
                if store.hasSeenOnboarding {
                    EmptyView()
                } else {
                    EmptyView()
                }
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.settingsSheet,
                    action: \.destination.settingsSheet
                )
            ) { _ in
                EmptyView()
            }
            .fullScreenCover(
                item: $store.scope(
                    state: \.destination?.appCategoryPicker,
                    action: \.destination.appCategoryPicker
                )
            ) { _ in
                EmptyView()
            }
            .fullScreenCover(
                item: $store.scope(state: \.$overlay, action: \.overlay)
            ) { _ in
                EmptyView()
            }
        }
    }
}

#Preview {
    RootView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
