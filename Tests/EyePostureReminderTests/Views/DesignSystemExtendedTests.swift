@testable import EyePostureReminder
import SwiftUI
import XCTest

/// Additional coverage for design system tokens — fills remaining gaps in
/// AppOpacity, AppLayout edge values, AppAnimation boundary checks, and
/// SoftElevation modifier compile tests.
final class DesignSystemExtendedTests: XCTestCase {

    // MARK: - AppOpacity: All tokens exist and are in valid range

    func test_appOpacity_iconAura_isInRange() {
        XCTAssertGreaterThan(AppOpacity.iconAura, 0)
        XCTAssertLessThanOrEqual(AppOpacity.iconAura, 1)
    }

    func test_appOpacity_warningBackground_isInRange() {
        XCTAssertGreaterThan(AppOpacity.warningBackground, 0)
        XCTAssertLessThanOrEqual(AppOpacity.warningBackground, 1)
    }

    func test_appOpacity_warningSeparator_isInRange() {
        XCTAssertGreaterThan(AppOpacity.warningSeparator, 0)
        XCTAssertLessThanOrEqual(AppOpacity.warningSeparator, 1)
    }

    func test_appOpacity_pressedButton_isInRange() {
        XCTAssertGreaterThan(AppOpacity.pressedButton, 0)
        XCTAssertLessThanOrEqual(AppOpacity.pressedButton, 1)
    }

    func test_appOpacity_mutedTimestamp_isInRange() {
        XCTAssertGreaterThan(AppOpacity.mutedTimestamp, 0)
        XCTAssertLessThanOrEqual(AppOpacity.mutedTimestamp, 1)
    }

    func test_appOpacity_subtleBorder_isInRange() {
        XCTAssertGreaterThan(AppOpacity.subtleBorder, 0)
        XCTAssertLessThanOrEqual(AppOpacity.subtleBorder, 1)
    }

    // MARK: - AppOpacity: Specific values

    func test_appOpacity_iconAura_is012() {
        XCTAssertEqual(AppOpacity.iconAura, 0.12, accuracy: 0.001)
    }

    func test_appOpacity_warningBackground_is010() {
        XCTAssertEqual(AppOpacity.warningBackground, 0.10, accuracy: 0.001)
    }

    func test_appOpacity_warningSeparator_is025() {
        XCTAssertEqual(AppOpacity.warningSeparator, 0.25, accuracy: 0.001)
    }

    func test_appOpacity_pressedButton_is068() {
        XCTAssertEqual(AppOpacity.pressedButton, 0.68, accuracy: 0.001)
    }

    func test_appOpacity_mutedTimestamp_is072() {
        XCTAssertEqual(AppOpacity.mutedTimestamp, 0.72, accuracy: 0.001)
    }

    func test_appOpacity_subtleBorder_is065() {
        XCTAssertEqual(AppOpacity.subtleBorder, 0.65, accuracy: 0.001)
    }

    // MARK: - AppLayout: All radii > 0

    func test_appLayout_radiusSmall_isPositive() {
        XCTAssertGreaterThan(AppLayout.radiusSmall, 0)
    }

    func test_appLayout_radiusCard_isPositive() {
        XCTAssertGreaterThan(AppLayout.radiusCard, 0)
    }

    func test_appLayout_radiusLarge_isPositive() {
        XCTAssertGreaterThan(AppLayout.radiusLarge, 0)
    }

    func test_appLayout_radiusPill_isLargeValue() {
        XCTAssertGreaterThanOrEqual(AppLayout.radiusPill, 999)
    }

    // MARK: - AppLayout: Size ordering

    func test_appLayout_radii_orderedSmallToLarge() {
        XCTAssertLessThan(AppLayout.radiusSmall, AppLayout.radiusCard)
        XCTAssertLessThan(AppLayout.radiusCard, AppLayout.radiusLarge)
        XCTAssertLessThan(AppLayout.radiusLarge, AppLayout.radiusPill)
    }

    // MARK: - AppLayout: Key sizes

    func test_appLayout_minTapTarget_is44() {
        XCTAssertEqual(AppLayout.minTapTarget, 44)
    }

    func test_appLayout_overlayIconSize_is80() {
        XCTAssertEqual(AppLayout.overlayIconSize, 80)
    }

    func test_appLayout_countdownRingDiameter_is160() {
        XCTAssertEqual(AppLayout.countdownRingDiameter, 160)
    }

    func test_appLayout_countdownRingStroke_is8() {
        XCTAssertEqual(AppLayout.countdownRingStroke, 8)
    }

    func test_appLayout_onboardingMaxContentWidth_is540() {
        XCTAssertEqual(AppLayout.onboardingMaxContentWidth, 540)
    }

    func test_appLayout_onboardingIllustrationSize_is72() {
        XCTAssertEqual(AppLayout.onboardingIllustrationSize, 72)
    }

    func test_appLayout_entranceSlideOffset_is20() {
        XCTAssertEqual(AppLayout.entranceSlideOffset, 20)
    }

    func test_appLayout_settingsRowIconWidth_is40() {
        XCTAssertEqual(AppLayout.settingsRowIconWidth, 40)
    }

    // MARK: - AppSpacing: Complete token audit

    func test_appSpacing_xs_is4() {
        XCTAssertEqual(AppSpacing.xs, 4)
    }

    func test_appSpacing_sm_is8() {
        XCTAssertEqual(AppSpacing.sm, 8)
    }

    func test_appSpacing_md_is16() {
        XCTAssertEqual(AppSpacing.md, 16)
    }

    func test_appSpacing_lg_is24() {
        XCTAssertEqual(AppSpacing.lg, 24)
    }

    func test_appSpacing_xl_is32() {
        XCTAssertEqual(AppSpacing.xl, 32)
    }

    func test_appSpacing_xxl_is40() {
        XCTAssertEqual(AppSpacing.xxl, 40)
    }

    func test_appSpacing_isOn4ptGrid() {
        let all: [CGFloat] = [AppSpacing.xs, AppSpacing.sm, AppSpacing.md,
                              AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl]
        for value in all {
            XCTAssertEqual(
                value.truncatingRemainder(dividingBy: 4), 0,
                "\(value) must be a multiple of 4 (4pt grid)")
        }
    }

    // MARK: - AppAnimation: Duration values

    func test_appAnimation_overlayAppear_is03() {
        XCTAssertEqual(AppAnimation.overlayAppear, 0.3, accuracy: 0.001)
    }

    func test_appAnimation_overlayDismiss_is02() {
        XCTAssertEqual(AppAnimation.overlayDismiss, 0.2, accuracy: 0.001)
    }

    func test_appAnimation_overlayAutoDismiss_is03() {
        XCTAssertEqual(AppAnimation.overlayAutoDismiss, 0.3, accuracy: 0.001)
    }

    func test_appAnimation_settingsExpand_is02() {
        XCTAssertEqual(AppAnimation.settingsExpand, 0.2, accuracy: 0.001)
    }

    func test_appAnimation_calmingEntranceDuration_is05() {
        XCTAssertEqual(AppAnimation.calmingEntranceDuration, 0.5, accuracy: 0.001)
    }

    func test_appAnimation_statusCrossfadeDuration_is025() {
        XCTAssertEqual(AppAnimation.statusCrossfadeDuration, 0.25, accuracy: 0.001)
    }

    func test_appAnimation_onboardingFadeIn_is04() {
        XCTAssertEqual(AppAnimation.onboardingFadeIn, 0.4, accuracy: 0.001)
    }

    func test_appAnimation_onboardingFadeInDelay_is01() {
        XCTAssertEqual(AppAnimation.onboardingFadeInDelay, 0.1, accuracy: 0.001)
    }

    func test_appAnimation_countdownRingTick_is1() {
        XCTAssertEqual(AppAnimation.countdownRingTick, 1.0, accuracy: 0.001)
    }

    func test_appAnimation_allDurations_arePositive() {
        let durations: [Double] = [
            AppAnimation.overlayAppear,
            AppAnimation.overlayDismiss,
            AppAnimation.overlayAutoDismiss,
            AppAnimation.settingsExpand,
            AppAnimation.calmingEntranceDuration,
            AppAnimation.statusCrossfadeDuration,
            AppAnimation.onboardingFadeIn,
            AppAnimation.onboardingFadeInDelay,
            AppAnimation.countdownRingTick
        ]
        for duration in durations {
            XCTAssertGreaterThan(duration, 0, "Animation duration must be > 0")
        }
    }

    // MARK: - AppAnimation: Curve existence (compile + instantiation)

    func test_appAnimation_curveTokens_compile() {
        _ = AppAnimation.overlayAppearCurve
        _ = AppAnimation.overlayDismissCurve
        _ = AppAnimation.overlayFadeCurve
        _ = AppAnimation.settingsExpandCurve
        _ = AppAnimation.onboardingTransition
        _ = AppAnimation.onboardingFadeInCurve
        _ = AppAnimation.calmingEntranceCurve
        _ = AppAnimation.statusCrossfadeCurve
        _ = AppAnimation.countdownRingCurve
        _ = AppAnimation.yinYangSpinCurve
    }

    // MARK: - AppFont aliases match AppTypography

    func test_appFont_aliases_compile() {
        _ = AppFont.headline
        _ = AppFont.body
        _ = AppFont.bodyEmphasized
        _ = AppFont.caption
        _ = AppFont.captionEmphasized
        _ = AppFont.secondaryAction
        _ = AppFont.overlayDismiss
        _ = AppFont.countdown
        _ = AppFont.settingsRowIcon
        _ = AppFont.warningIcon
        _ = AppFont.reminderCardIcon
        _ = AppFont.overlayIcon
        _ = AppFont.homeLogoIcon
        _ = AppFont.illustrationIcon
    }

    // MARK: - SoftElevation modifier compiles

    func test_softElevation_modifierCompiles() {
        let modifier = SoftElevation()
        _ = modifier
    }
}
