/// ShieldConfiguration extension — provides the static UI shown when a kshana
/// break shield is active.
///
/// This stub compiles without the `com.apple.developer.family-controls`
/// entitlement. Runtime shield rendering requires:
///   1. FamilyControls entitlement approved (issue #201)
///   2. App Group provisioning profile including `group.com.yashasgujjar.kshana`
///
/// The principal class is registered via `Info.plist` (`NSExtensionPrincipalClass`).
/// `ShieldConfigurationDataSource` is an ObjC-rooted class; Swift subclasses are
/// automatically visible to the ObjC runtime without `@objc`.

import Foundation
import ManagedSettings
import ManagedSettingsUI

// MARK: - ShieldConfigurationDataSourceImpl

final class ShieldConfigurationDataSourceImpl: ShieldConfigurationDataSource {

    // MARK: ShieldConfigurationDataSource overrides

    override func configuration(
        shielding application: Application
    ) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain
    ) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeConfiguration()
    }

    // MARK: Private

    private func makeConfiguration() -> ShieldConfiguration {
        let suite = UserDefaults(suiteName: ShieldSessionKeys.appGroupID)
        let reasonRaw = suite?.string(forKey: ShieldSessionKeys.breakReason) ?? ""
        let (title, subtitle) = copy(for: reasonRaw)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: .white)
        )
    }

    private func copy(for reasonRaw: String) -> (String, String) {
        switch reasonRaw {
        case "eyes":
            return ("Eye Break", "Look 20 feet away for 20 seconds.")
        case "posture":
            return ("Posture Break", "Stand up and stretch.")
        default:
            return ("Break Time", "Take a moment to rest.")
        }
    }
}
