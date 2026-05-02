/// App Group–backed state for True Interrupt Mode app/category selection.
///
/// Persists lightweight selection metadata (no opaque `FamilyControls` tokens) to
/// the shared App Group `UserDefaults` so the main app and extension targets share
/// the same selection across process boundaries.
///
/// **Testability:** The initialiser accepts any `UserDefaults` instance so unit
/// tests can pass an isolated in-memory suite without requiring the real App Group
/// to exist (which demands a device + provisioning profile). Tests never touch the
/// real `group.com.yashasg.kshana` suite.
///
/// **Token serialisation:** `ApplicationToken` and `ActivityCategoryToken` values
/// from `FamilyControls` are opaque and not `Codable`. Only aggregate counts that
/// drive UI copy ("3 apps selected") are stored here. The real picker selection
/// (`FamilyActivitySelection`) will be written to the App Group as `Data` by the
/// main app target once #201 is resolved; the extension reads it via
/// `ManagedSettingsStore`.

import Combine
import Foundation
import os
import ScreenTimeExtensionShared

/// App-facing name for the shared App Group selection payload.
typealias SelectedAppsMetadata = AppGroupSelectionSnapshot

// MARK: - SelectedAppsIPCStoring

/// Minimal persistence interface required by `SelectedAppsState`.
/// Abstracted for testability without exposing the full `AppGroupIPCStore` API.
protocol SelectedAppsIPCStoring {
    var isAvailable: Bool { get }
    func readSelection() throws -> AppGroupSelectionSnapshot
    func isTrueInterruptEnabled() -> Bool
    @discardableResult func setTrueInterruptEnabled(_ enabled: Bool) -> Bool
    func writeSelection(_ snapshot: AppGroupSelectionSnapshot) throws
}

extension AppGroupIPCStore: SelectedAppsIPCStoring {}

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

    private let ipcStore: any SelectedAppsIPCStoring

    // MARK: Init

    /// Create a state object backed by `defaults`.
    ///
    /// - Parameter defaults: Defaults suite to read/write. Defaults to the
    ///   shared App Group suite; pass an isolated suite in tests. Passing `nil`
    ///   leaves extension-critical persistence unavailable instead of falling
    ///   back to standard defaults.
    convenience init(
        defaults: UserDefaults? = AppGroupDefaults.resolve(consumer: "SelectedAppsState")
    ) {
        self.init(ipcStore: AppGroupIPCStore(defaults: defaults))
    }

    /// Create a state object backed by an explicit IPC store (for testing).
    init(ipcStore: any SelectedAppsIPCStoring) {
        self.ipcStore = ipcStore

        // Distinguish a successful read-returning-empty from a read failure.
        // Only clean up the storedEnabled/empty inconsistency when the read
        // actually succeeded — a failed read cannot distinguish "no apps selected"
        // from "App Group store unavailable", and we must not permanently disable
        // True Interrupt Mode on a transient IPC error. Fixes #491.
        let readResult = Result { try ipcStore.readSelection() }
        let initialMetadata: SelectedAppsMetadata
        let readSucceeded: Bool
        switch readResult {
        case .success(let metadata):
            initialMetadata = metadata
            readSucceeded = true
        case .failure(let error):
            Logger.settings.error(
                "SelectedAppsState: failed to read App Group selection — True Interrupt state preserved: \(error.localizedDescription, privacy: .public)"
            )
            initialMetadata = .empty
            readSucceeded = false
        }

        selectionMetadata = initialMetadata
        let storedEnabled = ipcStore.isTrueInterruptEnabled()
        isTrueInterruptEnabled = storedEnabled && !initialMetadata.isEmpty

        // Only reconcile the "enabled but nothing selected" inconsistency when
        // the read succeeded — if it failed we cannot know whether the selection
        // is genuinely empty or merely unreadable.
        if readSucceeded && storedEnabled && initialMetadata.isEmpty {
            _ = ipcStore.setTrueInterruptEnabled(false)
        }
    }

    // MARK: Mutations

    /// Toggle the user's intent to use True Interrupt Mode.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        guard ipcStore.isAvailable else {
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
        do {
            try ipcStore.writeSelection(metadata)
        } catch {
            selectionMetadata = .empty
            isTrueInterruptEnabled = false
            _ = ipcStore.setTrueInterruptEnabled(false)
            return false
        }
        selectionMetadata = metadata
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
