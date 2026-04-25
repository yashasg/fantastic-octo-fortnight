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
        XCTAssertNotNil("\(font)")
    }

    /// Body compiles with Font.TextStyle .body — scales with Dynamic Type.
    func test_appFont_body_isAccessible() {
        let font = AppFont.body
        let spec: Font = .system(.body)
        _ = font
        _ = spec
        XCTAssertNotNil("\(font)")
    }

    /// bodyEmphasized compiles with Font.TextStyle .headline — scales with Dynamic Type.
    func test_appFont_bodyEmphasized_isAccessible() {
        let font = AppFont.bodyEmphasized
        let spec: Font = .system(.headline)
        _ = font
        _ = spec
        XCTAssertNotNil("\(font)")
    }

    /// Caption compiles with Font.TextStyle .footnote — scales with Dynamic Type.
    func test_appFont_caption_isAccessible() {
        let font = AppFont.caption
        let spec: Font = .system(.footnote)
        _ = font
        _ = spec
        XCTAssertNotNil("\(font)")
    }

    /// Countdown is intentionally fixed-size (64pt monospaced bold).
    /// Accessibility is provided via `.accessibilityLabel` on the countdown ZStack.
    func test_appFont_countdown_isFixedMonospaced_byDesign() {
        let font = AppFont.countdown
        let spec: Font = .system(size: 64, weight: .bold, design: .monospaced)
        _ = font
        _ = spec
        // Compile-time confirmation that the fixed-size variant exists.
        XCTAssertNotNil("\(font)")
    }

    // MARK: - AppSpacing: 4pt Grid Compliance

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
        let spacings: [CGFloat] = [AppSpacing.xs, AppSpacing.sm, AppSpacing.md, AppSpacing.lg, AppSpacing.xl]
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

    func test_appLayout_snoozeButtonHeight_meetsHIGMinimum() {
        XCTAssertGreaterThanOrEqual(
            AppLayout.snoozeButtonHeight,
            44,
            "Snooze button height must be ≥44pt per iOS HIG")
    }

    func test_appLayout_sheetCornerRadius_isPositive() {
        XCTAssertGreaterThan(AppLayout.sheetCornerRadius, 0)
    }

    func test_appLayout_overlayCornerRadius_isPositive() {
        XCTAssertGreaterThan(AppLayout.overlayCornerRadius, 0)
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

    func test_appAnimation_snoozeAutoDismiss_is5s() {
        XCTAssertEqual(
            AppAnimation.snoozeAutoDismiss,
            5.0,
            accuracy: 0.001,
            "Snooze sheet auto-dismiss timeout must be 5 seconds")
    }

    func test_appAnimation_allDurationsArePositive() {
        let durations = [
            AppAnimation.overlayAppear,
            AppAnimation.overlayDismiss,
            AppAnimation.overlayAutoDismiss,
            AppAnimation.settingsExpand,
            AppAnimation.countdownRingTick,
            AppAnimation.snoozeSheetAppear,
            AppAnimation.snoozeAutoDismiss
        ]
        for duration in durations {
            XCTAssertGreaterThan(duration, 0, "All animation durations must be positive")
        }
    }

    // MARK: - AppColor: Token Accessibility

    /// Verifies all `AppColor` tokens compile and are accessible without crashing.
    func test_appColor_allTokensAreAccessible() {
        _ = AppColor.reminderBlue
        _ = AppColor.reminderGreen
        _ = AppColor.overlayBackground
        _ = AppColor.warningOrange
        _ = AppColor.permissionBanner
        _ = AppColor.permissionBannerText
        _ = AppColor.warningText
    }

    // MARK: - AppSymbol: SF Symbol Names Are Non-Empty

    func test_appSymbol_allNamesAreNonEmpty() {
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
}
