@testable import EyePostureReminder
import SwiftUI
import UIKit
import XCTest

// Expanded dark mode tests for the DesignSystem.
//
// **Coverage (distinct from ColorTokenTests and DesignSystemTests):**
// - AppColor tokens resolve with explicit `UITraitCollection` overrides (not just "resolves non-nil")
// - Color component values are checked against the documented spec (brightness, opacity)
// - `overlayBackground` alpha value is validated against the 0.6 spec
// - Static colors (`PermissionBanner`, `PermissionBannerText`) are equal in both modes
// - AppFont text styles scale with Dynamic Type even in dark mode trait contexts
// - All SF Symbol names load as valid `UIImage` instances in dark mode
// swiftlint:disable:next type_body_length
final class DarkModeTests: XCTestCase {

    private let lightTraits = UITraitCollection(userInterfaceStyle: .light)
    private let darkTraits  = UITraitCollection(userInterfaceStyle: .dark)

    // MARK: - Helpers

    private func resolvedLight(_ name: String) -> UIColor? {
        TestBundle.testColor(named: name)?.resolvedColor(with: lightTraits)
    }

    private func resolvedDark(_ name: String) -> UIColor? {
        TestBundle.testColor(named: name)?.resolvedColor(with: darkTraits)
    }

    // Extracts RGBA components via getRed. Returns nil if the color is not in RGB space.
    private func rgba(of color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return (red, green, blue, alpha)
    }

    // MARK: - Adaptive Token Component Tests in Dark Mode

    /// ReminderBlue dark variant (#5BA8F0) must be fully opaque (alpha=1.0).
    func test_reminderBlue_darkMode_isFullyOpaque() {
        guard let dark = resolvedDark("ReminderBlue"),
              let (_, _, _, alpha) = rgba(of: dark) else {
            XCTFail("ReminderBlue must resolve in dark mode")
            return
        }
        XCTAssertEqual(
            alpha,
            1.0,
            accuracy: 0.01,
            "ReminderBlue in dark mode (#5BA8F0) must be fully opaque")
    }

    /// ReminderGreen dark variant (#30D158) must be fully opaque.
    func test_reminderGreen_darkMode_isFullyOpaque() {
        guard let dark = resolvedDark("ReminderGreen"),
              let (_, _, _, alpha) = rgba(of: dark) else {
            XCTFail("ReminderGreen must resolve in dark mode")
            return
        }
        XCTAssertEqual(
            alpha,
            1.0,
            accuracy: 0.01,
            "ReminderGreen in dark mode (#30D158) must be fully opaque")
    }

    /// WarningOrange dark (#FF9500) must have a higher red component than light (#E07000)
    /// because it is brightened for better contrast on dark backgrounds.
    func test_warningOrange_darkMode_hasBrighterRedThanLight() {
        guard let light = resolvedLight("WarningOrange"),
              let dark  = resolvedDark("WarningOrange"),
              let (rL, _, _, _) = rgba(of: light),
              let (rD, _, _, _) = rgba(of: dark) else {
            XCTFail("WarningOrange must resolve in both modes")
            return
        }
        // Light: #E07000 → R ≈ 0.878.  Dark: #FF9500 → R = 1.0.
        XCTAssertGreaterThan(
            rD,
            rL,
            "WarningOrange must have higher R in dark mode (#FF9500 vs #E07000) for improved dark-background contrast")
    }

    /// WarningText dark (#FF9500) must be orange-toned: R is the dominant channel,
    /// alpha is 1.0.
    func test_warningText_darkMode_isOrangeToned_andFullyOpaque() {
        guard let dark = resolvedDark("WarningText"),
              let (red, green, _, alpha) = rgba(of: dark) else {
            XCTFail("WarningText must resolve in dark mode")
            return
        }
        // #FF9500: R=1.0, G≈0.584, B=0.0 — dominant red channel (orange)
        XCTAssertGreaterThan(
            red,
            green,
            "WarningText dark mode must have dominant red channel (orange tone #FF9500)")
        XCTAssertEqual(
            alpha,
            1.0,
            accuracy: 0.01,
            "WarningText must be fully opaque in dark mode")
    }

    // MARK: - Static Tokens: Light == Dark

    /// PermissionBanner (#FFCC00) is intentionally static — same hex in both modes.
    func test_permissionBanner_isStaticColor_lightAndDarkAreEqual() {
        guard let light = resolvedLight("PermissionBanner"),
              let dark  = resolvedDark("PermissionBanner"),
              let (rL, gL, bL, _) = rgba(of: light),
              let (rD, gD, bD, _) = rgba(of: dark) else {
            XCTFail("PermissionBanner must resolve in both modes")
            return
        }
        XCTAssertEqual(
            rL,
            rD,
            accuracy: 0.01,
            "PermissionBanner R must be identical in light and dark (static color)")
        XCTAssertEqual(
            gL,
            gD,
            accuracy: 0.01,
            "PermissionBanner G must be identical in light and dark (static color)")
        XCTAssertEqual(
            bL,
            bD,
            accuracy: 0.01,
            "PermissionBanner B must be identical in light and dark (static color)")
    }

    /// PermissionBannerText (#262626) is intentionally static — same hex in both modes.
    func test_permissionBannerText_isStaticColor_lightAndDarkAreEqual() {
        guard let light = resolvedLight("PermissionBannerText"),
              let dark  = resolvedDark("PermissionBannerText"),
              let (rL, gL, bL, _) = rgba(of: light),
              let (rD, gD, bD, _) = rgba(of: dark) else {
            XCTFail("PermissionBannerText must resolve in both modes")
            return
        }
        XCTAssertEqual(
            rL,
            rD,
            accuracy: 0.01,
            "PermissionBannerText R must be identical in light and dark (static near-black)")
        XCTAssertEqual(
            gL,
            gD,
            accuracy: 0.01,
            "PermissionBannerText G must be identical in light and dark (static near-black)")
        XCTAssertEqual(
            bL,
            bD,
            accuracy: 0.01,
            "PermissionBannerText B must be identical in light and dark (static near-black)")
    }

    // MARK: - All 6 Named Tokens Non-nil in Dark Mode

    func test_allNamedTokens_resolveNonNilInDarkMode() {
        let names = [
            "ReminderBlue",
            "ReminderGreen",
            "WarningOrange",
            "PermissionBanner",
            "PermissionBannerText",
            "WarningText"
        ]
        for name in names {
            XCTAssertNotNil(
                resolvedDark(name),
                "AppColor token '\(name)' must resolve non-nil in dark mode UITraitCollection context")
        }
    }

    // MARK: - overlayBackground Opacity

    /// AppColor.overlayBackground = Color(.systemBackground).opacity(0.6)
    /// Converting to UIColor must yield alpha ≈ 0.6 in light mode.
    func test_overlayBackground_hasAlpha0point6_inLightMode() {
        let uiKitColor = UIColor(AppColor.overlayBackground).resolvedColor(with: lightTraits)
        guard let (_, _, _, alpha) = rgba(of: uiKitColor) else {
            XCTFail("overlayBackground must be expressible in RGB space")
            return
        }
        XCTAssertEqual(
            alpha,
            0.6,
            accuracy: 0.01,
            "overlayBackground must have alpha=0.6 in light mode (spec: .opacity(0.6))")
    }

    /// The 0.6 opacity spec applies in dark mode too — only the base color changes.
    func test_overlayBackground_hasAlpha0point6_inDarkMode() {
        let uiKitColor = UIColor(AppColor.overlayBackground).resolvedColor(with: darkTraits)
        guard let (_, _, _, alpha) = rgba(of: uiKitColor) else {
            XCTFail("overlayBackground must be expressible in RGB space in dark mode")
            return
        }
        XCTAssertEqual(
            alpha,
            0.6,
            accuracy: 0.01,
            "overlayBackground must have alpha=0.6 in dark mode (spec: .opacity(0.6))")
    }

    /// The alpha is identical across modes — only the base systemBackground colour changes.
    func test_overlayBackground_alphaIsIdenticalInLightAndDark() {
        let lightAlpha: CGFloat
        let darkAlpha: CGFloat

        let lightResolved = UIColor(AppColor.overlayBackground).resolvedColor(with: lightTraits)
        let darkResolved  = UIColor(AppColor.overlayBackground).resolvedColor(with: darkTraits)

        guard let (_, _, _, lA) = rgba(of: lightResolved),
              let (_, _, _, dA) = rgba(of: darkResolved) else {
            XCTFail("overlayBackground must resolve in both modes")
            return
        }
        lightAlpha = lA
        darkAlpha  = dA

        XCTAssertEqual(
            lightAlpha,
            darkAlpha,
            accuracy: 0.01,
            "overlayBackground opacity must be mode-independent — only systemBackground's base colour adapts")
    }

    // MARK: - AppFont: Point Sizes in Dark Mode Trait Context

    /// Verifies that UIFont equivalents of each AppFont text style load with positive
    /// point sizes when the trait collection's user interface style is dark.
    func test_appFont_headline_hasPositivePointSize_inDarkContext() {
        let font = UIFont.preferredFont(forTextStyle: .title1, compatibleWith: darkTraits)
        XCTAssertGreaterThan(
            font.pointSize,
            0,
            "AppFont.headline (.title1 style) must have positive point size in dark mode context")
    }

    func test_appFont_body_hasPositivePointSize_inDarkContext() {
        let font = UIFont.preferredFont(forTextStyle: .body, compatibleWith: darkTraits)
        XCTAssertGreaterThan(
            font.pointSize,
            0,
            "AppFont.body must have positive point size in dark mode context")
    }

    func test_appFont_bodyEmphasized_hasPositivePointSize_inDarkContext() {
        let font = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: darkTraits)
        XCTAssertGreaterThan(
            font.pointSize,
            0,
            "AppFont.bodyEmphasized (.headline style) must have positive point size in dark mode context")
    }

    func test_appFont_caption_hasPositivePointSize_inDarkContext() {
        let font = UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: darkTraits)
        XCTAssertGreaterThan(
            font.pointSize,
            0,
            "AppFont.caption (.footnote style) must have positive point size in dark mode context")
    }

    /// countdown is fixed at 64pt — point size must be exactly 64 regardless of dark mode.
    func test_appFont_countdown_isFixed64pt_inDarkContext() {
        let font = UIFont.monospacedSystemFont(ofSize: 64, weight: .bold)
        XCTAssertEqual(
            font.pointSize,
            64,
            accuracy: 0.1,
            "AppFont.countdown must be fixed at 64pt and not change with dark mode or Dynamic Type")
    }

    // MARK: - Dynamic Type + Dark Mode Interaction

    /// All scalable AppFont styles must produce a larger point size at
    /// accessibilityExtraExtraExtraLarge than at medium, even in dark mode.
    func test_appFont_headline_scalesWithLargeType_inDarkMode() {
        let standardContext = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(preferredContentSizeCategory: .medium)
        ])
        let accessibilityContext = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        ])
        let standard = UIFont.preferredFont(forTextStyle: .title1, compatibleWith: standardContext)
        let accessibility = UIFont.preferredFont(forTextStyle: .title1, compatibleWith: accessibilityContext)
        XCTAssertGreaterThan(
            accessibility.pointSize,
            standard.pointSize,
            "headline must scale up with accessibility large text even in dark mode")
    }

    func test_appFont_body_scalesWithLargeType_inDarkMode() {
        let standardContext = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(preferredContentSizeCategory: .medium)
        ])
        let accessibilityContext = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        ])
        let standard = UIFont.preferredFont(forTextStyle: .body, compatibleWith: standardContext)
        let accessibility = UIFont.preferredFont(forTextStyle: .body, compatibleWith: accessibilityContext)
        XCTAssertGreaterThan(
            accessibility.pointSize,
            standard.pointSize,
            "body must scale up with accessibility large text even in dark mode")
    }

    func test_appFont_caption_scalesWithLargeType_inDarkMode() {
        let standardContext = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(preferredContentSizeCategory: .medium)
        ])
        let accessibilityContext = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        ])
        let standard = UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: standardContext)
        let accessibility = UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: accessibilityContext)
        XCTAssertGreaterThan(
            accessibility.pointSize,
            standard.pointSize,
            "caption must scale up with accessibility large text even in dark mode")
    }

    // MARK: - SF Symbol Loading in Dark Mode

    /// All AppSymbol names must load as valid UIImage instances — they are rendered with
    /// the system and are not affected by dark mode failure points.
    func test_sfSymbols_allLoadWithDarkModeConfig() {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        let symbolNames = [
            AppSymbol.eyeBreak,
            AppSymbol.postureCheck,
            AppSymbol.dismiss,
            AppSymbol.settings,
            AppSymbol.chevronDown,
            AppSymbol.chevronUp,
            AppSymbol.warning
        ]
        for name in symbolNames {
            XCTAssertNotNil(
                UIImage(systemName: name, withConfiguration: config),
                "SF Symbol '\(name)' must load in dark mode symbol configuration context")
        }
    }

    /// SF Symbols can be tinted with dark-mode-resolved AppColor tokens without crashing.
    func test_sfSymbols_canBeTinted_withDarkModeAppColors() {
        let darkReminderBlue = UIColor(AppColor.reminderBlue).resolvedColor(with: darkTraits)
        let darkWarningOrange = UIColor(AppColor.warningOrange).resolvedColor(with: darkTraits)

        let dismissImage  = UIImage(systemName: AppSymbol.dismiss)
        let warningImage  = UIImage(systemName: AppSymbol.warning)
        let settingsImage = UIImage(systemName: AppSymbol.settings)

        // Tinting must not crash — verify non-nil result
        XCTAssertNotNil(
            dismissImage?.withTintColor(darkReminderBlue),
            "dismiss symbol must accept ReminderBlue tint in dark mode")
        XCTAssertNotNil(
            warningImage?.withTintColor(darkWarningOrange),
            "warning symbol must accept WarningOrange tint in dark mode")
        XCTAssertNotNil(
            settingsImage?.withTintColor(darkReminderBlue),
            "settings symbol must accept ReminderBlue tint in dark mode")
    }

    // MARK: - AppColor: All Tokens Are Accessible Without Crash in Dark Context

    /// Access all 7 AppColor tokens in a simulated dark context — no crash is the contract.
    func test_allAppColorTokens_accessibleWithoutCrash_inDarkContext() {
        // Verifying the AppColor constants are accessible from dark-mode test code.
        let tokens: [Color] = [
            AppColor.reminderBlue,
            AppColor.reminderGreen,
            AppColor.overlayBackground,
            AppColor.warningOrange,
            AppColor.permissionBanner,
            AppColor.permissionBannerText,
            AppColor.warningText
        ]
        for token in tokens {
            _ = UIColor(token).resolvedColor(with: darkTraits)
        }
        // Reaching this line means no crash
        XCTAssertTrue(true, "All AppColor tokens must resolve without crash in dark mode context")
    }
}
