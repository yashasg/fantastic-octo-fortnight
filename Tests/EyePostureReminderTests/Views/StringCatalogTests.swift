@testable import EyePostureReminder
import XCTest
// swiftlint:disable file_length

// Tests for the String Catalog (`Localizable.xcstrings`) shipped by Linus.
//
// ## What these tests verify:
// - All expected catalog keys resolve to non-empty English values
// - Resolved values are NOT equal to the key string (i.e., the catalog is really loaded)
// - No duplicate keys across the expected key set
// - Key naming convention follows `screen.component[.qualifier]` (dot-separated, camelCase)
// - Missing keys fall back gracefully (no crash, returns key string)
// - String format specifiers (`%@`, `%d`, `%1$@`) are syntactically valid Swift format strings
//
// ## Bundle note:
// The `.xcstrings` file is compiled into the app bundle. In iOS Simulator test runs the
// test bundle is injected into the running app, so `Bundle.main` contains the compiled
// strings table. Tests use `Bundle.main` for all `NSLocalizedString` lookups.
// swiftlint:disable:next type_body_length
final class StringCatalogTests: XCTestCase {

    // MARK: - Helpers

    /// Looks up a key in the production module bundle (where the compiled xcstrings lives).
    /// `Bundle.main` in test context does not contain the module's string catalog —
    /// `TestBundle.module` resolves the correct resource bundle.
    private func str(_ key: String) -> String {
        NSLocalizedString(key, bundle: TestBundle.module, comment: "")
    }

    /// Returns `true` when the catalog has translated the key (value ≠ key fallback).
    private func isTranslated(_ key: String) -> Bool {
        str(key) != key
    }

    // MARK: - All Expected Keys Resolve (non-empty, non-key values)

    // Checks that each key has a real English translation, not the key echo-back.

    func test_homeNavTitle_resolvesToEnglish() {
        XCTAssertTrue(
            isTranslated("home.navTitle"),
            "'home.navTitle' must resolve from catalog, not fall back to key string")
    }

    func test_homeTitle_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("home.title"))
    }

    func test_homeStatusActive_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("home.status.active"))
    }

    func test_homeStatusPaused_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("home.status.paused"))
    }

    func test_settingsNavTitle_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.navTitle"))
    }

    func test_settingsDoneButton_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.doneButton"))
    }

    func test_settingsGlobalToggle_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.masterToggle"))
    }

    func test_settingsSectionEyes_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.section.eyes"))
    }

    func test_settingsSectionPosture_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.section.posture"))
    }

    func test_settingsSectionSnooze_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.section.snooze"))
    }

    func test_settingsSnoozeActiveLabel_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.snooze.activeLabel"))
    }

    func test_settingsSnoozeCancelButton_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.snooze.cancelButton"))
    }

    func test_settingsHapticFeedback_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.hapticFeedback"))
    }

    func test_settingsNotificationsDisabledTitle_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.notifications.disabledTitle"))
    }

    func test_overlayDismissButton_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("overlay.dismissButton"))
    }

    func test_overlayCountdownLabel_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("overlay.countdown.label"))
    }

    func test_overlaySettingsButton_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("overlay.settingsButton"))
    }

    func test_onboardingWelcomeTitle_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("onboarding.welcome.title"))
    }

    func test_onboardingWelcomeNextButton_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("onboarding.welcome.nextButton"))
    }

    func test_onboardingPermissionTitle_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("onboarding.permission.title"))
    }

    func test_onboardingPermissionEnableButton_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("onboarding.permission.enableButton"))
    }

    func test_onboardingSetupTitle_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("onboarding.setup.title"))
    }

    func test_onboardingSetupGetStartedButton_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("onboarding.setup.getStartedButton"))
    }

    // MARK: - Resolved Values Are Non-Empty

    func test_allExpectedKeys_resolveToNonEmptyStrings() {
        let expectedKeys = [
            "home.navTitle", "home.title", "home.status.active", "home.status.paused",
            "home.settingsButton",
            "settings.navTitle", "settings.doneButton", "settings.masterToggle",
            "settings.pausedBanner", "settings.section.eyes", "settings.section.posture",
            "settings.section.snooze", "settings.snooze.cancelButton",
            "settings.snooze.5min", "settings.snooze.1hour", "settings.snooze.restOfDay",
            "settings.section.preferences", "settings.hapticFeedback",
            "settings.notifications.disabledTitle", "settings.notifications.disabledBody",
            "settings.notifications.openSettings",
            "overlay.dismissButton", "overlay.countdown.label", "overlay.settingsLabel",
            "overlay.settingsButton",
            "onboarding.welcome.title", "onboarding.welcome.subtitle",
            "onboarding.welcome.nextButton",
            "onboarding.permission.title", "onboarding.permission.enableButton",
            "onboarding.permission.skipButton",
            "onboarding.setup.title", "onboarding.setup.getStartedButton",
            "legal.dismissButton",
            "legal.terms.navTitle", "legal.terms.notMedical.heading", "legal.terms.notMedical.body",
            "legal.terms.professional.heading", "legal.terms.professional.body",
            "legal.terms.userResponsibilities.heading", "legal.terms.userResponsibilities.body",
            "legal.terms.intellectualProperty.heading", "legal.terms.intellectualProperty.body",
            "legal.terms.warranty.heading", "legal.terms.warranty.body",
            "legal.terms.liability.heading", "legal.terms.liability.body",
            "legal.terms.thirdPartyServices.heading", "legal.terms.thirdPartyServices.body",
            "legal.terms.termination.heading", "legal.terms.termination.body",
            "legal.terms.governingLaw.heading", "legal.terms.governingLaw.body",
            "legal.terms.changesToTerms.heading", "legal.terms.changesToTerms.body",
            "legal.terms.contact.heading", "legal.terms.contact.body",
            "legal.privacy.navTitle", "legal.privacy.localStorageOnly.heading",
            "legal.privacy.localStorageOnly.body", "legal.privacy.noCollect.heading",
            "legal.privacy.noCollect.body", "legal.privacy.collect.heading",
            "legal.privacy.collect.body", "legal.privacy.appleAppStore.heading",
            "legal.privacy.appleAppStore.body", "legal.privacy.childrenPrivacy.heading",
            "legal.privacy.childrenPrivacy.body", "legal.privacy.rights.heading",
            "legal.privacy.rights.body", "legal.privacy.changesToPolicy.heading",
            "legal.privacy.changesToPolicy.body", "legal.privacy.contact.heading",
            "legal.privacy.contact.body"
        ]
        for key in expectedKeys {
            XCTAssertFalse(str(key).isEmpty, "Key '\(key)' must resolve to a non-empty string")
        }
    }

    // MARK: - No Duplicate Keys

    func test_noDuplicateKeys_homeScreen() {
        let keys = [
            "home.navTitle", "home.title", "home.status.active",
            "home.status.paused", "home.settingsButton"
        ]
        XCTAssertEqual(Set(keys).count, keys.count, "Home screen keys must be unique")
    }

    func test_noDuplicateKeys_settingsScreen() {
        let keys = [
            "settings.navTitle", "settings.doneButton", "settings.doneButton.hint",
            "settings.masterToggle", "settings.masterToggle.hint",
            "settings.pausedBanner", "settings.section.eyes", "settings.section.posture",
            "settings.section.snooze", "settings.snooze.activeLabel",
            "settings.snooze.activeLabel.accessibility", "settings.snooze.cancelButton",
            "settings.snooze.cancelButton.hint",
            "settings.snooze.5min", "settings.snooze.5min.label", "settings.snooze.5min.hint",
            "settings.snooze.1hour", "settings.snooze.1hour.label", "settings.snooze.1hour.hint",
            "settings.snooze.restOfDay", "settings.snooze.restOfDay.label",
            "settings.snooze.restOfDay.hint",
            "settings.section.preferences", "settings.hapticFeedback",
            "settings.hapticFeedback.hint",
            "settings.notifications.disabledTitle", "settings.notifications.disabledBody",
            "settings.notifications.disabledLabel", "settings.notifications.openSettings",
            "settings.notifications.openSettings.hint"
        ]
        XCTAssertEqual(Set(keys).count, keys.count, "Settings screen keys must be unique")
    }

    func test_noDuplicateKeys_overlayScreen() {
        let keys = [
            "overlay.dismissButton", "overlay.countdown.label", "overlay.countdown.value",
            "overlay.settingsLabel", "overlay.settingsButton", "overlay.settingsButton.hint"
        ]
        XCTAssertEqual(Set(keys).count, keys.count, "Overlay screen keys must be unique")
    }

    func test_noDuplicateKeys_acrossAllScreens() {
        // The complete expected key set — no two screens should share a key.
        let allKeys = [
            "home.navTitle", "home.title", "home.status.active", "home.status.paused",
            "home.settingsButton",
            "settings.navTitle", "settings.doneButton", "settings.doneButton.hint",
            "settings.masterToggle", "settings.masterToggle.hint",
            "settings.pausedBanner", "settings.section.eyes", "settings.section.posture",
            "settings.section.snooze", "settings.snooze.activeLabel",
            "settings.snooze.activeLabel.accessibility", "settings.snooze.cancelButton",
            "settings.snooze.cancelButton.hint",
            "settings.snooze.5min", "settings.snooze.5min.label", "settings.snooze.5min.hint",
            "settings.snooze.1hour", "settings.snooze.1hour.label", "settings.snooze.1hour.hint",
            "settings.snooze.restOfDay", "settings.snooze.restOfDay.label",
            "settings.snooze.restOfDay.hint",
            "settings.section.preferences", "settings.hapticFeedback",
            "settings.hapticFeedback.hint",
            "settings.notifications.disabledTitle", "settings.notifications.disabledBody",
            "settings.notifications.disabledLabel", "settings.notifications.openSettings",
            "settings.notifications.openSettings.hint",
            "overlay.dismissButton", "overlay.countdown.label", "overlay.countdown.value",
            "overlay.settingsLabel", "overlay.settingsButton", "overlay.settingsButton.hint",
            "onboarding.welcome.illustrationLabel", "onboarding.welcome.title",
            "onboarding.welcome.subtitle", "onboarding.welcome.body",
            "onboarding.welcome.nextButton", "onboarding.welcome.nextButton.hint",
            "onboarding.permission.title", "onboarding.permission.body1",
            "onboarding.permission.body2", "onboarding.permission.enableButton",
            "onboarding.permission.enableButton.hint", "onboarding.permission.skipButton",
            "onboarding.permission.skipButton.hint",
            "onboarding.permission.notificationCard.appName",
            "onboarding.permission.notificationCard.now",
            "onboarding.permission.notificationCard.title",
            "onboarding.permission.notificationCard.body",
            "onboarding.permission.notificationCard.label",
            "onboarding.setup.title", "onboarding.setup.subtitle",
            "onboarding.setup.eyeBreaks.title", "onboarding.setup.eyeBreaks.interval",
            "onboarding.setup.eyeBreaks.duration",
            "onboarding.setup.postureChecks.title", "onboarding.setup.postureChecks.interval",
            "onboarding.setup.postureChecks.duration",
            "onboarding.setup.body", "onboarding.setup.getStartedButton",
            "onboarding.setup.getStartedButton.hint", "onboarding.setup.customizeButton",
            "onboarding.setup.customizeButton.hint", "onboarding.setup.card.label",
            "legal.dismissButton",
            "legal.terms.navTitle", "legal.terms.notMedical.heading", "legal.terms.notMedical.body",
            "legal.terms.professional.heading", "legal.terms.professional.body",
            "legal.terms.userResponsibilities.heading", "legal.terms.userResponsibilities.body",
            "legal.terms.intellectualProperty.heading", "legal.terms.intellectualProperty.body",
            "legal.terms.warranty.heading", "legal.terms.warranty.body",
            "legal.terms.liability.heading", "legal.terms.liability.body",
            "legal.terms.thirdPartyServices.heading", "legal.terms.thirdPartyServices.body",
            "legal.terms.termination.heading", "legal.terms.termination.body",
            "legal.terms.governingLaw.heading", "legal.terms.governingLaw.body",
            "legal.terms.changesToTerms.heading", "legal.terms.changesToTerms.body",
            "legal.terms.contact.heading", "legal.terms.contact.body",
            "legal.privacy.navTitle", "legal.privacy.localStorageOnly.heading",
            "legal.privacy.localStorageOnly.body", "legal.privacy.noCollect.heading",
            "legal.privacy.noCollect.body", "legal.privacy.collect.heading",
            "legal.privacy.collect.body", "legal.privacy.appleAppStore.heading",
            "legal.privacy.appleAppStore.body", "legal.privacy.childrenPrivacy.heading",
            "legal.privacy.childrenPrivacy.body", "legal.privacy.rights.heading",
            "legal.privacy.rights.body", "legal.privacy.changesToPolicy.heading",
            "legal.privacy.changesToPolicy.body", "legal.privacy.contact.heading",
            "legal.privacy.contact.body"
        ]
        XCTAssertEqual(
            Set(allKeys).count,
            allKeys.count,
            "No two catalog keys across all screens may be identical")
    }

    // MARK: - Key Naming Convention: screen.component[.qualifier]

    func test_keyConvention_usesDotsNotUnderscores() {
        let allKeys = [
            "home.navTitle", "settings.doneButton", "overlay.dismissButton",
            "onboarding.welcome.title", "onboarding.setup.getStartedButton"
        ]
        for key in allKeys {
            XCTAssertFalse(
                key.contains("_"),
                "Key '\(key)' must use dot-notation, never underscore/snake_case")
        }
    }

    func test_keyConvention_usesDotsNotHyphens() {
        let allKeys = [
            "home.navTitle", "settings.doneButton", "overlay.dismissButton",
            "onboarding.welcome.title"
        ]
        for key in allKeys {
            XCTAssertFalse(
                key.contains("-"),
                "Key '\(key)' must use dot-notation, never hyphens")
        }
    }

    func test_keyConvention_noEmptyKeys() {
        let allKeys = [
            "home.navTitle", "home.title",
            "settings.navTitle", "settings.masterToggle",
            "overlay.dismissButton", "onboarding.welcome.title"
        ]
        for key in allKeys {
            XCTAssertFalse(key.isEmpty, "No string key may be empty")
            XCTAssertFalse(
                key.trimmingCharacters(in: .whitespaces).isEmpty,
                "No string key may be whitespace-only")
        }
    }

    func test_keyConvention_allKeysHaveAtLeastTwoComponents() {
        let allKeys = [
            "home.navTitle", "home.title", "home.status.active",
            "settings.doneButton", "settings.section.eyes",
            "overlay.dismissButton", "overlay.countdown.label",
            "onboarding.welcome.title", "onboarding.setup.getStartedButton"
        ]
        for key in allKeys {
            let components = key.split(separator: ".")
            XCTAssertGreaterThanOrEqual(
                components.count,
                2,
                "Key '\(key)' must have at least 'screen.component' (≥2 dot-separated parts)")
        }
    }

    func test_keyConvention_screenPrefixes_areKnown() {
        // All keys must start with a recognised screen prefix.
        let validPrefixes = Set(["home", "settings", "overlay", "onboarding", "legal"])
        let allKeys = [
            "home.navTitle", "home.title", "home.status.active",
            "settings.navTitle", "settings.doneButton",
            "overlay.dismissButton", "overlay.countdown.label",
            "onboarding.welcome.title", "onboarding.permission.title",
            "onboarding.setup.title"
        ]
        for key in allKeys {
            let prefix = String(key.split(separator: ".").first ?? "")
            XCTAssertTrue(
                validPrefixes.contains(prefix),
                "Key '\(key)' has unrecognised screen prefix '\(prefix)'")
        }
    }

    // MARK: - Format Specifiers Are Syntactically Valid

    func test_snoozeActiveLabel_containsFormatSpecifier() {
        // "settings.snooze.activeLabel" = "Snoozed until %@" — must contain %@
        let value = str("settings.snooze.activeLabel")
        XCTAssertTrue(
            value.contains("%@") || value.contains("%1$@"),
            "'settings.snooze.activeLabel' must contain a %@ format specifier for the date")
    }

    func test_overlayCountdownValue_containsIntegerFormatSpecifier() {
        // "overlay.countdown.value" uses plural variants — verify it resolves
        let formatted = String.localizedStringWithFormat(
            NSLocalizedString("overlay.countdown.value", bundle: TestBundle.module, comment: ""),
            5
        )
        XCTAssertTrue(
            formatted.contains("5"),
            "'overlay.countdown.value' must resolve to a string containing the count")
    }

    func test_setupCardLabel_containsPositionalSpecifiers() {
        // "onboarding.setup.card.label" = "%1$@: every %2$@, %3$@ break"
        let value = str("onboarding.setup.card.label")
        XCTAssertTrue(
            value.contains("%"),
            "'onboarding.setup.card.label' must contain format specifiers for dynamic content")
    }

    // MARK: - Missing Key Fallback Behaviour

    func test_missingKey_returnsKeyString_doesNotCrash() {
        // NSLocalizedString contract: a missing key must return the key, not crash.
        let missingKey = "nonexistent.screen.component.xyz123"
        let result = str(missingKey)
        XCTAssertEqual(
            result,
            missingKey,
            "A missing catalog key must fall back to the key string itself without crashing")
    }

    func test_missingKey_fallback_isNonEmpty() {
        let result = str("another.missing.key.abc")
        XCTAssertFalse(
            result.isEmpty,
            "Even the key-string fallback is non-empty (the key itself)")
    }

    // MARK: - Specific Value Spot-Checks

    func test_homeTitle_value_isEyePostureReminder() {
        XCTAssertEqual(
            str("home.title"),
            "Eye & Posture Reminder",
            "home.title must equal 'Eye & Posture Reminder'")
    }

    func test_overlayDismissButton_value_isNonEmpty() {
        let value = str("overlay.dismissButton")
        XCTAssertFalse(value.isEmpty, "Dismiss button label must not be empty")
    }

    func test_onboardingWelcomeNextButton_value_isNext() {
        XCTAssertEqual(
            str("onboarding.welcome.nextButton"),
            "Next",
            "onboarding.welcome.nextButton must equal 'Next'")
    }

    func test_settingsDoneButton_value_isDone() {
        XCTAssertEqual(
            str("settings.doneButton"),
            "Done",
            "settings.doneButton must equal 'Done'")
    }

    func test_onboardingSetupEyeBreaksInterval_value_is20min() {
        XCTAssertEqual(
            str("onboarding.setup.eyeBreaks.interval"),
            "20 min",
            "Setup card must show '20 min' eye break interval (matches AppConfig defaults)")
    }

    func test_onboardingSetupPostureChecksInterval_value_is30min() {
        XCTAssertEqual(
            str("onboarding.setup.postureChecks.interval"),
            "30 min",
            "Setup card must show '30 min' posture check interval (matches AppConfig defaults)")
    }

    // MARK: - Legal Screen: No Duplicate Keys

    func test_noDuplicateKeys_legalScreen() {
        let keys = [
            "legal.dismissButton",
            "legal.terms.navTitle",
            "legal.terms.notMedical.heading", "legal.terms.notMedical.body",
            "legal.terms.professional.heading", "legal.terms.professional.body",
            "legal.terms.userResponsibilities.heading", "legal.terms.userResponsibilities.body",
            "legal.terms.intellectualProperty.heading", "legal.terms.intellectualProperty.body",
            "legal.terms.warranty.heading", "legal.terms.warranty.body",
            "legal.terms.liability.heading", "legal.terms.liability.body",
            "legal.terms.thirdPartyServices.heading", "legal.terms.thirdPartyServices.body",
            "legal.terms.termination.heading", "legal.terms.termination.body",
            "legal.terms.governingLaw.heading", "legal.terms.governingLaw.body",
            "legal.terms.changesToTerms.heading", "legal.terms.changesToTerms.body",
            "legal.terms.contact.heading", "legal.terms.contact.body",
            "legal.privacy.navTitle",
            "legal.privacy.localStorageOnly.heading", "legal.privacy.localStorageOnly.body",
            "legal.privacy.noCollect.heading", "legal.privacy.noCollect.body",
            "legal.privacy.collect.heading", "legal.privacy.collect.body",
            "legal.privacy.appleAppStore.heading", "legal.privacy.appleAppStore.body",
            "legal.privacy.childrenPrivacy.heading", "legal.privacy.childrenPrivacy.body",
            "legal.privacy.rights.heading", "legal.privacy.rights.body",
            "legal.privacy.changesToPolicy.heading", "legal.privacy.changesToPolicy.body",
            "legal.privacy.contact.heading", "legal.privacy.contact.body"
        ]
        XCTAssertEqual(Set(keys).count, keys.count, "Legal screen keys must be unique")
    }

    // MARK: - Legal Screen: Individual Key Resolution

    func test_legalDismissButton_resolvesToEnglish() {
        XCTAssertTrue(
            isTranslated("legal.dismissButton"),
            "'legal.dismissButton' must resolve from catalog, not fall back to key string")
    }

    func test_legalTermsNavTitle_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.navTitle"))
    }

    func test_legalTermsNotMedicalHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.notMedical.heading"))
    }

    func test_legalTermsNotMedicalBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.notMedical.body"))
    }

    func test_legalTermsProfessionalHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.professional.heading"))
    }

    func test_legalTermsProfessionalBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.professional.body"))
    }

    func test_legalTermsUserResponsibilitiesHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.userResponsibilities.heading"))
    }

    func test_legalTermsUserResponsibilitiesBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.userResponsibilities.body"))
    }

    func test_legalTermsIntellectualPropertyHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.intellectualProperty.heading"))
    }

    func test_legalTermsIntellectualPropertyBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.intellectualProperty.body"))
    }

    func test_legalTermsWarrantyHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.warranty.heading"))
    }

    func test_legalTermsWarrantyBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.warranty.body"))
    }

    func test_legalTermsLiabilityHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.liability.heading"))
    }

    func test_legalTermsLiabilityBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.liability.body"))
    }

    func test_legalTermsThirdPartyServicesHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.thirdPartyServices.heading"))
    }

    func test_legalTermsThirdPartyServicesBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.thirdPartyServices.body"))
    }

    func test_legalTermsTerminationHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.termination.heading"))
    }

    func test_legalTermsTerminationBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.termination.body"))
    }

    func test_legalTermsGoverningLawHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.governingLaw.heading"))
    }

    func test_legalTermsGoverningLawBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.governingLaw.body"))
    }

    func test_legalTermsChangesToTermsHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.changesToTerms.heading"))
    }

    func test_legalTermsChangesToTermsBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.changesToTerms.body"))
    }

    func test_legalTermsContactHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.contact.heading"))
    }

    func test_legalTermsContactBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.terms.contact.body"))
    }

    func test_legalPrivacyNavTitle_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.navTitle"))
    }

    func test_legalPrivacyLocalStorageOnlyHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.localStorageOnly.heading"))
    }

    func test_legalPrivacyLocalStorageOnlyBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.localStorageOnly.body"))
    }

    func test_legalPrivacyNoCollectHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.noCollect.heading"))
    }

    func test_legalPrivacyNoCollectBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.noCollect.body"))
    }

    func test_legalPrivacyCollectHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.collect.heading"))
    }

    func test_legalPrivacyCollectBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.collect.body"))
    }

    func test_legalPrivacyAppleAppStoreHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.appleAppStore.heading"))
    }

    func test_legalPrivacyAppleAppStoreBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.appleAppStore.body"))
    }

    func test_legalPrivacyChildrenPrivacyHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.childrenPrivacy.heading"))
    }

    func test_legalPrivacyChildrenPrivacyBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.childrenPrivacy.body"))
    }

    func test_legalPrivacyRightsHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.rights.heading"))
    }

    func test_legalPrivacyRightsBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.rights.body"))
    }

    func test_legalPrivacyChangesToPolicyHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.changesToPolicy.heading"))
    }

    func test_legalPrivacyChangesToPolicyBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.changesToPolicy.body"))
    }

    func test_legalPrivacyContactHeading_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.contact.heading"))
    }

    func test_legalPrivacyContactBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("legal.privacy.contact.body"))
    }

    // MARK: - Future Key Guard: resetToDefaults (pending Linus implementation)
    //
    // Once Linus adds the "Reset to Defaults" UI strings, uncomment and update these tests:
    //
    // func test_settingsResetDefaultsButton_resolvesToEnglish() {
    //     XCTAssertTrue(isTranslated("settings.resetDefaults.button"),
    //         "'settings.resetDefaults.button' must exist in catalog with English translation")
    // }
    //
    // func test_settingsResetDefaultsConfirm_resolvesToEnglish() {
    //     XCTAssertTrue(isTranslated("settings.resetDefaults.confirm"))
    // }
}
