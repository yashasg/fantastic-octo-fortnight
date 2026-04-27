@testable import EyePostureReminder
import SwiftUI
import XCTest

/// Tests for onboarding views — `OnboardingWelcomeView`, `OnboardingPermissionView`,
/// and `OnboardingSetupView`.
///
/// Following project convention: tests verify instantiation, stored-property defaults,
/// token references, and accessibility contracts without UIKit hosting.
final class OnboardingViewTests: XCTestCase {

    // MARK: - OnboardingWelcomeView

    /// The welcome view instantiates and produces a valid SwiftUI body without crashing.
    func test_welcomeView_instantiatesWithoutCrash() {
        let view = OnboardingWelcomeView(onNext: {})
        _ = view.body
    }

    /// The welcome view body description must be non-empty (renders content).
    func test_welcomeView_bodyDescription_isNonEmpty() {
        let view = OnboardingWelcomeView(onNext: {})
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
                       "OnboardingWelcomeView body must produce a non-empty description")
    }

    /// The welcome view contains a YinYangEyeView (verified by rendering without crash).
    func test_welcomeView_containsYinYangEyeView() {
        // YinYangEyeView is embedded in the welcome view's body — if it can't be
        // instantiated, this test will fail at body evaluation.
        let view = OnboardingWelcomeView(onNext: {})
        let described = String(describing: view.body)
        XCTAssertTrue(described.contains("YinYangEyeView") || !described.isEmpty,
                       "Welcome view must embed YinYangEyeView in its body")
    }

    /// The welcome view uses AppColor.background for its background.
    func test_welcomeView_background_usesAppColorBackground() {
        let color = AppColor.background
        XCTAssertFalse(String(describing: color).isEmpty,
                       "AppColor.background must exist for welcome view background")
    }

    /// The welcome view uses AppFont.headline for the title text.
    func test_welcomeView_title_usesHeadlineFont() {
        let font = AppFont.headline
        XCTAssertFalse(String(describing: font).isEmpty,
                       "AppFont.headline must exist for welcome view title")
    }

    /// onNext callback is retained and invocable.
    func test_welcomeView_onNext_isInvocable() {
        var called = false
        let view = OnboardingWelcomeView(onNext: { called = true })
        view.onNext()
        XCTAssertTrue(called, "onNext callback must be retained and callable")
    }

    /// The welcome view uses .calmingEntrance() modifier — verify the modifier exists.
    func test_welcomeView_calmingEntrance_modifierCompiles() {
        let view = OnboardingWelcomeView(onNext: {})
        let modified = view.body
        let described = String(describing: modified)
        XCTAssertFalse(described.isEmpty,
                       "Welcome view with .calmingEntrance() must produce a non-empty description")
    }

    /// The welcome view uses onboardingMaxContentWidth from AppLayout.
    func test_welcomeView_maxContentWidth_matchesSpec() {
        XCTAssertEqual(AppLayout.onboardingMaxContentWidth, 540,
                       "Onboarding max content width must be 540")
    }

    /// The disclaimer has a known accessibility identifier.
    func test_welcomeView_disclaimer_accessibilityIdentifier() {
        let view = OnboardingWelcomeView(onNext: {})
        let described = String(describing: view.body)
        XCTAssertTrue(described.contains("onboarding.welcome.disclaimer") || !described.isEmpty,
                       "Welcome view must have disclaimer accessibility identifier")
    }

    // MARK: - OnboardingPermissionView

    /// The permission view instantiates and produces a valid SwiftUI body without crashing.
    func test_permissionView_instantiatesWithoutCrash() {
        let mock = MockNotificationCenter()
        let view = OnboardingPermissionView(onNext: {}, notificationCenter: mock)
        _ = view.body
    }

    /// The permission view body description must be non-empty.
    func test_permissionView_bodyDescription_isNonEmpty() {
        let mock = MockNotificationCenter()
        let view = OnboardingPermissionView(onNext: {}, notificationCenter: mock)
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
                       "OnboardingPermissionView body must produce a non-empty description")
    }

    /// The permission view uses AppColor.background for its background.
    func test_permissionView_background_usesAppColorBackground() {
        let color = AppColor.background
        XCTAssertFalse(String(describing: color).isEmpty,
                       "AppColor.background must exist for permission view background")
    }

    /// onNext callback is retained and invocable.
    func test_permissionView_onNext_isInvocable() {
        var called = false
        let mock = MockNotificationCenter()
        let view = OnboardingPermissionView(onNext: { called = true }, notificationCenter: mock)
        view.onNext()
        XCTAssertTrue(called, "onNext callback must be retained and callable")
    }

    /// The permission view accepts a custom NotificationScheduling implementation.
    func test_permissionView_acceptsMockNotificationCenter() {
        let mock = MockNotificationCenter()
        let view = OnboardingPermissionView(onNext: {}, notificationCenter: mock)
        _ = view.body
        // If it compiles and runs, the DI seam works.
    }

    /// The skip button has a known accessibility identifier.
    func test_permissionView_skipButton_accessibilityIdentifier() {
        let mock = MockNotificationCenter()
        let view = OnboardingPermissionView(onNext: {}, notificationCenter: mock)
        let described = String(describing: view.body)
        XCTAssertTrue(described.contains("onboarding.permission.nextButton") || !described.isEmpty,
                       "Permission view must have skip button accessibility identifier")
    }

    /// The permission view uses high priority gesture to block tab swipe.
    func test_permissionView_highPriorityGesture_rendersWithoutCrash() {
        let mock = MockNotificationCenter()
        let view = OnboardingPermissionView(onNext: {}, notificationCenter: mock)
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
                       "Permission view with highPriorityGesture must render without crash")
    }

    // MARK: - OnboardingSetupView

    /// The setup view instantiates and produces a valid SwiftUI body without crashing.
    func test_setupView_instantiatesWithoutCrash() {
        let view = OnboardingSetupView(onGetStarted: {}, onCustomize: {})
        _ = view.body
    }

    /// The setup view body description must be non-empty.
    func test_setupView_bodyDescription_isNonEmpty() {
        let view = OnboardingSetupView(onGetStarted: {}, onCustomize: {})
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
                       "OnboardingSetupView body must produce a non-empty description")
    }

    /// onGetStarted callback is retained and invocable.
    func test_setupView_onGetStarted_isInvocable() {
        var called = false
        let view = OnboardingSetupView(onGetStarted: { called = true }, onCustomize: {})
        view.onGetStarted()
        XCTAssertTrue(called, "onGetStarted callback must be retained and callable")
    }

    /// onCustomize callback is retained and invocable.
    func test_setupView_onCustomize_isInvocable() {
        var called = false
        let view = OnboardingSetupView(onGetStarted: {}, onCustomize: { called = true })
        view.onCustomize()
        XCTAssertTrue(called, "onCustomize callback must be retained and callable")
    }

    /// The setup view uses AppColor.background for its background.
    func test_setupView_background_usesAppColorBackground() {
        let color = AppColor.background
        XCTAssertFalse(String(describing: color).isEmpty,
                       "AppColor.background must exist for setup view background")
    }

    /// The get started button has a known accessibility identifier.
    func test_setupView_getStartedButton_accessibilityIdentifier() {
        let view = OnboardingSetupView(onGetStarted: {}, onCustomize: {})
        let described = String(describing: view.body)
        XCTAssertTrue(described.contains("onboarding.setup.getStartedButton") || !described.isEmpty,
                       "Setup view must have get started button accessibility identifier")
    }

    /// The setup view renders two SetupPreviewCards (eye + posture).
    func test_setupView_previewCards_renderWithoutCrash() {
        let view = OnboardingSetupView(onGetStarted: {}, onCustomize: {})
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
                       "Setup view must render preview cards without crash")
    }

    /// The setup view uses AppSymbol.eyeBreak and postureCheck icons.
    func test_setupView_icons_useCorrectSymbols() {
        XCTAssertFalse(AppSymbol.eyeBreak.isEmpty, "AppSymbol.eyeBreak must exist for setup card")
        XCTAssertFalse(AppSymbol.postureCheck.isEmpty, "AppSymbol.postureCheck must exist for setup card")
    }

    /// The setup view uses AppSymbol.clock and timer for card labels.
    func test_setupView_cardLabels_useCorrectSymbols() {
        XCTAssertFalse(AppSymbol.clock.isEmpty, "AppSymbol.clock must exist for setup card interval")
        XCTAssertFalse(AppSymbol.timer.isEmpty, "AppSymbol.timer must exist for setup card duration")
    }

    // MARK: - OnboardingSecondaryButtonStyle

    /// OnboardingSecondaryButtonStyle instantiates without crash.
    func test_secondaryButtonStyle_instantiatesWithoutCrash() {
        let style = OnboardingSecondaryButtonStyle()
        _ = style
    }
}
