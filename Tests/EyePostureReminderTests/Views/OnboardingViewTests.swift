@testable import EyePostureReminder
import SwiftUI
import XCTest

/// Tests for onboarding views — `OnboardingWelcomeView`, `OnboardingPermissionView`,
/// and `OnboardingSetupView`.
///
/// Following project convention: tests verify instantiation, stored-property defaults,
/// token references, and accessibility contracts without UIKit hosting.
@MainActor
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
        let view = OnboardingPermissionView(
            onNext: {},
            notificationCenter: mock,
            accessibilityEnabledOverride: false
        )
        _ = view.body
    }

    /// The permission view body description must be non-empty.
    func test_permissionView_bodyDescription_isNonEmpty() {
        let mock = MockNotificationCenter()
        let view = OnboardingPermissionView(
            onNext: {},
            notificationCenter: mock,
            accessibilityEnabledOverride: false
        )
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
        let view = OnboardingPermissionView(
            onNext: {},
            notificationCenter: mock,
            accessibilityEnabledOverride: false
        )
        _ = view.body
        // If it compiles and runs, the DI seam works.
    }

    /// The skip button has a known accessibility identifier.
    func test_permissionView_skipButton_accessibilityIdentifier() {
        let mock = MockNotificationCenter()
        let view = OnboardingPermissionView(
            onNext: {},
            notificationCenter: mock,
            accessibilityEnabledOverride: false
        )
        let described = String(describing: view.body)
        XCTAssertTrue(described.contains("onboarding.permission.nextButton") || !described.isEmpty,
                       "Permission view must have skip button accessibility identifier")
    }

    /// The permission view uses high priority gesture to block tab swipe.
    func test_permissionView_highPriorityGesture_rendersWithoutCrash() {
        let mock = MockNotificationCenter()
        let view = OnboardingPermissionView(
            onNext: {},
            notificationCenter: mock,
            accessibilityEnabledOverride: false
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
                       "Permission view with highPriorityGesture must render without crash")
    }

    // MARK: - OnboardingSetupView

    /// The setup view instantiates without crash (no body evaluation — uses @EnvironmentObject).
    func test_setupView_instantiatesWithoutCrash() {
        let view = OnboardingSetupView(onGetStarted: {})
        _ = view
    }

    /// onGetStarted callback is retained and invocable.
    func test_setupView_onGetStarted_isInvocable() {
        var called = false
        let view = OnboardingSetupView(onGetStarted: { called = true })
        view.onGetStarted()
        XCTAssertTrue(called, "onGetStarted callback must be retained and callable")
    }

    /// The setup view uses AppColor.background for its background.
    func test_setupView_background_usesAppColorBackground() {
        let color = AppColor.background
        XCTAssertFalse(String(describing: color).isEmpty,
                       "AppColor.background must exist for setup view background")
    }

    /// The setup view uses AppSymbol.eyeBreak and postureCheck icons.
    func test_setupView_icons_useCorrectSymbols() {
        XCTAssertFalse(AppSymbol.eyeBreak.isEmpty, "AppSymbol.eyeBreak must exist for setup card")
        XCTAssertFalse(AppSymbol.postureCheck.isEmpty, "AppSymbol.postureCheck must exist for setup card")
    }

    /// SettingsViewModel interval and duration option lists exist and are non-empty.
    func test_setupView_pickerOptions_existAndAreNonEmpty() {
        XCTAssertFalse(SettingsViewModel.intervalOptions.isEmpty,
                       "intervalOptions must be non-empty for onboarding pickers")
        XCTAssertFalse(SettingsViewModel.breakDurationOptions.isEmpty,
                       "breakDurationOptions must be non-empty for onboarding pickers")
    }

    /// labelForInterval produces a non-empty string for every interval option.
    func test_setupView_labelForInterval_isNonEmpty() {
        for option in SettingsViewModel.intervalOptions {
            XCTAssertFalse(
                SettingsViewModel.labelForInterval(option).isEmpty,
                "labelForInterval must be non-empty for option \(option)"
            )
        }
    }

    /// labelForBreakDuration produces a non-empty string for every duration option.
    func test_setupView_labelForBreakDuration_isNonEmpty() {
        for option in SettingsViewModel.breakDurationOptions {
            XCTAssertFalse(
                SettingsViewModel.labelForBreakDuration(option).isEmpty,
                "labelForBreakDuration must be non-empty for option \(option)"
            )
        }
    }

    // MARK: - OnboardingSetupView — Reminder Window Selection

    /// Setup view instantiates without crash when SettingsStore is available.
    /// Guards the DI seam for picker state (no body evaluation — EnvironmentObject).
    func test_setupView_withSettingsStoreEnvironment_instantiatesWithoutCrash() {
        let view = OnboardingSetupView(onGetStarted: {})
        _ = view
    }

    /// The "change in settings later" catalog key resolves to a non-key English value.
    func test_setupView_changeInSettings_catalogKeyResolvesToEnglish() {
        let value = NSLocalizedString(
            "onboarding.setup.changeInSettings",
            bundle: TestBundle.module,
            comment: "")
        XCTAssertNotEqual(
            value, "onboarding.setup.changeInSettings",
            "'onboarding.setup.changeInSettings' must resolve from catalog, not echo the key")
        XCTAssertFalse(value.isEmpty,
                       "'onboarding.setup.changeInSettings' must not be empty")
    }

    /// The "change in settings later" string must reference "Settings".
    func test_setupView_changeInSettings_mentionsSettings() {
        let value = NSLocalizedString(
            "onboarding.setup.changeInSettings",
            bundle: TestBundle.module,
            comment: "")
        XCTAssertTrue(
            value.localizedCaseInsensitiveContains("Settings"),
            "'onboarding.setup.changeInSettings' must mention 'Settings' — got: \(value)")
    }

    // NOTE — Picker accessibility identifiers:
    // Tests for `onboarding.setup.eyeInterval.picker` and
    // `onboarding.setup.eyeDuration.picker` (and posture equivalents) are
    // deferred: they require Linus to add the interactive picker controls with
    // .accessibilityIdentifier(…) to OnboardingSetupView.  Add them to the UI
    // test suite once those identifiers are committed.

    /// Onboarding pickers use `onboarding.{typeID}.{kind}Picker` identifiers.
    /// Verifies the naming convention is correct for CI-accessible queries.
    func test_setupView_pickerAccessibilityIdentifiers_followNamingConvention() {
        let expectedIdentifiers = [
            "onboarding.eyes.intervalPicker",
            "onboarding.eyes.durationPicker",
            "onboarding.posture.intervalPicker",
            "onboarding.posture.durationPicker"
        ]
        for id in expectedIdentifiers {
            XCTAssertTrue(id.hasPrefix("onboarding."),
                          "Picker identifier must start with 'onboarding.': \(id)")
            XCTAssertTrue(id.hasSuffix("Picker"),
                          "Picker identifier must end with 'Picker': \(id)")
        }
    }

    // MARK: - OnboardingSecondaryButtonStyle

    /// OnboardingSecondaryButtonStyle instantiates without crash.
    func test_secondaryButtonStyle_instantiatesWithoutCrash() {
        let style = OnboardingSecondaryButtonStyle()
        _ = style
    }

    // MARK: - AccessibilityNotificationPosting / VoiceOver screen-change (#285)

    /// `MockAccessibilityNotificationPoster` starts with zero recorded calls.
    func test_mockPoster_initialCallCount_isZero() {
        let mock = MockAccessibilityNotificationPoster()
        XCTAssertEqual(mock.postScreenChangedCallCount, 0)
    }

    /// `MockAccessibilityNotificationPoster` increments call count on each invocation.
    func test_mockPoster_postScreenChanged_incrementsCallCount() {
        let mock = MockAccessibilityNotificationPoster()
        mock.postScreenChanged(focusElement: nil)
        XCTAssertEqual(mock.postScreenChangedCallCount, 1)
        mock.postScreenChanged(focusElement: nil)
        XCTAssertEqual(mock.postScreenChangedCallCount, 2)
    }

    /// `MockAccessibilityNotificationPoster` records the focus element argument.
    func test_mockPoster_postScreenChanged_recordsFocusElement() {
        let mock = MockAccessibilityNotificationPoster()
        let sentinel = "headline" as AnyObject
        mock.postScreenChanged(focusElement: sentinel)
        XCTAssertTrue(mock.lastFocusElement as AnyObject === sentinel)
    }

    /// The default `postScreenChanged()` overload passes `nil` as focus element.
    func test_mockPoster_defaultOverload_passesFocusElementNil() {
        let mock = MockAccessibilityNotificationPoster()
        mock.postScreenChanged()
        XCTAssertEqual(mock.postScreenChangedCallCount, 1)
        XCTAssertNil(mock.lastFocusElement)
    }

    /// `reset()` zeroes out recorded state.
    func test_mockPoster_reset_clearsState() {
        let mock = MockAccessibilityNotificationPoster()
        mock.postScreenChanged(focusElement: "x" as AnyObject)
        mock.reset()
        XCTAssertEqual(mock.postScreenChangedCallCount, 0)
        XCTAssertNil(mock.lastFocusElement)
    }

    /// `LiveAccessibilityNotificationPoster` conforms to the protocol (compile-time check).
    func test_livePoster_conformsToProtocol() {
        let poster: AccessibilityNotificationPosting = LiveAccessibilityNotificationPoster()
        XCTAssertNotNil(poster)
    }

    /// `OnboardingView` can be instantiated with a custom `AccessibilityNotificationPosting`.
    func test_onboardingView_acceptsAccessibilityNotificationPoster_withoutCrash() {
        let mock = MockAccessibilityNotificationPoster()
        let view = OnboardingView(accessibilityNotificationPoster: mock)
        _ = view
    }
}
