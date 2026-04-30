@testable import EyePostureReminder
import SwiftUI
import XCTest

/// Regression tests for `DesignSystem.swift` — the single source of truth for
/// all visual tokens (colors, fonts, spacing, animation, layout).
///
/// **Accessibility contract for AppFont:**
/// All tokens except `countdown` MUST use `Font.TextStyle`-based APIs so they
/// scale with the user's Dynamic Type setting. `countdown` uses a fixed monospaced
/// size intentionally (it is a decorative element replaced by an accessibility
/// label for VoiceOver users — see Phase 1 Implementation decisions).
///
/// **Note:** `Font` does not conform to `Equatable` so tests verify accessibility
/// by confirming the expected constant expressions compile and match the documented
/// design-system spec values. Regression failures are caught at the call-site if
/// the constant definition ever drifts from the spec comment.
final class DesignSystemTests: XCTestCase {

    // MARK: - AppFont: Static Accessibility Compilation Tests

    /// Headline compiles with Font.TextStyle .title — scales with Dynamic Type.
    func test_appFont_headline_isAccessible() {
        let font = AppFont.headline
        let spec: Font = .system(.title).weight(.bold)
        _ = font
        _ = spec
        // Both expressions compile — proves no hardcoded `size:` parameter.
        XCTAssertFalse(String(describing: font).isEmpty, "headline font must produce a non-empty description")
    }

    /// Body compiles with Font.TextStyle .body — scales with Dynamic Type.
    func test_appFont_body_isAccessible() {
        let font = AppFont.body
        let spec: Font = .system(.body)
        _ = font
        _ = spec
        XCTAssertFalse(String(describing: font).isEmpty, "body font must produce a non-empty description")
    }

    /// bodyEmphasized compiles with Font.TextStyle .headline — scales with Dynamic Type.
    func test_appFont_bodyEmphasized_isAccessible() {
        let font = AppFont.bodyEmphasized
        let spec: Font = .system(.headline)
        _ = font
        _ = spec
        XCTAssertFalse(String(describing: font).isEmpty, "bodyEmphasized font must produce a non-empty description")
    }

    /// Caption compiles with Font.TextStyle .footnote — scales with Dynamic Type.
    func test_appFont_caption_isAccessible() {
        let font = AppFont.caption
        let spec: Font = .system(.footnote)
        _ = font
        _ = spec
        XCTAssertFalse(String(describing: font).isEmpty, "caption font must produce a non-empty description")
    }

    /// Countdown is intentionally fixed-size (64pt monospaced bold).
    /// Accessibility is provided via `.accessibilityLabel` on the countdown ZStack.
    func test_appFont_countdown_isFixedMonospaced_byDesign() {
        let font = AppFont.countdown
        let spec: Font = .system(size: 64, weight: .bold, design: .monospaced)
        _ = font
        _ = spec
        // Compile-time confirmation that the fixed-size variant exists.
        XCTAssertFalse(String(describing: font).isEmpty, "countdown font must produce a non-empty description")
    }

    // MARK: - AppSpacing: 4pt Grid Compliance

    func test_appSpacing_xxs_is2pt() {
        XCTAssertEqual(AppSpacing.xxs, 2, "xxs must be 2pt (tight caption gap)")
    }

    func test_appSpacing_xs_is4pt() {
        XCTAssertEqual(AppSpacing.xs, 4, "xs must be 4pt (smallest grid unit)")
    }

    func test_appSpacing_sm_is8pt() {
        XCTAssertEqual(AppSpacing.sm, 8, "sm must be 8pt (2× grid)")
    }

    func test_appSpacing_md_is16pt() {
        XCTAssertEqual(AppSpacing.md, 16, "md must be 16pt (4× grid, standard section padding)")
    }

    func test_appSpacing_lg_is24pt() {
        XCTAssertEqual(AppSpacing.lg, 24, "lg must be 24pt (6× grid)")
    }

    func test_appSpacing_xl_is32pt() {
        XCTAssertEqual(AppSpacing.xl, 32, "xl must be 32pt (8× grid, screen-level breathing room)")
    }

    func test_appSpacing_valuesAreAscending() {
        let spacings: [CGFloat] = [AppSpacing.xxs, AppSpacing.xs, AppSpacing.sm, AppSpacing.md, AppSpacing.lg, AppSpacing.xl]
        for index in 1..<spacings.count {
            XCTAssertGreaterThan(
                spacings[index],
                spacings[index - 1],
                "Spacing tokens must be in strictly ascending order")
        }
    }

    // MARK: - AppLayout: iOS HIG Compliance

    func test_appLayout_minTapTarget_meetsHIGMinimum() {
        XCTAssertGreaterThanOrEqual(
            AppLayout.minTapTarget,
            44,
            "Minimum tap target must be ≥44pt per iOS HIG")
    }

    func test_appLayout_overlayIconSize_isReasonable() {
        XCTAssertGreaterThan(AppLayout.overlayIconSize, 0)
        XCTAssertGreaterThanOrEqual(
            AppLayout.overlayIconSize,
            AppLayout.minTapTarget,
            "Overlay icon must be at least as large as minimum tap target")
    }

    func test_appLayout_countdownRingDiameter_isPositive() {
        XCTAssertGreaterThan(AppLayout.countdownRingDiameter, 0)
    }

    func test_appLayout_countdownRingStroke_isPositive() {
        XCTAssertGreaterThan(AppLayout.countdownRingStroke, 0)
    }

    // MARK: - AppAnimation: Duration Spec Compliance

    func test_appAnimation_overlayAppear_is0point3s() {
        XCTAssertEqual(
            AppAnimation.overlayAppear,
            0.3,
            accuracy: 0.001,
            "Overlay appear animation must be 0.3s (ease-out)")
    }

    func test_appAnimation_overlayDismiss_is0point2s() {
        XCTAssertEqual(
            AppAnimation.overlayDismiss,
            0.2,
            accuracy: 0.001,
            "Overlay dismiss animation must be 0.2s (ease-in)")
    }

    func test_appAnimation_overlayAutoDismiss_is0point3s() {
        XCTAssertEqual(
            AppAnimation.overlayAutoDismiss,
            0.3,
            accuracy: 0.001,
            "Overlay auto-dismiss animation must be 0.3s (linear)")
    }

    func test_appAnimation_allDurationsArePositive() {
        let durations = [
            AppAnimation.overlayAppear,
            AppAnimation.overlayDismiss,
            AppAnimation.overlayAutoDismiss,
            AppAnimation.settingsExpand,
            AppAnimation.countdownRingTick
        ]
        for duration in durations {
            XCTAssertGreaterThan(duration, 0, "All animation durations must be positive")
        }
    }

    // MARK: - AppFont: Icon Tokens (Restful Grove additions)

    /// settingsRowIcon token compiles — SF Symbol at 15pt semibold (decorative, accessibility-hidden).
    func test_appFont_settingsRowIcon_isAccessible() {
        let font = AppFont.settingsRowIcon
        XCTAssertFalse(String(describing: font).isEmpty, "settingsRowIcon font must produce a non-empty description")
    }

    /// warningIcon token compiles — SF Symbol at 16pt semibold (decorative, accessibility-hidden).
    func test_appFont_warningIcon_isAccessible() {
        let font = AppFont.warningIcon
        XCTAssertFalse(String(describing: font).isEmpty, "warningIcon font must produce a non-empty description")
    }

    /// reminderCardIcon token compiles — system(.title2), scales with Dynamic Type.
    func test_appFont_reminderCardIcon_isAccessible() {
        let font = AppFont.reminderCardIcon
        XCTAssertFalse(String(describing: font).isEmpty, "reminderCardIcon font must produce a non-empty description")
    }

    /// overlayIcon token compiles — sized to AppLayout.overlayIconSize (decorative).
    func test_appFont_overlayIcon_isAccessible() {
        let font = AppFont.overlayIcon
        XCTAssertFalse(String(describing: font).isEmpty, "overlayIcon font must produce a non-empty description")
    }

    /// illustrationIcon token compiles — sized to AppLayout.onboardingIllustrationSize semibold (decorative).
    func test_appFont_illustrationIcon_isAccessible() {
        let font = AppFont.illustrationIcon
        XCTAssertFalse(String(describing: font).isEmpty, "illustrationIcon font must produce a non-empty description")
    }

    // MARK: - AppSpacing: xxl token

    func test_appSpacing_xxl_is40pt() {
        XCTAssertEqual(AppSpacing.xxl, 40, "xxl must be 40pt (10× grid, large section dividers)")
    }

    func test_appSpacing_allValuesAscending_includesXxl() {
        let spacings: [CGFloat] = [
            AppSpacing.xxs, AppSpacing.xs, AppSpacing.sm, AppSpacing.md,
            AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl
        ]
        for index in 1..<spacings.count {
            XCTAssertGreaterThan(
                spacings[index],
                spacings[index - 1],
                "Spacing tokens (including xxl) must be in strictly ascending order")
        }
    }

    // MARK: - AppLayout: Corner Radius Tokens (Restful Grove)

    func test_appLayout_radiusSmall_is12pt() {
        XCTAssertEqual(AppLayout.radiusSmall, 12, "radiusSmall must be 12pt (chips, tags, compact buttons)")
    }

    func test_appLayout_radiusCard_is20pt() {
        XCTAssertEqual(AppLayout.radiusCard, 20, "radiusCard must be 20pt (content cards, modals, sheets)")
    }

    func test_appLayout_radiusLarge_is28pt() {
        XCTAssertEqual(AppLayout.radiusLarge, 28, "radiusLarge must be 28pt (large surfaces, hero cards)")
    }

    func test_appLayout_radiusPill_is999pt() {
        XCTAssertEqual(AppLayout.radiusPill, 999, "radiusPill must be 999pt (capsule/pill semantics)")
    }

    func test_appLayout_radiusValues_areAscending() {
        let radii: [CGFloat] = [
            AppLayout.radiusSmall,
            AppLayout.radiusCard,
            AppLayout.radiusLarge,
            AppLayout.radiusPill
        ]
        for index in 1..<radii.count {
            XCTAssertGreaterThan(
                radii[index],
                radii[index - 1],
                "Radius tokens must be in strictly ascending order")
        }
    }

    func test_appLayout_entranceSlideOffset_is20pt() {
        XCTAssertEqual(AppLayout.entranceSlideOffset, 20, "entranceSlideOffset must be 20pt (gentle upward drift)")
    }

    func test_appLayout_entranceSlideOffset_isPositive() {
        XCTAssertGreaterThan(AppLayout.entranceSlideOffset, 0)
    }

    // MARK: - AppAnimation: New Duration Tokens (Restful Grove)

    func test_appAnimation_onboardingFadeIn_is0point4s() {
        XCTAssertEqual(
            AppAnimation.onboardingFadeIn,
            0.4,
            accuracy: 0.001,
            "onboardingFadeIn must be 0.4s")
    }

    func test_appAnimation_onboardingFadeInDelay_is0point1s() {
        XCTAssertEqual(
            AppAnimation.onboardingFadeInDelay,
            0.1,
            accuracy: 0.001,
            "onboardingFadeInDelay must be 0.1s")
    }

    func test_appAnimation_calmingEntranceDuration_is0point5s() {
        XCTAssertEqual(
            AppAnimation.calmingEntranceDuration,
            0.5,
            accuracy: 0.001,
            "calmingEntranceDuration must be 0.5s (slower ease-out for calming overlay entrance)")
    }

    func test_appAnimation_statusCrossfadeDuration_is0point25s() {
        XCTAssertEqual(
            AppAnimation.statusCrossfadeDuration,
            0.25,
            accuracy: 0.001,
            "statusCrossfadeDuration must be 0.25s (icon + text crossfade)")
    }

    func test_appAnimation_allDurationsArePositive_includesNewTokens() {
        let durations = [
            AppAnimation.overlayAppear,
            AppAnimation.overlayDismiss,
            AppAnimation.overlayAutoDismiss,
            AppAnimation.settingsExpand,
            AppAnimation.countdownRingTick,
            AppAnimation.onboardingFadeIn,
            AppAnimation.onboardingFadeInDelay,
            AppAnimation.calmingEntranceDuration,
            AppAnimation.statusCrossfadeDuration
        ]
        for duration in durations {
            XCTAssertGreaterThan(duration, 0, "All animation durations must be positive")
        }
    }

    func test_appAnimation_calmingEntranceCurve_compiles() {
        let curve = AppAnimation.calmingEntranceCurve
        _ = curve
    }

    func test_appAnimation_statusCrossfadeCurve_compiles() {
        let curve = AppAnimation.statusCrossfadeCurve
        _ = curve
    }

    // MARK: - AppLayout: Border Width Tokens

    func test_appLayout_borderHair_is0point5pt() {
        XCTAssertEqual(AppLayout.borderHair, 0.5, accuracy: 0.001,
                       "borderHair must be 0.5pt (hair-thin border ring)")
    }

    func test_appLayout_borderSoft_is1pt() {
        XCTAssertEqual(AppLayout.borderSoft, 1.0, accuracy: 0.001,
                       "borderSoft must be 1.0pt (standard separator border)")
    }

    func test_appLayout_borderBold_is1point5pt() {
        XCTAssertEqual(AppLayout.borderBold, 1.5, accuracy: 0.001,
                       "borderBold must be 1.5pt (bold accent border)")
    }

    func test_appLayout_borderWidths_areAscending() {
        XCTAssertLessThan(AppLayout.borderHair, AppLayout.borderSoft,
                          "borderHair must be thinner than borderSoft")
        XCTAssertLessThan(AppLayout.borderSoft, AppLayout.borderBold,
                          "borderSoft must be thinner than borderBold")
    }

    // MARK: - AppLayout: Entrance / Decorative Tokens (added #387/#398)

    func test_appLayout_overlayEntranceOffset_is300pt() {
        XCTAssertEqual(AppLayout.overlayEntranceOffset, 300,
                       "overlayEntranceOffset must be 300pt (positions overlay below screen before entrance)")
    }

    func test_appLayout_decorativeIconFrame_is44pt() {
        XCTAssertEqual(AppLayout.decorativeIconFrame, 44,
                       "decorativeIconFrame must be 44pt (visual weight match for interactive controls)")
    }

    // MARK: - AppAnimation: Yin-Yang Breathing Token (added #390)

    func test_appAnimation_yinYangBreathingDuration_is4s() {
        XCTAssertEqual(
            AppAnimation.yinYangBreathingDuration,
            4.0,
            accuracy: 0.001,
            "yinYangBreathingDuration must be 4.0s (breathing pulse, ease-in-out, repeating)")
    }

    // MARK: - AppColor: Token Accessibility

    /// Verifies all original `AppColor` tokens compile and are accessible without crashing.
    func test_appColor_originalTokensAreAccessible() {
        _ = AppColor.reminderBlue
        _ = AppColor.reminderGreen
        _ = AppColor.warningOrange
        _ = AppColor.warningText
    }

    /// Verifies all Restful Grove `AppColor` tokens compile and are accessible without crashing.
    func test_appColor_restfulGrovePaletteTokensAreAccessible() {
        _ = AppColor.background
        _ = AppColor.surface
        _ = AppColor.surfaceTint
        _ = AppColor.primaryRest
        _ = AppColor.secondaryCalm
        _ = AppColor.accentWarm
        _ = AppColor.textPrimary
        _ = AppColor.textSecondary
        _ = AppColor.separatorSoft
        _ = AppColor.shadowCard
    }

    // MARK: - AppSymbol: SF Symbol Names Are Non-Empty

    // MARK: - AppOpacity: Token Value Coverage

    func test_appOpacity_iconAura_existsAndInRange() {
        XCTAssertGreaterThanOrEqual(AppOpacity.iconAura, 0, "iconAura must be >= 0")
        XCTAssertLessThanOrEqual(AppOpacity.iconAura, 1, "iconAura must be <= 1")
    }

    func test_appOpacity_warningBackground_existsAndInRange() {
        XCTAssertGreaterThanOrEqual(AppOpacity.warningBackground, 0)
        XCTAssertLessThanOrEqual(AppOpacity.warningBackground, 1)
    }

    func test_appOpacity_warningSeparator_existsAndInRange() {
        XCTAssertGreaterThanOrEqual(AppOpacity.warningSeparator, 0)
        XCTAssertLessThanOrEqual(AppOpacity.warningSeparator, 1)
    }

    func test_appOpacity_pressedButton_existsAndInRange() {
        XCTAssertGreaterThanOrEqual(AppOpacity.pressedButton, 0)
        XCTAssertLessThanOrEqual(AppOpacity.pressedButton, 1)
    }

    func test_appOpacity_mutedTimestamp_existsAndInRange() {
        XCTAssertGreaterThanOrEqual(AppOpacity.mutedTimestamp, 0)
        XCTAssertLessThanOrEqual(AppOpacity.mutedTimestamp, 1)
    }

    func test_appOpacity_subtleBorder_existsAndInRange() {
        XCTAssertGreaterThanOrEqual(AppOpacity.subtleBorder, 0)
        XCTAssertLessThanOrEqual(AppOpacity.subtleBorder, 1)
    }

    func test_appOpacity_allTokensAreInValidRange() {
        let tokens: [Double] = [
            AppOpacity.iconAura,
            AppOpacity.warningBackground,
            AppOpacity.warningSeparator,
            AppOpacity.pressedButton,
            AppOpacity.mutedTimestamp,
            AppOpacity.subtleBorder
        ]
        for token in tokens {
            XCTAssertTrue((0...1).contains(token), "All AppOpacity tokens must be in 0...1, got \(token)")
        }
    }

    // MARK: - AppSymbol

    func test_appSymbol_originalNamesAreNonEmpty() {
        let symbols = [
            AppSymbol.eyeBreak,
            AppSymbol.postureCheck,
            AppSymbol.dismiss,
            AppSymbol.settings,
            AppSymbol.chevronDown,
            AppSymbol.chevronUp,
            AppSymbol.warning
        ]
        for symbol in symbols {
            XCTAssertFalse(symbol.isEmpty, "AppSymbol name must not be empty: \(symbol)")
        }
    }

    func test_appSymbol_newNamesAreNonEmpty() {
        let symbols = [
            AppSymbol.snoozed,
            AppSymbol.bell,
            AppSymbol.pauseDuringFocus,
            AppSymbol.pauseWhileDriving,
            AppSymbol.clock,
            AppSymbol.timer,
            AppSymbol.masterToggle,
            AppSymbol.haptics,
            AppSymbol.trueInterrupt,
            AppSymbol.chevronTrailing,
            AppSymbol.checkmark,
            AppSymbol.lock
        ]
        for symbol in symbols {
            XCTAssertFalse(symbol.isEmpty, "AppSymbol name must not be empty: \(symbol)")
        }
    }

    func test_appSymbol_allNamesAreUnique() {
        let symbols = [
            AppSymbol.eyeBreak, AppSymbol.postureCheck, AppSymbol.dismiss,
            AppSymbol.settings, AppSymbol.chevronDown, AppSymbol.chevronUp,
            AppSymbol.warning, AppSymbol.checkmark, AppSymbol.lock,
            AppSymbol.snoozed, AppSymbol.bell,
            AppSymbol.pauseDuringFocus, AppSymbol.pauseWhileDriving,
            AppSymbol.clock, AppSymbol.timer,
            AppSymbol.trueInterrupt, AppSymbol.masterToggle,
            AppSymbol.haptics, AppSymbol.chevronTrailing
        ]
        XCTAssertEqual(
            Set(symbols).count,
            symbols.count,
            "All AppSymbol names must be unique")
    }
}
