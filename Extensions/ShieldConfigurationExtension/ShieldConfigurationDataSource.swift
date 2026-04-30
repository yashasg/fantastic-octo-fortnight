/// ShieldConfiguration extension — provides the static UI shown when a kshana
/// break shield is active.
///
/// This stub compiles without the `com.apple.developer.family-controls`
/// entitlement. Runtime shield rendering requires:
///   1. FamilyControls entitlement approved (issue #201)
///   2. App Group provisioning profile including `group.com.yashasg.kshana`
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
        let suite = AppGroupDefaults.resolve(consumer: "ShieldConfigurationDataSource")
        let snapshot = ShieldSessionSnapshot.read(from: suite)
        let copy = ShieldConfigurationCopy.make(for: snapshot)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            title: ShieldConfiguration.Label(text: copy.title, color: .white),
            subtitle: ShieldConfiguration.Label(text: copy.subtitle, color: .white)
        )
    }
}
