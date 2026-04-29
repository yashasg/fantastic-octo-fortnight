/// DeviceActivityMonitor extension — called by the OS when a monitored
/// DeviceActivity interval starts or ends.
///
/// This stub compiles without the `com.apple.developer.family-controls`
/// entitlement. Actual shield application/removal via `ManagedSettingsStore`
/// requires:
///   1. FamilyControls entitlement approved (issue #201)
///   2. `DeviceActivityCenter.shared.startMonitoring(...)` invoked by the
///      main app after the user grants Family Controls authorization.
///
/// The principal class is registered via `Info.plist` (`NSExtensionPrincipalClass`).

import DeviceActivity
import ManagedSettings
import Foundation

// MARK: - DeviceActivityMonitorExtensionImpl

final class DeviceActivityMonitorExtensionImpl: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    // MARK: DeviceActivityMonitor overrides

    override func intervalDidStart(for activity: DeviceActivityName) {
        // TODO (#201): Apply app shield restrictions via store.shield.applications
        // when FamilyControls entitlement is provisioned.
        // Example (requires authorized ManagedSettingsStore):
        //   store.shield.applications = .all
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
        // TODO (#201): Handle threshold events (e.g. warn user break is ending).
    }
}
