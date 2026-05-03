/// UI Test Mode detection for `AppCoordinator`.
///
/// Isolated to its own file so that (a) `AppCoordinator.swift` stays within the
/// file-length SwiftLint budget and (b) the `#if DEBUG` guard is clearly visible.

import Foundation

extension AppCoordinator {

    // MARK: - UI Test Mode

    /// `true` when the app is launched by XCUITest with onboarding-control arguments.
    /// Used to suppress background services (timers, permission requests) that prevent
    /// the accessibility tree from settling between test interactions.
    ///
    /// `#if DEBUG` ensures this `CommandLine` inspection is compiled out of Release/TestFlight
    /// builds, preventing accidental onboarding state resets in production (re: #350/#405).
#if DEBUG
    static var isUITestMode: Bool {
        resolveIsUITestMode()
    }

    static func resolveIsUITestMode(
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
            launchArguments.contains("--simulate-screen-time-not-determined")
    }
#else
    static var isUITestMode: Bool { false }

    static func resolveIsUITestMode(
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
