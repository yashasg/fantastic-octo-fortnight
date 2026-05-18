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
/// `AppGroupSelectionSnapshot` (hydrated on `.onAppear` from
/// `IPCClient.readSelection` and persisted on `.selectionChanged` via
/// `IPCClient.writeSelection`; see #894), drives the authorisation request
/// flow, and routes the `denied` recovery path through iOS Settings. The
/// parent `AppFeature` is responsible for dismissing the destination on
/// `.doneTapped` (e.g. by clearing `state.destination`).
///
/// Subscribing to `IPCClient.selectionChanges` for live cross-process
/// updates is intentionally deferred — it requires a `CancelID` and an
/// owning lifetime that we do not need until `FamilyControls` unblocks the
/// `FamilyActivityPicker` integration (#201).
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
    @Dependency(\.ipcClient) var ipcClient
    @Dependency(\.openURL) var openURL

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoadingSelection = true
                // Sequential read keeps `TestStore` receive ordering
                // deterministic (the selection snapshot is the first
                // action observed by parents that pin transitions).
                return .run { [ipcClient, screenTimeAuthorizationClient] send in
                    let snapshot = await ipcClient.readSelection()
                    await send(.selectionChanged(snapshot))
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
                let didChange = state.selection != snapshot
                state.selection = snapshot
                state.isLoadingSelection = false
                // Persist only on real transitions. `AppGroupIPCStore.writeSelection`
                // already dedupes broadcasts on equal payloads, but the reducer-
                // level guard keeps the effect free on hydration re-entries.
                guard didChange else { return .none }
                return .run { [ipcClient] _ in
                    _ = await ipcClient.writeSelection(snapshot)
                }

            case .authorizationStatusChanged(let status):
                state.authorizationStatus = status
                return .none

            case .doneTapped:
                return .none
            }
        }
    }
}
