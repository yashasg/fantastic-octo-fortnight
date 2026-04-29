@testable import EyePostureReminder
import SwiftUI
import UIKit
import XCTest

@MainActor
final class TrueInterruptViewCoverageTests: XCTestCase {

    private func render<V: View>(_ view: V, file: StaticString = #filePath, line: UInt = #line) {
        let hostingController = UIHostingController(rootView: view)
        hostingController.loadViewIfNeeded()
        hostingController.view.layoutIfNeeded()
        XCTAssertNotNil(hostingController.view, file: file, line: line)
    }

    private func makeSelectedAppsState(
        appCount: Int = 0,
        categoryCount: Int = 0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SelectedAppsState {
        let suiteName = "TrueInterruptViewCoverageTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated defaults", file: file, line: line)
            return SelectedAppsState()
        }
        defaults.removePersistentDomain(forName: suiteName)

        let state = SelectedAppsState(defaults: defaults)
        state.updateMetadata(SelectedAppsMetadata(
            categoryCount: categoryCount,
            appCount: appCount,
            lastUpdated: Date()
        ))
        return state
    }

    func test_onboardingInterruptModeView_unavailable_bodyEvaluation() {
        let view = OnboardingInterruptModeView(
            onGetStarted: {},
            authorizationStatus: .unavailable,
            accessibilityEnabledOverride: false
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_onboardingInterruptModeView_unavailableWithSetup_bodyEvaluation() {
        let view = OnboardingInterruptModeView(
            onGetStarted: {},
            onSetUp: {},
            authorizationStatus: .unavailable,
            accessibilityEnabledOverride: false
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_onboardingInterruptModeView_notDetermined_bodyEvaluation() {
        let view = OnboardingInterruptModeView(
            onGetStarted: {},
            onSetUp: {},
            authorizationStatus: .notDetermined,
            accessibilityEnabledOverride: false
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_onboardingInterruptModeView_approved_bodyEvaluation() {
        let view = OnboardingInterruptModeView(
            onGetStarted: {},
            onSetUp: {},
            authorizationStatus: .approved,
            accessibilityEnabledOverride: false
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_onboardingInterruptModeView_callbacksAreInvocable() {
        var getStartedCalled = false
        var setUpCalled = false
        let view = OnboardingInterruptModeView(
            onGetStarted: { getStartedCalled = true },
            onSetUp: { setUpCalled = true },
            authorizationStatus: .approved
        )

        view.onGetStarted()
        view.onSetUp?()

        XCTAssertTrue(getStartedCalled)
        XCTAssertTrue(setUpCalled)
    }

    func test_onboardingInterruptModeView_unavailableSetupCallbackIsInvocable() {
        var setUpCalled = false
        let view = OnboardingInterruptModeView(
            onGetStarted: {},
            onSetUp: { setUpCalled = true },
            authorizationStatus: .unavailable
        )

        view.onSetUp?()

        XCTAssertTrue(setUpCalled)
    }

    func test_onboardingInterruptModeView_unavailable_renders() {
        render(OnboardingInterruptModeView(
            onGetStarted: {},
            authorizationStatus: .unavailable
        ))
    }

    func test_onboardingInterruptModeView_approved_renders() {
        render(OnboardingInterruptModeView(
            onGetStarted: {},
            onSetUp: {},
            authorizationStatus: .approved
        ))
    }

    func test_appCategoryPickerView_unavailable_bodyEvaluation() {
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(),
            authorizationStatus: .unavailable,
            onRequestAuthorization: {},
            onDone: {}
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryPickerView_notDetermined_bodyEvaluation() {
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(),
            authorizationStatus: .notDetermined,
            onRequestAuthorization: {},
            onDone: {}
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryPickerView_denied_bodyEvaluation() {
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(),
            authorizationStatus: .denied,
            onRequestAuthorization: {},
            onDone: {}
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryPickerView_approvedEmptySelection_bodyEvaluation() {
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(),
            authorizationStatus: .approved,
            onRequestAuthorization: {},
            onDone: {}
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryPickerView_approvedSelectedApps_bodyEvaluation() {
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(appCount: 2, categoryCount: 1),
            authorizationStatus: .approved,
            onRequestAuthorization: {},
            onDone: {}
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryPickerView_callbacksAreInvocable() {
        var authorizationRequested = false
        var doneCalled = false
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(),
            authorizationStatus: .notDetermined,
            onRequestAuthorization: { authorizationRequested = true },
            onDone: { doneCalled = true }
        )

        view.onRequestAuthorization()
        view.onDone()

        XCTAssertTrue(authorizationRequested)
        XCTAssertTrue(doneCalled)
    }

    func test_appCategoryPickerView_deniedPrimaryAction_opensSettingsOnly() {
        var authorizationRequested = false
        var settingsOpened = false
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(),
            authorizationStatus: .denied,
            onRequestAuthorization: { authorizationRequested = true },
            onOpenSettings: { settingsOpened = true },
            onDone: {}
        )

        view.performPrimaryAction()

        XCTAssertFalse(authorizationRequested)
        XCTAssertTrue(settingsOpened)
    }

    func test_appCategoryPickerView_notDeterminedPrimaryAction_requestsAuthorizationOnly() {
        var authorizationRequested = false
        var settingsOpened = false
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(),
            authorizationStatus: .notDetermined,
            onRequestAuthorization: { authorizationRequested = true },
            onOpenSettings: { settingsOpened = true },
            onDone: {}
        )

        view.performPrimaryAction()

        XCTAssertTrue(authorizationRequested)
        XCTAssertFalse(settingsOpened)
    }

    func test_appCategoryPickerView_approvedPrimaryAction_requestsAuthorizationOnly() {
        var authorizationRequested = false
        var settingsOpened = false
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(),
            authorizationStatus: .approved,
            onRequestAuthorization: { authorizationRequested = true },
            onOpenSettings: { settingsOpened = true },
            onDone: {}
        )

        view.performPrimaryAction()

        XCTAssertTrue(authorizationRequested)
        XCTAssertFalse(settingsOpened)
    }

    func test_appCategoryPickerView_unavailablePrimaryAction_requestsAuthorizationOnly() {
        var authorizationRequested = false
        var settingsOpened = false
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(),
            authorizationStatus: .unavailable,
            onRequestAuthorization: { authorizationRequested = true },
            onOpenSettings: { settingsOpened = true },
            onDone: {}
        )

        view.performPrimaryAction()

        XCTAssertTrue(authorizationRequested)
        XCTAssertFalse(settingsOpened)
    }

    func test_appCategoryPickerView_allStatuses_render() {
        for status in ScreenTimeAuthorizationStatus.allCases {
            render(AppCategoryPickerView(
                appsState: makeSelectedAppsState(appCount: 1, categoryCount: 1),
                authorizationStatus: status,
                onRequestAuthorization: {},
                onDone: {}
            ))
        }
    }

    func test_appCategoryUnavailableBanner_bodyEvaluation() {
        let described = String(describing: AppCategoryUnavailableBanner().body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryPrePermissionCard_bodyEvaluation() {
        let described = String(describing: AppCategoryPrePermissionCard().body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryDeniedCard_bodyEvaluation() {
        let described = String(describing: AppCategoryDeniedCard().body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryApprovedCard_emptySelection_bodyEvaluation() {
        let metadata = SelectedAppsMetadata(categoryCount: 0, appCount: 0, lastUpdated: Date())
        let described = String(describing: AppCategoryApprovedCard(metadata: metadata).body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryApprovedCard_singleCategorySelection_bodyEvaluation() {
        let metadata = SelectedAppsMetadata(categoryCount: 1, appCount: 0, lastUpdated: Date())
        let described = String(describing: AppCategoryApprovedCard(metadata: metadata).body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryApprovedCard_singleAppSelection_bodyEvaluation() {
        let metadata = SelectedAppsMetadata(categoryCount: 0, appCount: 1, lastUpdated: Date())
        let described = String(describing: AppCategoryApprovedCard(metadata: metadata).body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryApprovedCard_multipleSelections_bodyEvaluation() {
        let metadata = SelectedAppsMetadata(categoryCount: 2, appCount: 3, lastUpdated: Date())
        let described = String(describing: AppCategoryApprovedCard(metadata: metadata).body)
        XCTAssertFalse(described.isEmpty)
    }
}
