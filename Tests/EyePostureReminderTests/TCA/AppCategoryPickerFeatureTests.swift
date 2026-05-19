import ComposableArchitecture
import ScreenTimeExtensionShared
import XCTest

@testable import EyePostureReminder

/// `TestStore` baseline coverage for `AppCategoryPickerFeature` (Phase 1
/// reducer `p0-tca-9` / #672). Selection read/write wires through the
/// `IPCClient` dependency surface added in `p0-tca-15` / #678 and consumed
/// by the reducer in #894.
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

    func test_onAppear_hydratesFromIPCClientAndPollsAuthorisationStatus() async {
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        } withDependencies: {
            $0.ipcClient = TCATestDependencies.silentIPCClient()
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient(
                status: { .approved },
                statusChanges: { .finished },
                requestAuthorization: { .approved }
            )
        }

        await store.send(.onAppear) {
            $0.isLoadingSelection = true
        }
        await store.receive(\.selectionChanged) {
            $0.isLoadingSelection = false
        }
        await store.receive(\.authorizationStatusChanged) {
            $0.authorizationStatus = .approved
        }
    }

    func test_onAppear_seedsNonEmptySnapshotFromIPCClient() async {
        let persisted = AppGroupSelectionSnapshot(
            categoryCount: 2,
            appCount: 3,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let writeRecorder = LockIsolated<[AppGroupSelectionSnapshot]>([])
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        } withDependencies: {
            var client = TCATestDependencies.silentIPCClient()
            client.readSelection = { persisted }
            client.writeSelection = { snapshot in
                writeRecorder.withValue { $0.append(snapshot) }
                return true
            }
            $0.ipcClient = client
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient(
                status: { .approved },
                statusChanges: { .finished },
                requestAuthorization: { .approved }
            )
        }

        await store.send(.onAppear) {
            $0.isLoadingSelection = true
        }
        await store.receive(\.selectionChanged) {
            $0.selection = persisted
            $0.isLoadingSelection = false
        }
        await store.receive(\.authorizationStatusChanged) {
            $0.authorizationStatus = .approved
        }

        writeRecorder.withValue { recorded in
            XCTAssertEqual(
                recorded,
                [persisted],
                """
                Hydrating from .empty to a non-empty persisted snapshot must \
                round-trip through writeSelection so external listeners stay \
                in lock-step
                """
            )
        }
    }

    func test_onAppear_emptyPersistedSnapshot_doesNotWrite() async {
        let writeRecorder = LockIsolated<[AppGroupSelectionSnapshot]>([])
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        } withDependencies: {
            var client = TCATestDependencies.silentIPCClient()
            client.writeSelection = { snapshot in
                writeRecorder.withValue { $0.append(snapshot) }
                return true
            }
            $0.ipcClient = client
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient(
                status: { .unavailable },
                statusChanges: { .finished },
                requestAuthorization: { .unavailable }
            )
        }

        await store.send(.onAppear) {
            $0.isLoadingSelection = true
        }
        await store.receive(\.selectionChanged) {
            $0.isLoadingSelection = false
        }
        await store.receive(\.authorizationStatusChanged)

        writeRecorder.withValue { recorded in
            XCTAssertEqual(
                recorded,
                [],
                """
                Hydration from .empty → .empty must not re-write because writes \
                would re-trigger any subscribed selectionChanges streams
                """
            )
        }
    }

    func test_onAppear_propagatesUnavailableStatus() async {
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        } withDependencies: {
            $0.ipcClient = TCATestDependencies.silentIPCClient()
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient(
                status: { .unavailable },
                statusChanges: { .finished },
                requestAuthorization: { .unavailable }
            )
        }

        await store.send(.onAppear) {
            $0.isLoadingSelection = true
        }
        await store.receive(\.selectionChanged) {
            $0.isLoadingSelection = false
        }
        await store.receive(\.authorizationStatusChanged)
    }

    // MARK: - .requestAuthorizationTapped

    func test_requestAuthorizationTapped_routesThroughClientAndUpdatesState() async {
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        } withDependencies: {
            $0.ipcClient = TCATestDependencies.silentIPCClient()
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
            $0.ipcClient = TCATestDependencies.silentIPCClient()
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

    func test_selectionChanged_persistsNewSnapshotViaIPCClient() async {
        let snapshot = AppGroupSelectionSnapshot(
            categoryCount: 1,
            appCount: 2,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let writeRecorder = LockIsolated<[AppGroupSelectionSnapshot]>([])

        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        } withDependencies: {
            var client = TCATestDependencies.silentIPCClient()
            client.writeSelection = { snapshot in
                writeRecorder.withValue { $0.append(snapshot) }
                return true
            }
            $0.ipcClient = client
        }

        await store.send(.selectionChanged(snapshot)) {
            $0.selection = snapshot
        }
        await store.finish()

        writeRecorder.withValue { recorded in
            XCTAssertEqual(
                recorded,
                [snapshot],
                """
                .selectionChanged with a new snapshot must persist exactly \
                once through ipcClient.writeSelection
                """
            )
        }
    }

    func test_selectionChanged_unchangedSnapshot_doesNotPersist() async {
        let snapshot = AppGroupSelectionSnapshot(
            categoryCount: 1,
            appCount: 2,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let writeRecorder = LockIsolated<[AppGroupSelectionSnapshot]>([])

        let store = TestStore(
            initialState: AppCategoryPickerFeature.State(
                authorizationStatus: .approved,
                selection: snapshot,
                isLoadingSelection: false,
                lastError: nil
            )
        ) {
            AppCategoryPickerFeature()
        } withDependencies: {
            var client = TCATestDependencies.silentIPCClient()
            client.writeSelection = { snapshot in
                writeRecorder.withValue { $0.append(snapshot) }
                return true
            }
            $0.ipcClient = client
        }

        await store.send(.selectionChanged(snapshot))
        await store.finish()

        writeRecorder.withValue { recorded in
            XCTAssertEqual(
                recorded,
                [],
                """
                .selectionChanged with an unchanged snapshot must not \
                re-persist (defence against selectionChanges stream loops)
                """
            )
        }
    }

    // MARK: - .authorizationStatusChanged

    func test_authorizationStatusChanged_setsApproved() async {
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        } withDependencies: {
            $0.ipcClient = TCATestDependencies.silentIPCClient()
        }

        await store.send(.authorizationStatusChanged(.approved)) {
            $0.authorizationStatus = .approved
        }
    }

    func test_authorizationStatusChanged_setsDenied() async {
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        } withDependencies: {
            $0.ipcClient = TCATestDependencies.silentIPCClient()
        }

        await store.send(.authorizationStatusChanged(.denied)) {
            $0.authorizationStatus = .denied
        }
    }

    // MARK: - .doneTapped

    func test_doneTapped_isPureNoOpAtFeatureLevel() async {
        let store = TestStore(initialState: AppCategoryPickerFeature.State()) {
            AppCategoryPickerFeature()
        } withDependencies: {
            $0.ipcClient = TCATestDependencies.silentIPCClient()
        }

        await store.send(.doneTapped)
    }
}
