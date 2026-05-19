import Foundation

/// Process-level UI test mode detection (`#755` Phase E).
///
/// Inspects `CommandLine.arguments` for the onboarding-control launch
/// arguments XCUITest uses to drive deterministic launches. Consumers
/// (currently `AccessibleToggle`) only need this launch-argument check,
/// so a free-standing helper is sufficient.
///
/// `#if DEBUG` ensures the `CommandLine` inspection is compiled out of
/// Release/TestFlight builds, preventing accidental onboarding-state resets
/// in production (re: #350, #405).
enum UITestMode {

    /// `true` when the app was launched by XCUITest with one of the
    /// onboarding-control launch arguments. Used to suppress background
    /// services and to swap SwiftUI controls for UIKit-backed equivalents
    /// that XCUITest can reliably tap.
#if DEBUG
    static var isEnabled: Bool {
        resolve()
    }

    static func resolve(
        launchArguments: [String]? = nil,
        launchArgumentsProvider: () -> [String] = { CommandLine.arguments }
    ) -> Bool {
        let resolvedLaunchArguments = launchArguments ?? launchArgumentsProvider()
        return isUITestMode(launchArguments: resolvedLaunchArguments)
    }

    static func isUITestMode(launchArguments: [String]) -> Bool {
        launchArguments.contains("--skip-onboarding") ||
            launchArguments.contains("--reset-onboarding") ||
            launchArguments.contains("--show-overlay-eyes") ||
            launchArguments.contains("--show-overlay-posture") ||
            launchArguments.contains("--simulate-screen-time-not-determined") ||
            launchArguments.contains("--dismiss-true-interrupt-banner") ||
            launchArguments.contains("--show-true-interrupt-banner")
    }
#else
    static var isEnabled: Bool { false }

    static func resolve(
        launchArguments: [String]? = nil,
        launchArgumentsProvider: () -> [String] = { CommandLine.arguments }
    ) -> Bool {
        false
    }

    static func isUITestMode(launchArguments: [String]) -> Bool {
        false
    }
#endif
}
