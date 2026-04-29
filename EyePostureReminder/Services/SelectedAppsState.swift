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

    private let defaults: UserDefaults

    // MARK: Init

    /// Create a state object backed by `defaults`.
    ///
    /// - Parameter defaults: Defaults suite to read/write.  Defaults to the
    ///   shared App Group suite; pass an isolated suite in tests.
    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppGroupIPCKeys.appGroupID) ?? .standard
    ) {
        self.defaults = defaults
        isTrueInterruptEnabled = defaults.bool(forKey: SelectedAppsState.enabledKey)
        if let data = defaults.data(forKey: SelectedAppsState.metadataKey),
           let decoded = try? JSONDecoder().decode(SelectedAppsMetadata.self, from: data) {
            selectionMetadata = decoded
        } else {
            selectionMetadata = .empty
        }
    }

    // MARK: Mutations

    /// Toggle the user's intent to use True Interrupt Mode.
    func setEnabled(_ enabled: Bool) {
        isTrueInterruptEnabled = enabled
        defaults.set(enabled, forKey: SelectedAppsState.enabledKey)
    }

    /// Persist updated selection metadata (called after a real `FamilyActivityPicker` session).
    func updateMetadata(_ metadata: SelectedAppsMetadata) {
        selectionMetadata = metadata
        if let data = try? JSONEncoder().encode(metadata) {
            defaults.set(data, forKey: SelectedAppsState.metadataKey)
        }
    }

    /// Clear the selection and disable True Interrupt Mode.
    func clearSelection() {
        updateMetadata(.empty)
        setEnabled(false)
    }
}
