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
            "settings.notificationFallback", "settings.notificationFallback.footer",
            "settings.notificationFallback.hint",
            "settings.notifications.disabledTitle", "settings.notifications.disabledBody",
            "settings.notifications.openSettings",
            "overlay.dismissButton", "overlay.countdown.label", "overlay.settingsLabel",
            "overlay.settingsButton", "overlay.doneButton",
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
            "legal.privacy.contact.body",
            // settings.resetToDefaults.* keys (6) — destructive confirmation dialog
            "settings.resetToDefaults", "settings.resetToDefaults.hint",
            "settings.resetToDefaults.cancel", "settings.resetToDefaults.confirmAction",
            "settings.resetToDefaults.confirmMessage", "settings.resetToDefaults.confirmTitle",
            // settings.reminder.* picker/toggle keys — shown on every SettingsView load
            "settings.reminder.durationPicker", "settings.reminder.durationPicker.hint",
            "settings.reminder.intervalPicker", "settings.reminder.intervalPicker.hint",
            "settings.reminder.section.footer",
            "settings.reminder.toggle.disabled.hint", "settings.reminder.toggle.enabled.hint",
            // settings.legal.* — legal section buttons and hints
            "settings.legal.privacy", "settings.legal.privacy.hint",
            "settings.legal.terms", "settings.legal.terms.hint",
            // settings section headers — about, advanced, legal
            "settings.section.about", "settings.section.advanced", "settings.section.legal",
            // settings.snooze.limitReached.hint — shown when snooze limit is reached
            "settings.snooze.limitReached.hint",
            // settings.masterToggle.footer — footer below master toggle
            "settings.masterToggle.footer",
            // settings.about.* — version string in About section
            "settings.about.versionFormat",
            // settings.feedback.* — send feedback button
            "settings.feedback.sendFeedback", "settings.feedback.sendFeedback.hint",
            // settings.picker.* — minute/second format strings in pickers
            "settings.picker.minuteFormat", "settings.picker.secondFormat",
            // overlay.dismissButton.hint — VoiceOver hint on overlay dismiss
            "overlay.dismissButton.hint",
            // home.settingsButton.hint — VoiceOver hint on home settings gear
            "home.settingsButton.hint",
            // onboarding.welcome.disclaimer
            "onboarding.welcome.disclaimer",
            // settings.smartPause.* keys (6) — added by Linus for Smart Pause feature
            "settings.section.smartPause",
            "settings.smartPause.footer",
            "settings.smartPause.pauseDuringFocus",
            "settings.smartPause.pauseDuringFocus.hint",
            "settings.smartPause.pauseWhileDriving",
            "settings.smartPause.pauseWhileDriving.hint",
            // reminder.* keys — notification/overlay text and supportive subtitles
            "reminder.eyes.title", "reminder.eyes.overlayTitle",
            "reminder.eyes.notificationTitle", "reminder.eyes.notificationBody",
            "reminder.eyes.overlaySupportiveText",
            "reminder.posture.title", "reminder.posture.overlayTitle",
            "reminder.posture.notificationTitle", "reminder.posture.notificationBody",
            "reminder.posture.overlaySupportiveText",
            // overlay.doneButton — primary CTA on redesigned overlay
            "overlay.doneButton"
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
            "settings.notificationFallback", "settings.notificationFallback.footer",
            "settings.notificationFallback.hint",
            "settings.notifications.disabledTitle", "settings.notifications.disabledBody",
            "settings.notifications.disabledLabel", "settings.notifications.openSettings",
            "settings.notifications.openSettings.hint",
            "settings.section.smartPause", "settings.smartPause.footer",
            "settings.smartPause.pauseDuringFocus", "settings.smartPause.pauseDuringFocus.hint",
            "settings.smartPause.pauseWhileDriving", "settings.smartPause.pauseWhileDriving.hint",
            // settings.resetToDefaults.* cluster — destructive confirmation dialog
            "settings.resetToDefaults", "settings.resetToDefaults.hint",
            "settings.resetToDefaults.cancel", "settings.resetToDefaults.confirmAction",
            "settings.resetToDefaults.confirmMessage", "settings.resetToDefaults.confirmTitle",
            // settings.reminder.* — picker/toggle strings visible on every SettingsView load
            "settings.reminder.durationPicker", "settings.reminder.durationPicker.hint",
            "settings.reminder.intervalPicker", "settings.reminder.intervalPicker.hint",
            "settings.reminder.section.footer",
            "settings.reminder.toggle.disabled.hint", "settings.reminder.toggle.enabled.hint",
            // settings.legal.* — legal section buttons
            "settings.legal.privacy", "settings.legal.privacy.hint",
            "settings.legal.terms", "settings.legal.terms.hint",
            // settings section headers and footers
            "settings.section.about", "settings.section.advanced", "settings.section.legal",
            "settings.snooze.limitReached.hint", "settings.masterToggle.footer",
            // settings.about, feedback, picker format strings
            "settings.about.versionFormat",
            "settings.feedback.sendFeedback", "settings.feedback.sendFeedback.hint",
            "settings.picker.minuteFormat", "settings.picker.secondFormat"
        ]
        XCTAssertEqual(Set(keys).count, keys.count, "Settings screen keys must be unique")
    }

    func test_noDuplicateKeys_overlayScreen() {
        let keys = [
            "overlay.dismissButton", "overlay.countdown.label", "overlay.countdown.value",
            "overlay.settingsLabel", "overlay.settingsButton", "overlay.settingsButton.hint",
            "overlay.doneButton"
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
            "settings.notificationFallback", "settings.notificationFallback.footer",
            "settings.notificationFallback.hint",
            "settings.notifications.disabledTitle", "settings.notifications.disabledBody",
            "settings.notifications.disabledLabel", "settings.notifications.openSettings",
            "settings.notifications.openSettings.hint",
            "overlay.dismissButton", "overlay.countdown.label", "overlay.countdown.value",
            "overlay.settingsLabel", "overlay.settingsButton", "overlay.settingsButton.hint",
            "overlay.doneButton",
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
            "onboarding.setup.eyeBreaks.title", "onboarding.setup.postureChecks.title",
            "onboarding.setup.picker.every", "onboarding.setup.picker.breakFor",
            "onboarding.setup.changeInSettings", "onboarding.setup.getStartedButton",
            "onboarding.setup.getStartedButton.hint", "onboarding.setup.card.label",
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
            "legal.privacy.contact.body",
            // settings.smartPause.* keys (6) — added by Linus for Smart Pause feature
            "settings.section.smartPause", "settings.smartPause.footer",
            "settings.smartPause.pauseDuringFocus", "settings.smartPause.pauseDuringFocus.hint",
            "settings.smartPause.pauseWhileDriving", "settings.smartPause.pauseWhileDriving.hint",
            // settings.resetToDefaults.* cluster — destructive confirmation dialog
            "settings.resetToDefaults", "settings.resetToDefaults.hint",
            "settings.resetToDefaults.cancel", "settings.resetToDefaults.confirmAction",
            "settings.resetToDefaults.confirmMessage", "settings.resetToDefaults.confirmTitle",
            // settings.reminder.* — picker/toggle strings
            "settings.reminder.durationPicker", "settings.reminder.durationPicker.hint",
            "settings.reminder.intervalPicker", "settings.reminder.intervalPicker.hint",
            "settings.reminder.section.footer",
            "settings.reminder.toggle.disabled.hint", "settings.reminder.toggle.enabled.hint",
            // settings.legal.*
            "settings.legal.privacy", "settings.legal.privacy.hint",
            "settings.legal.terms", "settings.legal.terms.hint",
            // settings section headers, footers, feedback, about
            "settings.section.about", "settings.section.advanced", "settings.section.legal",
            "settings.snooze.limitReached.hint", "settings.masterToggle.footer",
            "settings.about.versionFormat",
            "settings.feedback.sendFeedback", "settings.feedback.sendFeedback.hint",
            "settings.picker.minuteFormat", "settings.picker.secondFormat",
            // overlay hint and home settings button hint
            "overlay.dismissButton.hint", "home.settingsButton.hint",
            // onboarding.welcome.disclaimer
            "onboarding.welcome.disclaimer",
            // reminder.* keys — notification/overlay text and supportive subtitles
            "reminder.eyes.title", "reminder.eyes.overlayTitle",
            "reminder.eyes.notificationTitle", "reminder.eyes.notificationBody",
            "reminder.eyes.overlaySupportiveText",
            "reminder.posture.title", "reminder.posture.overlayTitle",
            "reminder.posture.notificationTitle", "reminder.posture.notificationBody",
            "reminder.posture.overlaySupportiveText"
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
        let validPrefixes = Set(["home", "settings", "overlay", "onboarding", "legal", "reminder"])
        let allKeys = [
            "home.navTitle", "home.title", "home.status.active",
            "settings.navTitle", "settings.doneButton",
            "settings.section.smartPause", "settings.smartPause.pauseDuringFocus",
            "overlay.dismissButton", "overlay.countdown.label",
            "onboarding.welcome.title", "onboarding.permission.title",
            "onboarding.setup.title",
            "reminder.eyes.notificationTitle", "reminder.posture.notificationTitle"
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

    func test_homeTitle_value_isKshana() {
        XCTAssertEqual(
            str("home.title"),
            "kshana",
            "home.title must equal 'kshana'")
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

    func test_onboardingSetupPickerEvery_resolvesToEnglish() {
        XCTAssertTrue(
            isTranslated("onboarding.setup.picker.every"),
            "'onboarding.setup.picker.every' must resolve from catalog (label for interval picker)")
    }

    func test_onboardingSetupPickerBreakFor_resolvesToEnglish() {
        XCTAssertTrue(
            isTranslated("onboarding.setup.picker.breakFor"),
            "'onboarding.setup.picker.breakFor' must resolve from catalog (label for duration picker)")
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

    // MARK: - settings.smartPause.* Keys: Individual Resolution

    func test_settingsSectionSmartPause_resolvesToEnglish() {
        XCTAssertTrue(
            isTranslated("settings.section.smartPause"),
            "'settings.section.smartPause' must resolve from catalog, not fall back to key string")
    }

    func test_settingsSmartPauseFooter_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.smartPause.footer"))
    }

    func test_settingsSmartPausePauseDuringFocus_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.smartPause.pauseDuringFocus"))
    }

    func test_settingsSmartPausePauseDuringFocusHint_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.smartPause.pauseDuringFocus.hint"))
    }

    func test_settingsSmartPausePauseWhileDriving_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.smartPause.pauseWhileDriving"))
    }

    func test_settingsSmartPausePauseWhileDrivingHint_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.smartPause.pauseWhileDriving.hint"))
    }

    // MARK: - settings.notificationFallback.* Keys: Individual Resolution

    func test_settingsNotificationFallback_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.notificationFallback"))
    }

    func test_settingsNotificationFallbackFooter_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.notificationFallback.footer"))
    }

    func test_settingsNotificationFallbackHint_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.notificationFallback.hint"))
    }

    // MARK: - reminder.* Keys: Individual Resolution

    func test_reminderEyesTitle_resolvesToEnglish() {
        XCTAssertTrue(
            isTranslated("reminder.eyes.title"),
            "'reminder.eyes.title' must resolve from catalog, not fall back to key string")
    }

    func test_reminderEyesOverlayTitle_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("reminder.eyes.overlayTitle"))
    }

    func test_reminderEyesNotificationTitle_resolvesToEnglish() {
        XCTAssertTrue(
            isTranslated("reminder.eyes.notificationTitle"),
            "'reminder.eyes.notificationTitle' must resolve — shown in system notification banners")
    }

    func test_reminderEyesNotificationBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("reminder.eyes.notificationBody"))
    }

    func test_reminderPostureTitle_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("reminder.posture.title"))
    }

    func test_reminderPostureOverlayTitle_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("reminder.posture.overlayTitle"))
    }

    func test_reminderPostureNotificationTitle_resolvesToEnglish() {
        XCTAssertTrue(
            isTranslated("reminder.posture.notificationTitle"),
            "'reminder.posture.notificationTitle' must resolve — shown in system notification banners")
    }

    func test_reminderPostureNotificationBody_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("reminder.posture.notificationBody"))
    }

    // MARK: - reminder.* Keys: No Duplicates

    func test_noDuplicateKeys_reminderKeys() {
        let keys = [
            "reminder.eyes.title", "reminder.eyes.overlayTitle",
            "reminder.eyes.notificationTitle", "reminder.eyes.notificationBody",
            "reminder.posture.title", "reminder.posture.overlayTitle",
            "reminder.posture.notificationTitle", "reminder.posture.notificationBody"
        ]
        XCTAssertEqual(Set(keys).count, keys.count, "Reminder keys must be unique")
    }

    // MARK: - settings.resetToDefaults.* Keys

    func test_settingsResetToDefaultsHint_resolvesToEnglish() {
        XCTAssertTrue(
            isTranslated("settings.resetToDefaults.hint"),
            "'settings.resetToDefaults.hint' must exist — VoiceOver pre-action hint for destructive button")
    }

    // MARK: - settings.resetToDefaults.* Spot-Checks (P1-1 fix)

    func test_settingsResetToDefaults_resolvesToEnglish() {
        XCTAssertTrue(
            isTranslated("settings.resetToDefaults"),
            "'settings.resetToDefaults' must resolve — button label in Advanced section")
    }

    func test_settingsResetToDefaultsConfirmTitle_resolvesToEnglish() {
        XCTAssertTrue(
            isTranslated("settings.resetToDefaults.confirmTitle"),
            "'settings.resetToDefaults.confirmTitle' must resolve — confirmation alert title")
    }

    func test_settingsResetToDefaultsConfirmAction_resolvesToEnglish() {
        XCTAssertTrue(
            isTranslated("settings.resetToDefaults.confirmAction"),
            "'settings.resetToDefaults.confirmAction' must resolve — destructive action label")
    }

    func test_settingsResetToDefaultsCancel_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.resetToDefaults.cancel"))
    }

    func test_settingsResetToDefaultsConfirmMessage_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.resetToDefaults.confirmMessage"))
    }

    // MARK: - settings.resetToDefaults.* No Duplicates

    func test_noDuplicateKeys_resetToDefaultsCluster() {
        let keys = [
            "settings.resetToDefaults", "settings.resetToDefaults.hint",
            "settings.resetToDefaults.cancel", "settings.resetToDefaults.confirmAction",
            "settings.resetToDefaults.confirmMessage", "settings.resetToDefaults.confirmTitle"
        ]
        XCTAssertEqual(Set(keys).count, keys.count, "resetToDefaults cluster keys must be unique")
    }

    // MARK: - P2-1 High-Risk Untested Keys (individual resolution)

    func test_settingsReminderDurationPicker_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.reminder.durationPicker"))
    }

    func test_settingsReminderDurationPickerHint_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.reminder.durationPicker.hint"))
    }

    func test_settingsReminderIntervalPicker_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.reminder.intervalPicker"))
    }

    func test_settingsReminderIntervalPickerHint_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.reminder.intervalPicker.hint"))
    }

    func test_settingsReminderSectionFooter_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.reminder.section.footer"))
    }

    func test_settingsReminderToggleDisabledHint_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.reminder.toggle.disabled.hint"))
    }

    func test_settingsReminderToggleEnabledHint_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.reminder.toggle.enabled.hint"))
    }

    func test_settingsLegalPrivacy_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.legal.privacy"))
    }

    func test_settingsLegalPrivacyHint_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.legal.privacy.hint"))
    }

    func test_settingsLegalTerms_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.legal.terms"))
    }

    func test_settingsLegalTermsHint_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.legal.terms.hint"))
    }

    func test_settingsSectionAbout_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.section.about"))
    }

    func test_settingsSectionAdvanced_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.section.advanced"))
    }

    func test_settingsSectionLegal_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.section.legal"))
    }

    func test_settingsSnoozeLimit_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.snooze.limitReached.hint"))
    }

    func test_settingsGlobalToggleFooter_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.masterToggle.footer"))
    }

    func test_settingsAboutVersionFormat_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.about.versionFormat"))
    }

    func test_settingsFeedbackSendFeedback_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.feedback.sendFeedback"))
    }

    func test_settingsFeedbackSendFeedbackHint_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.feedback.sendFeedback.hint"))
    }

    func test_settingsPickerMinuteFormat_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.picker.minuteFormat"))
    }

    func test_settingsPickerSecondFormat_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("settings.picker.secondFormat"))
    }

    func test_overlayDismissButtonHint_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("overlay.dismissButton.hint"))
    }

    func test_homeSettingsButtonHint_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("home.settingsButton.hint"))
    }

    func test_onboardingWelcomeDisclaimer_resolvesToEnglish() {
        XCTAssertTrue(isTranslated("onboarding.welcome.disclaimer"))
    }

    // MARK: - Format-Specifier Validation
    //
    // Critical user-facing strings that contain printf-style format specifiers must
    // retain those placeholders after any catalog edit. These spot-checks verify that
    // the compiled English value still contains the expected specifier so callers
    // (String(format:) and SwiftUI Text interpolation) receive well-formed strings.

    /// `settings.picker.minuteFormat` is used to build countdown and picker labels
    /// such as "20 min". Requires exactly one `%d` integer placeholder.
    func test_settingsPickerMinuteFormat_containsIntegerSpecifier() {
        let value = str("settings.picker.minuteFormat")
        XCTAssertTrue(
            value.contains("%d"),
            "'settings.picker.minuteFormat' must contain %%d — received: \(value)")
    }

    /// `settings.picker.secondFormat` is used to build countdown and picker labels
    /// such as "20 sec". Requires exactly one `%d` integer placeholder.
    func test_settingsPickerSecondFormat_containsIntegerSpecifier() {
        let value = str("settings.picker.secondFormat")
        XCTAssertTrue(
            value.contains("%d"),
            "'settings.picker.secondFormat' must contain %%d — received: \(value)")
    }

    /// `onboarding.setup.card.label` is the setup-screen summary card for each
    /// reminder type. It uses three *positional* string specifiers (`%1$@`, `%2$@`,
    /// `%3$@`) so word order is locale-safe. All three must be present.
    func test_onboardingSetupCardLabel_containsThreePositionalSpecifiers() {
        let value = str("onboarding.setup.card.label")
        XCTAssertTrue(
            value.contains("%1$@"),
            "'onboarding.setup.card.label' must contain %%1$@ — received: \(value)")
        XCTAssertTrue(
            value.contains("%2$@"),
            "'onboarding.setup.card.label' must contain %%2$@ — received: \(value)")
        XCTAssertTrue(
            value.contains("%3$@"),
            "'onboarding.setup.card.label' must contain %%3$@ — received: \(value)")
    }

    /// `settings.snooze.activeLabel` renders the snooze expiry time in the Settings
    /// screen ("Snoozed until 3:00 PM"). Requires one `%@` object placeholder for the
    /// formatted `Date` string.
    func test_settingsSnoozeActiveLabel_containsStringSpecifier() {
        let value = str("settings.snooze.activeLabel")
        XCTAssertTrue(
            value.contains("%@"),
            "'settings.snooze.activeLabel' must contain %%@ — received: \(value)")
    }

    /// `settings.about.versionFormat` renders the build info in the About section
    /// ("v1.0.0 (build 42)"). Requires two `%@` object placeholders.
    func test_settingsAboutVersionFormat_containsTwoStringSpecifiers() {
        let value = str("settings.about.versionFormat")
        let count = value.components(separatedBy: "%@").count - 1
        XCTAssertEqual(
            count,
            2,
            "'settings.about.versionFormat' must contain exactly 2 %%@ specifiers — received: \(value)"
        )
    }

    /// `settings.reminder.durationPicker.hint` VoiceOver hint contains one `%@`
    /// placeholder for the reminder-type name (e.g., "eye" / "posture").
    func test_settingsReminderDurationPickerHint_containsStringSpecifier() {
        let value = str("settings.reminder.durationPicker.hint")
        XCTAssertTrue(
            value.contains("%@"),
            "'settings.reminder.durationPicker.hint' must contain %%@ — received: \(value)")
    }

    // MARK: - Onboarding Setup — Reminder Window Selection

    /// `onboarding.setup.changeInSettings` is the reassurance copy on the Setup screen
    /// telling users they can adjust their reminder schedule in Settings later.
    func test_onboardingSetup_changeInSettings_resolvesToEnglish() {
        XCTAssertTrue(
            isTranslated("onboarding.setup.changeInSettings"),
            "'onboarding.setup.changeInSettings' must resolve from catalog, not fall back to the key string")
    }

    /// The resolved value must reference "Settings" so users understand where to go.
    func test_onboardingSetup_changeInSettings_mentionsSettings() {
        let value = str("onboarding.setup.changeInSettings")
        XCTAssertTrue(
            value.localizedCaseInsensitiveContains("Settings"),
            "'onboarding.setup.changeInSettings' must reference 'Settings' — got: \(value)")
    }

    /// `onboarding.setup.changeInSettings` must be non-empty.
    func test_onboardingSetup_changeInSettings_isNonEmpty() {
        let value = str("onboarding.setup.changeInSettings")
        XCTAssertFalse(value.isEmpty,
                       "'onboarding.setup.changeInSettings' must not resolve to an empty string")
    }

    // MARK: - Permission Copy Regression (P0 + M3.8 reminder-alert copy)
    //
    // The notification permission screen must motivate reminder-alert permission
    // on its own, without demoting alerts to a backup for True Interrupt Mode.
    //
    // These tests lock in that copy contract so future edits cannot silently revert
    // to backup-only framing or overlay promises.

    /// Enable-button must say "Reminder Alerts" — not backup-only implementation copy.
    func test_onboardingPermission_enableButton_readsReminderAlerts() {
        let value = str("onboarding.permission.enableButton")
        XCTAssertTrue(
            value.localizedCaseInsensitiveContains("Reminder Alerts"),
            "'onboarding.permission.enableButton' must use reminder-alert language — got: \(value)")
        XCTAssertFalse(
            value.localizedCaseInsensitiveContains("Backup"),
            "'onboarding.permission.enableButton' must not demote alerts to backup-only — got: \(value)")
    }

    /// Body line 1 must frame alerts as valuable for all users, not as True Interrupt backup.
    func test_onboardingPermission_body1_valuesReminderAlertsDirectly() {
        let value = str("onboarding.permission.body1")
        XCTAssertTrue(
            value.localizedCaseInsensitiveContains("gentle alerts"),
            "'onboarding.permission.body1' must positively frame reminder alerts — got: \(value)")
        XCTAssertTrue(
            value.localizedCaseInsensitiveContains("rest your eyes"),
            "'onboarding.permission.body1' must explain the eye-break value — got: \(value)")
        XCTAssertTrue(
            value.localizedCaseInsensitiveContains("check your posture"),
            "'onboarding.permission.body1' must explain the posture-check value — got: \(value)")
        XCTAssertFalse(
            value.localizedCaseInsensitiveContains("backup"),
            "'onboarding.permission.body1' must not frame alerts as backup-only — got: \(value)")
        XCTAssertFalse(
            value.localizedCaseInsensitiveContains("True Interrupt"),
            "'onboarding.permission.body1' must not redirect to True Interrupt setup — got: \(value)")
        XCTAssertFalse(
            value.localizedCaseInsensitiveContains("Screen Time"),
            "'onboarding.permission.body1' must not depend on Screen Time availability — got: \(value)")
    }

    /// Body line 2 must be non-empty and not promise a system-level notification popup.
    func test_onboardingPermission_body2_isNonEmptyAndNotSystemOverlayPromise() {
        let value = str("onboarding.permission.body2")
        XCTAssertFalse(value.isEmpty, "'onboarding.permission.body2' must not be empty")
        // "overlay" would promise UI that only works while the app is foregrounded.
        XCTAssertFalse(
            value.localizedCaseInsensitiveContains("overlay"),
            "'onboarding.permission.body2' must not reference 'overlay' — got: \(value)")
    }

    /// Master toggle footer must distinguish in-app overlays from OS-delivered alerts.
    func test_primaryToggleFooter_describesBackgroundAlertDeliveryAccurately() {
        let value = str("settings.masterToggle.footer")

        XCTAssertTrue(
            value.localizedCaseInsensitiveContains("overlays"),
            "'settings.masterToggle.footer' must scope app-open language to overlays — got: \(value)")
        XCTAssertTrue(
            value.localizedCaseInsensitiveContains("delivered by iOS"),
            "'settings.masterToggle.footer' must explain alerts are OS-delivered — got: \(value)")
        XCTAssertTrue(
            value.localizedCaseInsensitiveContains("app is closed"),
            "'settings.masterToggle.footer' must not imply closed-app delivery is unavailable — got: \(value)")
        XCTAssertFalse(
            value.localizedCaseInsensitiveContains("Reminders only work while the app is open"),
            "'settings.masterToggle.footer' must not claim all reminders require the app open — got: \(value)")
    }

    /// The permission screen title must be non-empty and resolve from the catalog.
    func test_onboardingPermission_title_resolvesFromCatalog() {
        XCTAssertTrue(
            isTranslated("onboarding.permission.title"),
            "'onboarding.permission.title' must resolve to a real string, not the key fallback")
        XCTAssertFalse(str("onboarding.permission.title").isEmpty)
    }

    /// Reminder notification content keys must resolve so notification banners display
    /// real copy rather than the raw key string.
    func test_reminderNotificationContent_eyesTitle_resolvesFromCatalog() {
        XCTAssertTrue(
            isTranslated("reminder.eyes.notificationTitle"),
            "'reminder.eyes.notificationTitle' must resolve from catalog")
    }

    func test_reminderNotificationContent_eyesBody_resolvesFromCatalog() {
        XCTAssertTrue(
            isTranslated("reminder.eyes.notificationBody"),
            "'reminder.eyes.notificationBody' must resolve from catalog")
    }

    func test_reminderNotificationContent_postureTitle_resolvesFromCatalog() {
        XCTAssertTrue(
            isTranslated("reminder.posture.notificationTitle"),
            "'reminder.posture.notificationTitle' must resolve from catalog")
    }

    func test_reminderNotificationContent_postureBody_resolvesFromCatalog() {
        XCTAssertTrue(
            isTranslated("reminder.posture.notificationBody"),
            "'reminder.posture.notificationBody' must resolve from catalog")
    }

    /// Notification content keys must be non-empty — a blank notification banner
    /// is worse than no notification.
    func test_reminderNotificationContent_allKeys_areNonEmpty() {
        let notificationKeys = [
            "reminder.eyes.notificationTitle",
            "reminder.eyes.notificationBody",
            "reminder.posture.notificationTitle",
            "reminder.posture.notificationBody"
        ]
        for key in notificationKeys {
            let value = str(key)
            XCTAssertFalse(
                value.isEmpty,
                "'\(key)' must not resolve to an empty string — blank notification content is invisible to users")
        }
    }

    func test_reminderNotificationContent_usesBackupReminderCopy() {
        let backupReminderValues = [
            str("reminder.eyes.notificationBody"),
            str("reminder.posture.notificationBody")
        ]
        for value in backupReminderValues {
            XCTAssertTrue(
                value.localizedCaseInsensitiveContains("backup reminder"),
                "Notification copy must use user-facing backup-reminder language — got: \(value)"
            )
        }

        let notificationAndPreviewValues = [
            str("reminder.eyes.notificationTitle"),
            str("reminder.eyes.notificationBody"),
            str("reminder.posture.notificationTitle"),
            str("reminder.posture.notificationBody"),
            str("onboarding.permission.notificationCard.title"),
            str("onboarding.permission.notificationCard.body"),
            str("onboarding.permission.notificationCard.label")
        ]
        for value in notificationAndPreviewValues {
            XCTAssertNil(
                value.range(
                    of: #"\bfallback\b"#,
                    options: [.regularExpression, .caseInsensitive]
                ),
                "Notification copy must not expose fallback implementation jargon — got: \(value)"
            )
        }

        let permissionScreenValues = [
            str("onboarding.permission.title"),
            str("onboarding.permission.body1"),
            str("onboarding.permission.enableButton"),
            str("onboarding.permission.enableButton.hint"),
            str("onboarding.permission.notificationCard.body"),
            str("onboarding.permission.notificationCard.label")
        ]
        for value in permissionScreenValues {
            XCTAssertFalse(
                value.localizedCaseInsensitiveContains("backup"),
                "Permission-screen copy must not demote notification alerts to backup-only — got: \(value)"
            )
        }
    }

    func test_reminderNotificationTitles_doNotUseEmojiFirstCopy() {
        let values = [
            str("reminder.eyes.notificationTitle"),
            str("reminder.posture.notificationTitle")
        ]
        for value in values {
            XCTAssertFalse(
                value.contains("👁") || value.contains("🧍"),
                "Notification title must not use legacy emoji-first copy — got: \(value)"
            )
        }
    }

    /// Settings banner copy for disabled reminders must use "Reminders" language,
    /// consistent with the permission-screen and notification-content rename.
    func test_settingsNotificationsDisabledTitle_usesReminderLanguage() {
        let value = str("settings.notifications.disabledTitle")
        XCTAssertTrue(
            value.localizedCaseInsensitiveContains("Reminder"),
            "'settings.notifications.disabledTitle' must use 'Reminder' language — got: \(value)")
    }
}
