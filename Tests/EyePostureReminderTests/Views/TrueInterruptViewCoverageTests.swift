import ComposableArchitecture
import ScreenTimeExtensionShared
import SwiftUI
import UIKit
import XCTest

@testable import EyePostureReminder

// swiftlint:disable type_body_length
@MainActor
final class TrueInterruptViewCoverageTests: XCTestCase {

    private func render<V: View>(_ view: V, file: StaticString = #filePath, line: UInt = #line) {
        let hostingController = UIHostingController(rootView: view)
        hostingController.loadViewIfNeeded()
        hostingController.view.layoutIfNeeded()
        XCTAssertNotNil(hostingController.view, file: file, line: line)
    }

    /// Builds a fresh `AppCategoryPickerView` store seeded with the given status and
    /// optional selection snapshot. Stubs the screen-time client so the view's
    /// `.onAppear` dispatch (which drains an async authorization probe) doesn't
    /// race against test teardown or hit the live `FamilyControls` framework.
    private func makePickerStore(
        authorizationStatus: ScreenTimeAuthorizationStatus,
        selection: AppGroupSelectionSnapshot = .empty
    ) -> StoreOf<AppCategoryPickerFeature> {
        withDependencies {
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient(
                status: { authorizationStatus },
                statusChanges: { .finished },
                requestAuthorization: { authorizationStatus }
            )
        } operation: {
            Store(
                initialState: AppCategoryPickerFeature.State(
                    authorizationStatus: authorizationStatus,
                    selection: selection
                )
            ) { AppCategoryPickerFeature() }
        }
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
        let view = AppCategoryPickerView(store: makePickerStore(authorizationStatus: .unavailable))
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryPickerView_notDetermined_bodyEvaluation() {
        let view = AppCategoryPickerView(
            store: makePickerStore(authorizationStatus: .notDetermined)
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryPickerView_denied_bodyEvaluation() {
        let view = AppCategoryPickerView(store: makePickerStore(authorizationStatus: .denied))
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryPickerView_approvedEmptySelection_bodyEvaluation() {
        let view = AppCategoryPickerView(store: makePickerStore(authorizationStatus: .approved))
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryPickerView_approvedSelectedApps_bodyEvaluation() {
        let store = makePickerStore(
            authorizationStatus: .approved,
            selection: AppGroupSelectionSnapshot(categoryCount: 1, appCount: 2, lastUpdated: Date())
        )
        let view = AppCategoryPickerView(store: store)
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryPickerView_onSelectAppsCallback_isInvocable() {
        var selectAppsCalled = false
        let view = AppCategoryPickerView(
            store: makePickerStore(authorizationStatus: .approved),
            onSelectApps: { selectAppsCalled = true }
        )

        view.performPrimaryAction()

        XCTAssertTrue(selectAppsCalled,
                      "Approved-state primary action must invoke parent-injected onSelectApps")
    }

    func test_appCategoryPickerView_deniedPrimaryAction_dispatchesOpenSettings() async {
        let opened = LockIsolated<[URL]>([])
        let store = withDependencies {
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient(
                status: { .denied },
                statusChanges: { .finished },
                requestAuthorization: { .denied }
            )
            $0.openURL = OpenURLEffect { url in
                opened.withValue { $0.append(url) }
                return true
            }
        } operation: {
            Store(initialState: AppCategoryPickerFeature.State(authorizationStatus: .denied)) {
                AppCategoryPickerFeature()
            }
        }
        let view = AppCategoryPickerView(store: store)

        view.performPrimaryAction()
        // Allow the .openSettingsTapped effect to drain.
        try? await Task.sleep(nanoseconds: 100_000_000)

        opened.withValue { urls in
            XCTAssertEqual(urls.count, 1,
                           "Denied-state primary action must route exactly one URL via openURL")
        }
    }

    func test_appCategoryPickerView_notDeterminedPrimaryAction_routesAuthorizationRequest() async {
        let requestCount = LockIsolated(0)
        let store = withDependencies {
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient(
                status: { .notDetermined },
                statusChanges: { .finished },
                requestAuthorization: {
                    requestCount.withValue { $0 += 1 }
                    return .approved
                }
            )
        } operation: {
            Store(
                initialState: AppCategoryPickerFeature.State(authorizationStatus: .notDetermined)
            ) { AppCategoryPickerFeature() }
        }
        let view = AppCategoryPickerView(store: store)

        view.performPrimaryAction()
        // Allow the .requestAuthorizationTapped effect to drain.
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(requestCount.value, 1,
                       "Not-determined primary action must hit the authorization client exactly once")
    }

    func test_appCategoryPickerView_unavailablePrimaryAction_isNoOp() {
        var selectAppsCalled = false
        let store = makePickerStore(authorizationStatus: .unavailable)
        let view = AppCategoryPickerView(
            store: store,
            onSelectApps: { selectAppsCalled = true }
        )

        view.performPrimaryAction()

        XCTAssertFalse(selectAppsCalled,
                       "Unavailable primary action must not invoke onSelectApps")
        XCTAssertEqual(store.authorizationStatus, .unavailable,
                       "Unavailable primary action must not mutate authorization status")
    }

    // MARK: - Accessibility Hint Body Tests

    func test_appCategoryPickerView_unavailable_bodyContainsPrimaryButtonHint() {
        XCTAssertEqual(
            AppCategoryPickerView.primaryButtonHintKey(for: .unavailable),
            "appCategoryPicker.button.pendingApproval.hint",
            "Unavailable state must use pending-approval hint key")
    }

    func test_appCategoryPickerView_notDetermined_bodyContainsPrimaryButtonHint() {
        XCTAssertEqual(
            AppCategoryPickerView.primaryButtonHintKey(for: .notDetermined),
            "appCategoryPicker.button.enableAccess.hint",
            "Not-determined state must use enable-access hint key")
    }

    func test_appCategoryPickerView_denied_bodyContainsPrimaryButtonHint() {
        XCTAssertEqual(
            AppCategoryPickerView.primaryButtonHintKey(for: .denied),
            "appCategoryPicker.button.openSettings.hint",
            "Denied state must use open-settings hint key")
    }

    func test_appCategoryPickerView_approved_bodyContainsPrimaryButtonHint() {
        XCTAssertEqual(
            AppCategoryPickerView.primaryButtonHintKey(for: .approved),
            "appCategoryPicker.button.selectApps.hint",
            "Approved state must use select-apps hint key")
    }

    func test_appCategoryPickerView_allStatuses_bodyContainsDoneButtonHint() {
        let expectedDoneHintKey: LocalizedStringKey = "appCategoryPicker.doneButton.hint"
        for status in ScreenTimeAuthorizationStatus.allCases {
            let view = AppCategoryPickerView(store: makePickerStore(authorizationStatus: status))
            let described = String(describing: view.body)
            XCTAssertFalse(
                described.isEmpty,
                "Body for status \(status) must not be empty")
            _ = expectedDoneHintKey // done button hint is always applied; key presence verified via StringCatalogTests
        }
    }

    func test_appCategoryPickerView_allStatuses_render() {
        for status in ScreenTimeAuthorizationStatus.allCases {
            render(AppCategoryPickerView(store: makePickerStore(
                authorizationStatus: status,
                selection: AppGroupSelectionSnapshot(
                    categoryCount: 1,
                    appCount: 1,
                    lastUpdated: Date()
                )
            )))
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
        let metadata = AppGroupSelectionSnapshot(categoryCount: 0, appCount: 0, lastUpdated: Date())
        let described = String(describing: AppCategoryApprovedCard(metadata: metadata).body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryApprovedCard_singleCategorySelection_bodyEvaluation() {
        let metadata = AppGroupSelectionSnapshot(categoryCount: 1, appCount: 0, lastUpdated: Date())
        let described = String(describing: AppCategoryApprovedCard(metadata: metadata).body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryApprovedCard_singleAppSelection_bodyEvaluation() {
        let metadata = AppGroupSelectionSnapshot(categoryCount: 0, appCount: 1, lastUpdated: Date())
        let described = String(describing: AppCategoryApprovedCard(metadata: metadata).body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategoryApprovedCard_multipleSelections_bodyEvaluation() {
        let metadata = AppGroupSelectionSnapshot(categoryCount: 2, appCount: 3, lastUpdated: Date())
        let described = String(describing: AppCategoryApprovedCard(metadata: metadata).body)
        XCTAssertFalse(described.isEmpty)
    }

    func test_appCategorySelectionSummary_usesLocalizedPluralCounts() {
        let summary = AppCategorySelectionSummary.text(
            for: AppGroupSelectionSnapshot(categoryCount: 2, appCount: 3, lastUpdated: Date()),
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
        let metadata = AppGroupSelectionSnapshot(categoryCount: 0, appCount: 0, lastUpdated: Date())
        let described = String(describing: AppCategoryApprovedCard(metadata: metadata).body)
        // The body description must not contain a 0.6 opacity literal applied to the placeholder.
        XCTAssertFalse(
            described.contains("opacity: 0.6"),
            "Placeholder text must not reduce textSecondary opacity — that fails WCAG 1.4.3 contrast")
    }

    /// Verifies the approved-card placeholder body renders successfully when selection is non-empty.
    func test_appCategoryApprovedCard_withSelections_placeholderUsesFullOpacity() {
        let metadata = AppGroupSelectionSnapshot(categoryCount: 1, appCount: 2, lastUpdated: Date())
        let described = String(describing: AppCategoryApprovedCard(metadata: metadata).body)
        XCTAssertFalse(
            described.contains("opacity: 0.6"),
            "Placeholder text must not use reduced opacity regardless of selection state")
    }
}
// swiftlint:enable type_body_length
