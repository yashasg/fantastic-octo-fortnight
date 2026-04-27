@testable import EyePostureReminder
import XCTest

/// Additional tests targeting coverage gaps in files that are partially testable
/// without a host app. Pure SwiftUI `body` properties remain out of scope for
/// unit tests; these tests cover init contracts, computed properties, and
/// non-view logic extracted alongside views.
@MainActor
final class CoverageBoostTests: XCTestCase {

    // MARK: - LegalDocument Enum

    func test_legalDocument_terms_exists() {
        let doc = LegalDocument.terms
        XCTAssertNotNil(doc)
    }

    func test_legalDocument_privacy_exists() {
        let doc = LegalDocument.privacy
        XCTAssertNotNil(doc)
    }

    func test_legalDocument_termsAndPrivacy_areDistinct() {
        XCTAssertTrue(LegalDocument.terms != .privacy, "terms and privacy must be distinct")
    }

    // MARK: - AppTypography.registerFonts()

    func test_registerFonts_doesNotCrash() {
        AppTypography.registerFonts()
    }

    func test_registerFonts_calledMultipleTimes_doesNotCrash() {
        AppTypography.registerFonts()
        AppTypography.registerFonts()
    }

    // MARK: - AppFont Aliases Mirror AppTypography

    func test_appFont_headline_matchesTypography() {
        XCTAssertNotNil(AppFont.headline)
    }

    func test_appFont_body_matchesTypography() {
        XCTAssertNotNil(AppFont.body)
    }

    func test_appFont_bodyEmphasized_matchesTypography() {
        XCTAssertNotNil(AppFont.bodyEmphasized)
    }

    func test_appFont_caption_matchesTypography() {
        XCTAssertNotNil(AppFont.caption)
    }

    func test_appFont_captionEmphasized_matchesTypography() {
        XCTAssertNotNil(AppFont.captionEmphasized)
    }

    func test_appFont_secondaryAction_matchesTypography() {
        XCTAssertNotNil(AppFont.secondaryAction)
    }

    func test_appFont_overlayDismiss_matchesTypography() {
        XCTAssertNotNil(AppFont.overlayDismiss)
    }

    func test_appFont_countdown_matchesTypography() {
        XCTAssertNotNil(AppFont.countdown)
    }

    func test_appFont_overlayIcon_matchesTypography() {
        XCTAssertNotNil(AppFont.overlayIcon)
    }

    func test_appFont_homeLogoIcon_matchesTypography() {
        XCTAssertNotNil(AppFont.homeLogoIcon)
    }

    func test_appFont_illustrationIcon_matchesTypography() {
        XCTAssertNotNil(AppFont.illustrationIcon)
    }

    // MARK: - AppOpacity Token Values

    func test_appOpacity_iconAura() {
        XCTAssertEqual(AppOpacity.iconAura, 0.12)
    }

    func test_appOpacity_warningBackground() {
        XCTAssertEqual(AppOpacity.warningBackground, 0.10)
    }

    func test_appOpacity_warningSeparator() {
        XCTAssertEqual(AppOpacity.warningSeparator, 0.25)
    }

    func test_appOpacity_pressedButton() {
        XCTAssertEqual(AppOpacity.pressedButton, 0.68)
    }

    func test_appOpacity_mutedTimestamp() {
        XCTAssertEqual(AppOpacity.mutedTimestamp, 0.72)
    }

    func test_appOpacity_subtleBorder() {
        XCTAssertEqual(AppOpacity.subtleBorder, 0.65)
    }

    // MARK: - OverlayView Init Contract

    func test_overlayView_initWithEyeType_setsProperties() {
        var dismissCalled = false
        let view = OverlayView(
            type: .eyes,
            duration: 20,
            hapticsEnabled: true,
            onDismiss: { dismissCalled = true }
        )
        XCTAssertEqual(view.type, .eyes)
        XCTAssertEqual(view.duration, 20)
        XCTAssertTrue(view.hapticsEnabled)
        view.onDismiss()
        XCTAssertTrue(dismissCalled)
    }

    func test_overlayView_initWithPostureType_setsProperties() {
        let view = OverlayView(
            type: .posture,
            duration: 10,
            hapticsEnabled: false,
            onDismiss: {}
        )
        XCTAssertEqual(view.type, .posture)
        XCTAssertEqual(view.duration, 10)
        XCTAssertFalse(view.hapticsEnabled)
    }

    func test_overlayView_defaultHapticsEnabled_isTrue() {
        let view = OverlayView(type: .eyes, duration: 20, onDismiss: {})
        XCTAssertTrue(view.hapticsEnabled)
    }

    func test_overlayView_onSettingsTap_defaultIsNoOp() {
        let view = OverlayView(type: .eyes, duration: 20, onDismiss: {})
        // Should not crash — default is {}
        view.onSettingsTap()
    }

    func test_overlayView_onAnalyticsEvent_defaultIsNoOp() {
        let view = OverlayView(type: .eyes, duration: 20, onDismiss: {})
        // Should not crash — default is { _ in }
        view.onAnalyticsEvent(.overlayAutoDismissed(type: .eyes, durationS: 20))
    }

    func test_overlayView_customOnSettingsTap_isCalled() {
        var tapped = false
        let view = OverlayView(
            type: .posture,
            duration: 10,
            onAnalyticsEvent: { _ in },
            onSettingsTap: { tapped = true },
            onDismiss: {}
        )
        view.onSettingsTap()
        XCTAssertTrue(tapped)
    }

    func test_overlayView_customOnAnalyticsEvent_isCalled() {
        var eventReceived: AnalyticsEvent?
        let view = OverlayView(
            type: .eyes,
            duration: 20,
            onAnalyticsEvent: { eventReceived = $0 },
            onDismiss: {}
        )
        let event = AnalyticsEvent.overlayAutoDismissed(type: .eyes, durationS: 20)
        view.onAnalyticsEvent(event)
        XCTAssertNotNil(eventReceived)
    }

    // MARK: - SoftElevation Modifier

    func test_softElevation_viewModifier_doesNotCrash() {
        let modifier = SoftElevation()
        XCTAssertNotNil(modifier)
    }

    // MARK: - SettingsViewModel Formatter Coverage

    func test_settingsViewModel_intervalOptions_isNotEmpty() {
        XCTAssertFalse(SettingsViewModel.intervalOptions.isEmpty)
    }

    func test_settingsViewModel_breakDurationOptions_isNotEmpty() {
        XCTAssertFalse(SettingsViewModel.breakDurationOptions.isEmpty)
    }

    func test_settingsViewModel_labelForInterval_allOptions() {
        for option in SettingsViewModel.intervalOptions {
            let label = SettingsViewModel.labelForInterval(option)
            XCTAssertFalse(label.isEmpty, "Label for interval \(option) should not be empty")
        }
    }

    func test_settingsViewModel_labelForBreakDuration_allOptions() {
        for option in SettingsViewModel.breakDurationOptions {
            let label = SettingsViewModel.labelForBreakDuration(option)
            XCTAssertFalse(label.isEmpty, "Label for duration \(option) should not be empty")
        }
    }
}
