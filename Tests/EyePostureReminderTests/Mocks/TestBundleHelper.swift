@testable import EyePostureReminder
import Foundation
import UIKit

/// Resolves the EyePostureReminder module's resource bundle for use in tests.
///
/// In SPM, compiled resources live in a separate `{Package}_{Target}.bundle` that is
/// embedded alongside (but distinct from) the code bundle. `Bundle.module` inside
/// production code resolves to that resource bundle at compile time via a generated
/// accessor, but test code importing `@testable import EyePostureReminder` gets the
/// *test* target's `.module` instead. This helper locates the production resource bundle
/// by walking the candidates that SPM uses at runtime.
enum TestBundle {
    /// The EyePostureReminder module's resource bundle.
    ///
    /// Equivalent to what `Bundle.module` resolves to inside production code.
    /// Use this anywhere a test needs `UIColor(named:in:)`, `NSLocalizedString(_:bundle:)`,
    /// or `Bundle` URL lookups against main-module resources.
    static let module: Bundle = {
        // Bundle that contains the SettingsStore class (production code bundle).
        let codeBundle = Bundle(for: SettingsStore.self)

        // SPM names resource bundles "{PackageName}_{TargetName}.bundle".
        let resourceBundleName = "EyePostureReminder_EyePostureReminder"

        // Candidate directories where SPM may place the resource bundle.
        let candidates: [URL] = [
            codeBundle.resourceURL,
            codeBundle.bundleURL,
            Bundle.main.resourceURL,
            Bundle.main.bundleURL
        ].compactMap { $0 }

        for candidate in candidates {
            let bundleURL = candidate.appendingPathComponent(resourceBundleName + ".bundle")
            if let bundle = Bundle(url: bundleURL) {
                return bundle
            }
        }

        // Fallback: the code bundle itself carries resources in some Xcode configurations.
        return codeBundle
    }()
}

// MARK: - Convenience helpers

extension TestBundle {
    /// Looks up a named color from the main module's asset catalog.
    ///
    /// - Parameter name: The asset-catalog color name (e.g. `"ReminderBlue"`).
    /// - Returns: The `UIColor` if found; `nil` otherwise.
    static func testColor(named name: String) -> UIColor? {
        UIColor(named: name, in: module, compatibleWith: nil)
    }

    /// Returns the localized string for `key` from the main module's string catalog.
    ///
    /// - Parameters:
    ///   - key: The localization key.
    ///   - value: Default value returned when the key is absent (default: `""`).
    /// - Returns: Localized string, or `value` if the key is not found.
    static func testLocalizedString(key: String, value: String = "") -> String {
        NSLocalizedString(key, bundle: module, value: value, comment: "")
    }
}
