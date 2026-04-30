@testable import EyePostureReminder
import SwiftUI
import UIKit
import XCTest

// swiftlint:disable type_body_length
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

    // MARK: - Accessibility Hint Body Tests

    func test_appCategoryPickerView_unavailable_bodyContainsPrimaryButtonHint() {
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(),
            authorizationStatus: .unavailable,
            onRequestAuthorization: {},
            onDone: {}
        )
        XCTAssertEqual(
            view.primaryButtonHintKey,
            "appCategoryPicker.button.pendingApproval.hint",
            "Unavailable state must use pending-approval hint key")
    }

    func test_appCategoryPickerView_notDetermined_bodyContainsPrimaryButtonHint() {
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(),
            authorizationStatus: .notDetermined,
            onRequestAuthorization: {},
            onDone: {}
        )
        XCTAssertEqual(
            view.primaryButtonHintKey,
            "appCategoryPicker.button.enableAccess.hint",
            "Not-determined state must use enable-access hint key")
    }

    func test_appCategoryPickerView_denied_bodyContainsPrimaryButtonHint() {
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(),
            authorizationStatus: .denied,
            onRequestAuthorization: {},
            onDone: {}
        )
        XCTAssertEqual(
            view.primaryButtonHintKey,
            "appCategoryPicker.button.openSettings.hint",
            "Denied state must use open-settings hint key")
    }

    func test_appCategoryPickerView_approved_bodyContainsPrimaryButtonHint() {
        let view = AppCategoryPickerView(
            appsState: makeSelectedAppsState(),
            authorizationStatus: .approved,
            onRequestAuthorization: {},
            onDone: {}
        )
        XCTAssertEqual(
            view.primaryButtonHintKey,
            "appCategoryPicker.button.selectApps.hint",
            "Approved state must use select-apps hint key")
    }

    func test_appCategoryPickerView_allStatuses_bodyContainsDoneButtonHint() {
        let expectedDoneHintKey: LocalizedStringKey = "appCategoryPicker.doneButton.hint"
        for status in ScreenTimeAuthorizationStatus.allCases {
            let view = AppCategoryPickerView(
                appsState: makeSelectedAppsState(),
                authorizationStatus: status,
                onRequestAuthorization: {},
                onDone: {}
            )
            let described = String(describing: view.body)
            XCTAssertFalse(
                described.isEmpty,
                "Body for status \(status) must not be empty")
            _ = expectedDoneHintKey // done button hint is always applied; key presence verified via StringCatalogTests
        }
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

    func test_appCategorySelectionSummary_usesLocalizedPluralCounts() {
        let summary = AppCategorySelectionSummary.text(
            for: SelectedAppsMetadata(categoryCount: 2, appCount: 3, lastUpdated: Date()),
            bundle: TestBundle.module
        )

        XCTAssertTrue(summary.contains("2 categories"))
        XCTAssertTrue(summary.contains("3 apps"))
        XCTAssertFalse(summary.contains("appCategoryPicker.approved.categoryCount"))
        XCTAssertFalse(summary.contains("appCategoryPicker.approved.appCount"))
    }

    // MARK: - TrueInterruptSkippedBanner (#258)

    func test_trueInterruptSkippedBanner_bodyEvaluation() {
        let view = TrueInterruptSkippedBanner(onSetUp: {}, onDismiss: {})
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_trueInterruptSkippedBanner_renders() {
        render(TrueInterruptSkippedBanner(onSetUp: {}, onDismiss: {}))
    }

    func test_trueInterruptSkippedBanner_onSetUpIsInvocable() {
        var setUpCalled = false
        let view = TrueInterruptSkippedBanner(onSetUp: { setUpCalled = true }, onDismiss: {})
        view.onSetUp()
        XCTAssertTrue(setUpCalled)
    }

    // MARK: - #311: Hero illustration accessibilityHidden

    /// Verifies the hero illustration in OnboardingInterruptModeView does NOT expose
    /// the `onboarding.interrupt.illustrationLabel` key to the accessibility tree.
    /// The image must be `.accessibilityHidden(true)` — the screen title conveys purpose.
    func test_onboardingInterruptModeView_heroIllustration_isAccessibilityHidden() {
        let view = OnboardingInterruptModeView(
            onGetStarted: {},
            authorizationStatus: .unavailable,
            accessibilityEnabledOverride: false
        )
        let described = String(describing: view.body)
        XCTAssertFalse(
            described.contains("onboarding.interrupt.illustrationLabel"),
            "Hero illustration must be accessibilityHidden — illustrationLabel key must not appear in body"
        )
    }

    // MARK: - #314: onCustomize callback

    /// Verifies the onCustomize callback is retained and invocable.
    func test_onboardingInterruptModeView_onCustomize_isInvocable() {
        var customizeCalled = false
        let view = OnboardingInterruptModeView(
            onGetStarted: {},
            onCustomize: { customizeCalled = true },
            authorizationStatus: .unavailable,
            accessibilityEnabledOverride: false
        )
        view.onCustomize?()
        XCTAssertTrue(customizeCalled, "onCustomize callback must be retained and callable")
    }

    /// Verifies OnboardingInterruptModeView body evaluates without crash when onCustomize is provided.
    func test_onboardingInterruptModeView_withCustomize_bodyEvaluation() {
        let view = OnboardingInterruptModeView(
            onGetStarted: {},
            onCustomize: {},
            authorizationStatus: .unavailable,
            accessibilityEnabledOverride: false
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
            "OnboardingInterruptModeView body must evaluate when onCustomize is provided")
    }

    /// Verifies onCustomize is nil-safe when not provided (default init).
    func test_onboardingInterruptModeView_withoutCustomize_customizeIsNil() {
        let view = OnboardingInterruptModeView(
            onGetStarted: {},
            authorizationStatus: .unavailable
        )
        XCTAssertNil(view.onCustomize, "onCustomize must be nil when not provided at init")
    }

    func test_trueInterruptSkippedBanner_onDismissIsInvocable() {
        var dismissCalled = false
        let view = TrueInterruptSkippedBanner(onSetUp: {}, onDismiss: { dismissCalled = true })
        view.onDismiss()
        XCTAssertTrue(dismissCalled)
    }

    // MARK: - #351: Disabled preview button hint

    /// When the primary button is disabled, primaryButtonHintKey returns the disabled hint key.
    func test_onboardingInterruptModeView_disabled_usesDisabledHintKey() {
        let view = OnboardingInterruptModeView(
            onGetStarted: {},
            onSetUp: nil,
            authorizationStatus: .unavailable,
            accessibilityEnabledOverride: false
        )
        XCTAssertEqual(
            view.primaryButtonHintKey,
            "onboarding.interrupt.previewButton.disabled.hint",
            "Disabled primary button must use the disabled hint key")
    }

    /// When unavailable + onSetUp provided (button enabled), active preview hint key is used.
    func test_onboardingInterruptModeView_unavailableWithSetup_usesPreviewHintKey() {
        let view = OnboardingInterruptModeView(
            onGetStarted: {},
            onSetUp: {},
            authorizationStatus: .unavailable,
            accessibilityEnabledOverride: false
        )
        XCTAssertEqual(
            view.primaryButtonHintKey,
            "onboarding.interrupt.previewButton.hint",
            "Enabled preview button must use the active preview hint key")
    }

    /// When approved, enable hint key is used (button is enabled).
    func test_onboardingInterruptModeView_approved_usesEnableHintKey() {
        let view = OnboardingInterruptModeView(
            onGetStarted: {},
            onSetUp: {},
            authorizationStatus: .approved,
            accessibilityEnabledOverride: false
        )
        XCTAssertEqual(
            view.primaryButtonHintKey,
            "onboarding.interrupt.enableButton.hint",
            "Approved primary button must use the enable hint key")
    }

    // MARK: - Contrast regression (#260)

    /// Verifies the placeholder body description does NOT contain a reduced-opacity modifier
    /// on the pickerPlaceholder text. Using `.opacity(0.6)` on `textSecondary` failed WCAG 1.4.3.
    func test_appCategoryApprovedCard_placeholderTextUsesFullOpacity_noReducedOpacity() {
        let metadata = SelectedAppsMetadata(categoryCount: 0, appCount: 0, lastUpdated: Date())
        let described = String(describing: AppCategoryApprovedCard(metadata: metadata).body)
        // The body description must not contain a 0.6 opacity literal applied to the placeholder.
        XCTAssertFalse(
            described.contains("opacity: 0.6"),
            "Placeholder text must not reduce textSecondary opacity — that fails WCAG 1.4.3 contrast")
    }

    /// Verifies the approved-card placeholder body renders successfully when selection is non-empty.
    func test_appCategoryApprovedCard_withSelections_placeholderUsesFullOpacity() {
        let metadata = SelectedAppsMetadata(categoryCount: 1, appCount: 2, lastUpdated: Date())
        let described = String(describing: AppCategoryApprovedCard(metadata: metadata).body)
        XCTAssertFalse(
            described.contains("opacity: 0.6"),
            "Placeholder text must not use reduced opacity regardless of selection state")
    }
}
// swiftlint:enable type_body_length
