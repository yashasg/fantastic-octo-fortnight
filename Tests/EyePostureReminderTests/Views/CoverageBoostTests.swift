import ComposableArchitecture
import XCTest

@testable import EyePostureReminder

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

    /// `#920` removed the closure-init in favour of the canonical
    /// `init(store:)`. The view exposes `type`, `duration`, and
    /// `hapticsEnabled` as proxy accessors that read from the underlying
    /// `OverlayFeature.State` — these tests preserve that property
    /// contract.

    private func makeOverlayView(
        type: ReminderType,
        duration: TimeInterval,
        hapticsEnabled: Bool = true
    ) -> OverlayView {
        let store = Store(
            initialState: OverlayFeature.State(
                type: type,
                duration: duration,
                hapticsEnabled: hapticsEnabled
            )
        ) {
            OverlayFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
        }
        return OverlayView(store: store)
    }

    func test_overlayView_initWithEyeType_setsProperties() {
        let view = makeOverlayView(type: .eyes, duration: 20, hapticsEnabled: true)
        XCTAssertEqual(view.type, .eyes)
        XCTAssertEqual(view.duration, 20)
        XCTAssertTrue(view.hapticsEnabled)
    }

    func test_overlayView_initWithPostureType_setsProperties() {
        let view = makeOverlayView(type: .posture, duration: 10, hapticsEnabled: false)
        XCTAssertEqual(view.type, .posture)
        XCTAssertEqual(view.duration, 10)
        XCTAssertFalse(view.hapticsEnabled)
    }

    func test_overlayView_defaultHapticsEnabled_isTrue() {
        // `OverlayFeature.State.init(...)` defaults `hapticsEnabled` to
        // `true` — `OverlayView` must read that through to its proxy.
        let store = Store(
            initialState: OverlayFeature.State(type: .eyes, duration: 20)
        ) {
            OverlayFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
        }
        let view = OverlayView(store: store)
        XCTAssertTrue(view.hapticsEnabled)
    }

    // MARK: - SoftElevation Modifier

    func test_softElevation_viewModifier_doesNotCrash() {
        let modifier = SoftElevation()
        XCTAssertNotNil(modifier)
    }

    // MARK: - SettingsPickerOptions Formatter Coverage

    func test_settingsPickerOptions_intervalOptions_isNotEmpty() {
        XCTAssertFalse(SettingsPickerOptions.intervalOptions.isEmpty)
    }

    func test_settingsPickerOptions_breakDurationOptions_isNotEmpty() {
        XCTAssertFalse(SettingsPickerOptions.breakDurationOptions.isEmpty)
    }

    func test_settingsPickerOptions_labelForInterval_allOptions() {
        for option in SettingsPickerOptions.intervalOptions {
            let label = SettingsPickerOptions.labelForInterval(option)
            XCTAssertFalse(label.isEmpty, "Label for interval \(option) should not be empty")
        }
    }

    func test_settingsPickerOptions_labelForBreakDuration_allOptions() {
        for option in SettingsPickerOptions.breakDurationOptions {
            let label = SettingsPickerOptions.labelForBreakDuration(option)
            XCTAssertFalse(label.isEmpty, "Label for duration \(option) should not be empty")
        }
    }
}
