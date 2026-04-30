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
    static let isUITestMode: Bool = CommandLine.arguments.contains("--skip-onboarding") ||
                                    CommandLine.arguments.contains("--reset-onboarding") ||
                                    CommandLine.arguments.contains("--show-overlay-eyes") ||
                                    CommandLine.arguments.contains("--show-overlay-posture") ||
                                    CommandLine.arguments.contains("--simulate-screen-time-not-determined")
#else
    static let isUITestMode: Bool = false
#endif
}
