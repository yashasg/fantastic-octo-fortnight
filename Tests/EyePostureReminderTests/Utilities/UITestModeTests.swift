import XCTest

@testable import EyePostureReminder

/// Tests for `UITestMode` — process-level XCUITest launch-argument detection
/// (`EyePostureReminder/Utilities/UITestMode.swift`).
///
/// The helper is the single source of truth that translates the onboarding-
/// control launch arguments XCUITest passes via `CommandLine.arguments` into a
/// boolean consumed by `AccessibleToggle` and `SchedulingFeature.isUITestMode`.
/// A typo or drift in the recognised argument list silently disables
/// deterministic UI tests on release-candidate builds, so each known argument
/// is asserted individually.
///
/// The static API is compiled into both DEBUG and CI configurations via
/// `SWIFT_ACTIVE_COMPILATION_CONDITIONS=CI` (see `scripts/build.sh`), so these
/// tests run in every CI lane.
final class UITestModeTests: XCTestCase {

    // MARK: - Recognised launch arguments

    func test_isUITestMode_returnsTrue_forSkipOnboardingArgument() {
        XCTAssertTrue(UITestMode.isUITestMode(launchArguments: ["--skip-onboarding"]))
    }

    func test_isUITestMode_returnsTrue_forResetOnboardingArgument() {
        XCTAssertTrue(UITestMode.isUITestMode(launchArguments: ["--reset-onboarding"]))
    }

    func test_isUITestMode_returnsTrue_forShowOverlayEyesArgument() {
        XCTAssertTrue(UITestMode.isUITestMode(launchArguments: ["--show-overlay-eyes"]))
    }

    func test_isUITestMode_returnsTrue_forShowOverlayPostureArgument() {
        XCTAssertTrue(UITestMode.isUITestMode(launchArguments: ["--show-overlay-posture"]))
    }

    func test_isUITestMode_returnsTrue_forSimulateScreenTimeNotDeterminedArgument() {
        XCTAssertTrue(
            UITestMode.isUITestMode(launchArguments: ["--simulate-screen-time-not-determined"]))
    }

    func test_isUITestMode_returnsTrue_forDismissTrueInterruptBannerArgument() {
        XCTAssertTrue(
            UITestMode.isUITestMode(launchArguments: ["--dismiss-true-interrupt-banner"]))
    }

    func test_isUITestMode_returnsTrue_forShowTrueInterruptBannerArgument() {
        XCTAssertTrue(UITestMode.isUITestMode(launchArguments: ["--show-true-interrupt-banner"]))
    }

    // MARK: - Negative cases

    func test_isUITestMode_returnsFalse_forEmptyArguments() {
        XCTAssertFalse(UITestMode.isUITestMode(launchArguments: []))
    }

    func test_isUITestMode_returnsFalse_forUnrelatedArguments() {
        XCTAssertFalse(
            UITestMode.isUITestMode(launchArguments: [
                "/path/to/EyePostureReminder.app",
                "-FIRDebugEnabled",
                "--unknown-flag"
            ]))
    }

    func test_isUITestMode_returnsFalse_forCaseMismatchedArgument() {
        // Production code uses exact string match (`Array.contains(_:)`), so
        // capitalisation drift must not silently enable UI-test mode.
        XCTAssertFalse(UITestMode.isUITestMode(launchArguments: ["--Skip-Onboarding"]))
        XCTAssertFalse(UITestMode.isUITestMode(launchArguments: ["--SKIP-ONBOARDING"]))
    }

    func test_isUITestMode_returnsFalse_forArgumentSubstring() {
        // A flag that merely *contains* a recognised argument as a substring
        // must not match — `contains(_:)` on `[String]` requires whole-element
        // equality.
        XCTAssertFalse(
            UITestMode.isUITestMode(launchArguments: ["--skip-onboarding-extended"]))
        XCTAssertFalse(UITestMode.isUITestMode(launchArguments: ["prefix--skip-onboarding"]))
    }

    // MARK: - Mixed arguments

    func test_isUITestMode_returnsTrue_whenKnownArgumentAppearsAmongOthers() {
        let mixed = [
            "/path/to/EyePostureReminder.app",
            "-FIRDebugEnabled",
            "--show-overlay-eyes",
            "--unrelated-flag"
        ]
        XCTAssertTrue(UITestMode.isUITestMode(launchArguments: mixed))
    }

    // MARK: - `resolve` parameter handling

    func test_resolve_withExplicitLaunchArguments_usesThemInsteadOfProvider() {
        var providerCalls = 0
        let result = UITestMode.resolve(
            launchArguments: ["--skip-onboarding"],
            launchArgumentsProvider: {
                providerCalls += 1
                return []
            })

        XCTAssertTrue(result, "Explicit launch arguments must take precedence")
        XCTAssertEqual(
            providerCalls, 0,
            "Provider must not be invoked when explicit arguments are supplied")
    }

    func test_resolve_withNilLaunchArguments_consultsProvider() {
        var providerCalls = 0
        let result = UITestMode.resolve(
            launchArguments: nil,
            launchArgumentsProvider: {
                providerCalls += 1
                return ["--reset-onboarding"]
            })

        XCTAssertTrue(result, "Provider-supplied recognised argument must enable UI-test mode")
        XCTAssertEqual(providerCalls, 1, "Provider must be invoked exactly once")
    }

    func test_resolve_withNilLaunchArguments_providerReturnsUnrelated_isFalse() {
        let result = UITestMode.resolve(
            launchArguments: nil,
            launchArgumentsProvider: { ["--unknown-flag"] })

        XCTAssertFalse(result)
    }
}
