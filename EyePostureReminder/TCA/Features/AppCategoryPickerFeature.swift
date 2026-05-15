import ComposableArchitecture
import Foundation
import ScreenTimeExtensionShared
#if canImport(UIKit)
import UIKit
#endif

/// Phase-1 reducer for the True Interrupt Mode app/category configuration
/// surface.
///
/// Tracks the Screen Time authorisation status, holds the latest
/// `AppGroupSelectionSnapshot` (sourced from `IPCClient.readSelection` /
/// `selectionChanges`), drives the authorisation request flow, and routes
/// the `denied` recovery path through iOS Settings. The parent `AppFeature`
/// is responsible for dismissing the destination on `.doneTapped` (e.g. by
/// clearing `state.destination`).
@Reducer
struct AppCategoryPickerFeature {
    @ObservableState
    struct State: Equatable {
        var authorizationStatus: ScreenTimeAuthorizationStatus = .unavailable
        var selection: AppGroupSelectionSnapshot = .empty
        var isLoadingSelection: Bool = false
        var lastError: String?
    }

    enum Action: Equatable {
        case onAppear
        case requestAuthorizationTapped
        case openSettingsTapped
        case selectionChanged(AppGroupSelectionSnapshot)
        case authorizationStatusChanged(ScreenTimeAuthorizationStatus)
        case doneTapped
    }

    @Dependency(\.screenTimeAuthorizationClient) var screenTimeAuthorizationClient
    @Dependency(\.openURL) var openURL

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoadingSelection = true
                // Selection persistence to App Group is owned by p0-tca-15 (#678) —
                // IPCClient surface is intentionally not extended here.
                state.selection = .empty
                state.isLoadingSelection = false
                return .run { send in
                    let status = await screenTimeAuthorizationClient.status()
                    await send(.authorizationStatusChanged(status))
                }

            case .requestAuthorizationTapped:
                return .run { send in
                    let status = await screenTimeAuthorizationClient.requestAuthorization()
                    await send(.authorizationStatusChanged(status))
                }

            case .openSettingsTapped:
                #if canImport(UIKit)
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                    return .none
                }
                return .run { _ in await openURL(settingsURL) }
                #else
                return .none
                #endif

            case .selectionChanged(let snapshot):
                state.selection = snapshot
                // Selection persistence to App Group is owned by p0-tca-15 (#678) —
                // IPCClient surface is intentionally not extended here.
                return .none

            case .authorizationStatusChanged(let status):
                state.authorizationStatus = status
                return .none

            case .doneTapped:
                return .none
            }
        }
    }
}
