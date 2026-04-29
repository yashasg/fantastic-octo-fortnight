/// DeviceActivityMonitor extension — called by the OS when a monitored
/// DeviceActivity interval starts or ends.
///
/// This extension applies and removes `ManagedSettingsStore` shield restrictions
/// during a break session. It reads break context from the shared App Group
/// `UserDefaults` (`group.com.yashasgujjar.kshana`) so it can customise shield
/// behaviour without importing the main app module.
///
/// **Entitlement dependency:** Real shield application via `ManagedSettingsStore`
/// requires the `com.apple.developer.family-controls` entitlement (issue #201).
/// The structural scaffolding here (including `readSession(from:)`) is compile-safe
/// and can be exercised in any build; only the `store.shield` assignments are
/// entitlement-gated at runtime.
///
/// **Activation flow:**
/// 1. Main app calls `DeviceActivityCenter.shared.startMonitoring(...)` via
///    `DeviceActivityMonitorProviding.scheduleBreakMonitoring(for:)`.
/// 2. The OS calls `intervalDidStart(for:)` in this extension process.
/// 3. The extension reads the break session from the shared App Group and
///    applies `ManagedSettingsStore` restrictions.
/// 4. Main app calls `DeviceActivityCenter.shared.stopMonitoring(...)` via
///    `DeviceActivityMonitorProviding.cancelBreakMonitoring()` when the break ends.
/// 5. The OS calls `intervalDidEnd(for:)` — restrictions are cleared.
///
/// The principal class is registered via `Info.plist` (`NSExtensionPrincipalClass`).

import DeviceActivity
import Foundation
import ManagedSettings

// MARK: - DeviceActivityMonitorExtensionImpl

final class DeviceActivityMonitorExtensionImpl: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    /// Reads the active break session written by the main app before
    /// `DeviceActivityCenter.startMonitoring(...)` was called.
    ///
    /// Returns `nil` when the App Group key is absent or unreadable — callers should
    /// fall back to a generic shield rather than skipping restrictions entirely.
    ///
    /// - Parameter defaults: The App Group `UserDefaults` suite. Defaults to the
    ///   shared `group.com.yashasgujjar.kshana` suite.
    static func readSession(
        from defaults: UserDefaults? = UserDefaults(suiteName: ShieldSessionKeys.appGroupID)
    ) -> (reason: String?, durationSeconds: Double, triggeredAt: Date?) {
        let reason = defaults?.string(forKey: ShieldSessionKeys.breakReason)
        let duration = defaults?.double(forKey: ShieldSessionKeys.durationSeconds) ?? 0
        let timestamp = defaults?.object(forKey: ShieldSessionKeys.triggeredAt) as? Double
        let triggeredAt = timestamp.map { Date(timeIntervalSince1970: $0) }
        return (reason: reason, durationSeconds: duration, triggeredAt: triggeredAt)
    }

    // MARK: DeviceActivityMonitor overrides

    override func intervalDidStart(for activity: DeviceActivityName) {
        let session = DeviceActivityMonitorExtensionImpl.readSession()

        // Pending #201: Apply app shield restrictions based on the selected apps from
        // SelectedAppsState (written to the App Group by the main app after the user
        // configured True Interrupt Mode in the app/category picker).
        //
        // Example (requires authorized ManagedSettingsStore post-#201):
        //   if let reason = session.reason {
        //       // Apply restrictions — future: scope to user-selected apps/categories
        //       store.shield.applications = .all
        //       store.shield.webDomains = .all
        //   }
        _ = session  // Referenced to suppress "unused variable" warning pre-#201.
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        // Remove all shield restrictions when the break ends.
        // clearAllSettings() is safe to call even without FamilyControls at
        // compile time; it is a no-op until the entitlement is active.
        store.clearAllSettings()
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        // Pending #201: Handle threshold events (e.g. warn user break is ending soon).
    }
}
