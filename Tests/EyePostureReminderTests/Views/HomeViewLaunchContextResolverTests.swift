import UserNotifications
import XCTest

@testable import EyePostureReminder

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

    func test_notificationRecovery_whenGlobalEnabledAndNotificationsDenied_returnsTrue() {
        XCTAssertTrue(HomeView.shouldShowNotificationRecovery(
            globalEnabled: true,
            notificationAuthStatus: .denied
        ))
    }

    func test_notificationRecovery_whenGlobalDisabledAndNotificationsDenied_returnsFalse() {
        XCTAssertFalse(HomeView.shouldShowNotificationRecovery(
            globalEnabled: false,
            notificationAuthStatus: .denied
        ))
    }

    func test_notificationRecovery_whenNotificationsAuthorized_returnsFalse() {
        XCTAssertFalse(HomeView.shouldShowNotificationRecovery(
            globalEnabled: true,
            notificationAuthStatus: .authorized
        ))
    }

    func test_noRemindersConfigured_whenGlobalEnabledAndBothReminderTypesDisabled_returnsTrue() {
        XCTAssertTrue(HomeView.shouldShowNoRemindersConfigured(
            globalEnabled: true,
            eyesEnabled: false,
            postureEnabled: false
        ))
    }

    func test_noRemindersConfigured_whenGlobalDisabled_returnsFalse() {
        XCTAssertFalse(HomeView.shouldShowNoRemindersConfigured(
            globalEnabled: false,
            eyesEnabled: false,
            postureEnabled: false
        ))
    }

    func test_statusLocalizationKey_whenNoReminderTypesEnabled_returnsNoReminders() {
        XCTAssertEqual(
            HomeView.statusLocalizationKey(
                globalEnabled: true,
                eyesEnabled: false,
                postureEnabled: false,
                notificationAuthStatus: .authorized
            ),
            "home.status.noReminders"
        )
    }

    func test_statusLocalizationKey_whenNoRemindersAndNotificationsDenied_prefersNoReminders() {
        XCTAssertEqual(
            HomeView.statusLocalizationKey(
                globalEnabled: true,
                eyesEnabled: false,
                postureEnabled: false,
                notificationAuthStatus: .denied
            ),
            "home.status.noReminders"
        )
    }

    func test_statusLocalizationKey_whenOneReminderEnabledAndNotificationsDenied_returnsNotificationsOff() {
        XCTAssertEqual(
            HomeView.statusLocalizationKey(
                globalEnabled: true,
                eyesEnabled: true,
                postureEnabled: false,
                notificationAuthStatus: .denied
            ),
            "home.status.notificationsOff"
        )
    }
}
#endif
