/// App Group–backed state for True Interrupt Mode app/category selection.
///
/// Persists lightweight selection metadata (no opaque `FamilyControls` tokens) to
/// the shared App Group `UserDefaults` so the main app and extension targets share
/// the same selection across process boundaries.
///
/// **Testability:** The initialiser accepts any `UserDefaults` instance so unit
/// tests can pass an isolated in-memory suite without requiring the real App Group
/// to exist (which demands a device + provisioning profile). Tests never touch the
/// real `group.com.yashasgujjar.kshana` suite.
///
/// **Token serialisation:** `ApplicationToken` and `ActivityCategoryToken` values
/// from `FamilyControls` are opaque and not `Codable`. Only aggregate counts that
/// drive UI copy ("3 apps selected") are stored here. The real picker selection
/// (`FamilyActivitySelection`) will be written to the App Group as `Data` by the
/// main app target once #201 is resolved; the extension reads it via
/// `ManagedSettingsStore`.

import Combine
import Foundation
import ScreenTimeExtensionShared

// MARK: - SelectedAppsMetadata

/// Lightweight, `Codable` metadata describing a `FamilyActivitySelection`.
///
/// Safe to use in SPM unit tests without the FamilyControls entitlement.
struct SelectedAppsMetadata: Codable, Equatable, Sendable {
    /// Number of app categories included in the selection.
    var categoryCount: Int
    /// Number of individual apps included in the selection.
    var appCount: Int
    /// When the selection was last updated by the user.
    var lastUpdated: Date

    /// `true` when neither apps nor categories have been chosen.
    var isEmpty: Bool { categoryCount == 0 && appCount == 0 }

    /// Empty selection sentinel used as the default pre-configuration state.
    static let empty = SelectedAppsMetadata(
        categoryCount: 0,
        appCount: 0,
        lastUpdated: .distantPast
    )
}

// MARK: - SelectedAppsState

/// Observable store for the True Interrupt Mode app/category selection.
@MainActor
final class SelectedAppsState: ObservableObject {

    // MARK: App Group + Persistence Keys

    /// Shared App Group suite used by the main app and extension targets.
    static let appGroupSuiteName = AppGroupIPCKeys.appGroupID
    /// UserDefaults key for the serialised `SelectedAppsMetadata`.
    static let metadataKey = AppGroupIPCKeys.selectionMetadata
    /// UserDefaults key for the user's True Interrupt Mode enabled intent.
    static let enabledKey = AppGroupIPCKeys.trueInterruptEnabled

    // MARK: Published State

    @Published private(set) var selectionMetadata: SelectedAppsMetadata
    @Published private(set) var isTrueInterruptEnabled: Bool

    // MARK: Dependency

    private let defaults: UserDefaults?
    private let ipcStore: AppGroupIPCStore

    // MARK: Init

    /// Create a state object backed by `defaults`.
    ///
    /// - Parameter defaults: Defaults suite to read/write. Defaults to the
    ///   shared App Group suite; pass an isolated suite in tests. Passing `nil`
    ///   leaves extension-critical persistence unavailable instead of falling
    ///   back to standard defaults.
    init(
        defaults: UserDefaults? = AppGroupDefaults.resolve(consumer: "SelectedAppsState")
    ) {
        self.defaults = defaults
        ipcStore = AppGroupIPCStore(defaults: defaults)
        let initialMetadata: SelectedAppsMetadata
        if let data = defaults?.data(forKey: SelectedAppsState.metadataKey),
           let decoded = try? JSONDecoder().decode(SelectedAppsMetadata.self, from: data) {
            initialMetadata = decoded
        } else {
            initialMetadata = .empty
        }
        selectionMetadata = initialMetadata
        let storedEnabled = ipcStore.isTrueInterruptEnabled()
        isTrueInterruptEnabled = storedEnabled && !initialMetadata.isEmpty
        if storedEnabled && initialMetadata.isEmpty {
            _ = ipcStore.setTrueInterruptEnabled(false)
        }
    }

    // MARK: Mutations

    /// Toggle the user's intent to use True Interrupt Mode.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        guard defaults != nil else {
            isTrueInterruptEnabled = false
            return false
        }
        guard !enabled || !selectionMetadata.isEmpty else {
            isTrueInterruptEnabled = false
            _ = ipcStore.setTrueInterruptEnabled(false)
            return false
        }
        let didWrite = ipcStore.setTrueInterruptEnabled(enabled)
        isTrueInterruptEnabled = enabled && didWrite
        return didWrite
    }

    /// Persist updated selection metadata (called after a real `FamilyActivityPicker` session).
    @discardableResult
    func updateMetadata(_ metadata: SelectedAppsMetadata) -> Bool {
        guard let defaults else {
            selectionMetadata = .empty
            return false
        }
        guard let data = try? JSONEncoder().encode(metadata) else {
            selectionMetadata = .empty
            return false
        }
        selectionMetadata = metadata
        defaults.set(data, forKey: SelectedAppsState.metadataKey)
        if metadata.isEmpty {
            isTrueInterruptEnabled = false
            _ = ipcStore.setTrueInterruptEnabled(false)
        }
        return true
    }

    /// Clear the selection and disable True Interrupt Mode.
    @discardableResult
    func clearSelection() -> Bool {
        let didClearMetadata = updateMetadata(.empty)
        let didDisableTrueInterrupt = setEnabled(false)
        return didClearMetadata && didDisableTrueInterrupt
    }
}
