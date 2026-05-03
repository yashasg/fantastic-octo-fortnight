@testable import EyePostureReminder
import XCTest

#if DEBUG
@MainActor
final class HomeViewLaunchContextResolverTests: XCTestCase {
    func test_resolver_withoutExplicitLaunchContext_usesInjectedProviders() {
        var launchArgumentsProviderCallCount = 0
        var processEnvironmentProviderCallCount = 0

        let result = HomeView.resolveShouldShowUITestScreenTimePrompt(
            launchArguments: nil,
            launchArgumentsProvider: {
                launchArgumentsProviderCallCount += 1
                return ["EyePostureReminderTests", "--simulate-screen-time-not-determined"]
            },
            processEnvironment: nil,
            processEnvironmentProvider: {
                processEnvironmentProviderCallCount += 1
                return [:]
            }
        )

        XCTAssertTrue(result)
        XCTAssertEqual(launchArgumentsProviderCallCount, 1)
        XCTAssertEqual(processEnvironmentProviderCallCount, 0)
    }

    func test_resolver_withExplicitLaunchArguments_bypassesInjectedProvider() {
        var launchArgumentsProviderCallCount = 0
        var processEnvironmentProviderCallCount = 0

        let result = HomeView.resolveShouldShowUITestScreenTimePrompt(
            launchArguments: ["EyePostureReminderTests", "--simulate-screen-time-not-determined"],
            launchArgumentsProvider: {
                launchArgumentsProviderCallCount += 1
                return []
            },
            processEnvironment: [:],
            processEnvironmentProvider: {
                processEnvironmentProviderCallCount += 1
                return [:]
            }
        )

        XCTAssertTrue(result)
        XCTAssertEqual(launchArgumentsProviderCallCount, 0)
        XCTAssertEqual(processEnvironmentProviderCallCount, 0)
    }

    func test_resolver_withoutExplicitProcessEnvironment_usesInjectedProvider() {
        var processEnvironmentProviderCallCount = 0

        let result = HomeView.resolveShouldShowUITestScreenTimePrompt(
            launchArguments: ["EyePostureReminderTests"],
            processEnvironment: nil,
            processEnvironmentProvider: {
                processEnvironmentProviderCallCount += 1
                return ["UITEST_SCREEN_TIME_STATUS": "notDetermined"]
            }
        )

        XCTAssertTrue(result)
        XCTAssertEqual(processEnvironmentProviderCallCount, 1)
    }

    func test_resolver_withNoDebugLaunchContext_returnsFalse() {
        let result = HomeView.resolveShouldShowUITestScreenTimePrompt(
            launchArguments: ["EyePostureReminderTests"],
            processEnvironment: [:]
        )

        XCTAssertFalse(result)
    }
}
#endif
