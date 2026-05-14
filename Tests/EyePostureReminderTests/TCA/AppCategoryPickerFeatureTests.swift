import ComposableArchitecture
import ScreenTimeExtensionShared
import XCTest

@testable import EyePostureReminder

/// `TestStore` baseline coverage for `AppCategoryPickerFeature` (Phase 1
/// reducer `p0-tca-9` / #672). Behavioural parity with the legacy
/// `SelectedAppsState` lives under Phase 2 issue `p0-tca-15` (#678) once the
/// IPC client surface is extended.
@MainActor
final class AppCategoryPickerFeatureTests: XCTestCase {

    // MARK: - Default state

    func test_state_init_defaultsAreUnauthorisedAndEmptySelection() {
        let state = AppCategoryPickerFeature.State()

        XCTAssertEqual(state.authorizationStatus, .unavailable)
        XCTAssertEqual(state.selection, .empty)
        XCTAssertFalse(state.isLoadingSelection)
        XCTAssertNil(state.lastError)
    }

    // MARK: - .onAppear

    func test_onAppear_clearsSelectionAndPollsAuthorisationStatus() async {
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        } withDependencies: {
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient(
                status: { .approved },
                statusChanges: { .finished },
                requestAuthorization: { .approved }
            )
        }

        await store.send(.onAppear)
        await store.receive(\.authorizationStatusChanged) {
            $0.authorizationStatus = .approved
        }
    }

    func test_onAppear_propagatesUnavailableStatus() async {
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        } withDependencies: {
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient(
                status: { .unavailable },
                statusChanges: { .finished },
                requestAuthorization: { .unavailable }
            )
        }

        await store.send(.onAppear)
        await store.receive(\.authorizationStatusChanged)
    }

    // MARK: - .requestAuthorizationTapped

    func test_requestAuthorizationTapped_routesThroughClientAndUpdatesState() async {
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        } withDependencies: {
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient(
                status: { .denied },
                statusChanges: { .finished },
                requestAuthorization: { .denied }
            )
        }

        await store.send(.requestAuthorizationTapped)
        await store.receive(\.authorizationStatusChanged) {
            $0.authorizationStatus = .denied
        }
    }

    // MARK: - .openSettingsTapped

    func test_openSettingsTapped_invokesOpenURL() async {
        let opened = LockIsolated<[URL]>([])

        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        } withDependencies: {
            $0.openURL = OpenURLEffect { url in
                opened.withValue { $0.append(url) }
                return true
            }
        }

        await store.send(.openSettingsTapped).finish()

        // UIApplication.openSettingsURLString — exact value is OS-defined; assert the
        // schema we routed to settings rather than equality on a private string.
        opened.withValue { urls in
            XCTAssertEqual(urls.count, 1, "openSettingsTapped must route exactly one URL")
            XCTAssertEqual(urls.first?.scheme, "app-settings",
                           "Settings URL scheme must be 'app-settings:'")
        }
    }

    // MARK: - .selectionChanged

    func test_selectionChanged_writesSnapshotOntoState() async {
        let snapshot = AppGroupSelectionSnapshot.empty
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        }

        await store.send(.selectionChanged(snapshot))
    }

    // MARK: - .authorizationStatusChanged

    func test_authorizationStatusChanged_setsApproved() async {
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        }

        await store.send(.authorizationStatusChanged(.approved)) {
            $0.authorizationStatus = .approved
        }
    }

    func test_authorizationStatusChanged_setsDenied() async {
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        }

        await store.send(.authorizationStatusChanged(.denied)) {
            $0.authorizationStatus = .denied
        }
    }

    // MARK: - .doneTapped

    func test_doneTapped_isPureNoOpAtFeatureLevel() async {
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        }

        await store.send(.doneTapped)
    }
}
