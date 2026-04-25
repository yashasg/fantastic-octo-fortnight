@testable import EyePostureReminder
import UIKit
import XCTest

/// Tests that all color tokens in the `Colors.xcassets` Asset Catalog resolve correctly.
///
/// ## What these tests verify:
/// - All 6 named colors load from the asset catalog (non-nil via `UIColor(named:)`)
/// - Light and dark variants are distinct (catalog has both appearances)
/// - Color names in the catalog match the constant names in `AppColor` (DesignSystem.swift)
/// - Asset catalog is properly bundled (reachable at runtime in the iOS Simulator context)
///
/// ## Color tokens under test (Colors.xcassets):
/// | Catalog name         | AppColor constant       |
/// |----------------------|-------------------------|
/// | ReminderBlue         | AppColor.reminderBlue   |
/// | ReminderGreen        | AppColor.reminderGreen  |
/// | WarningOrange        | AppColor.warningOrange  |
/// | PermissionBanner     | AppColor.permissionBanner |
/// | PermissionBannerText | AppColor.permissionBannerText |
/// | WarningText          | AppColor.warningText    |
///
/// ## Bundle note:
/// These tests run in the iOS Simulator context where the app bundle contains the compiled
/// asset catalog. `UIColor(named:)` without a bundle argument searches the main bundle first.
/// If tests run outside a simulator context, `UIColor(named:)` may return nil — use the
/// `TestBundle.testColor(named:)` helper which also searches the EyePostureReminder module bundle.
final class ColorTokenTests: XCTestCase {

    // MARK: - Helpers

    private let lightTraits = UITraitCollection(userInterfaceStyle: .light)
    private let darkTraits  = UITraitCollection(userInterfaceStyle: .dark)

    /// Resolves a color for light mode via the production module bundle.
    private func resolvedLight(named name: String) -> UIColor? {
        TestBundle.testColor(named: name)?.resolvedColor(with: lightTraits)
    }

    /// Resolves a color for dark mode via the production module bundle.
    private func resolvedDark(named name: String) -> UIColor? {
        TestBundle.testColor(named: name)?.resolvedColor(with: darkTraits)
    }

    // MARK: - All 6 Color Tokens Resolve (Non-nil)

    func test_reminderBlue_resolvesFromCatalog() {
        XCTAssertNotNil(
            TestBundle.testColor(named: "ReminderBlue"),
            "ReminderBlue must exist in the Colors asset catalog")
    }

    func test_reminderGreen_resolvesFromCatalog() {
        XCTAssertNotNil(
            TestBundle.testColor(named: "ReminderGreen"),
            "ReminderGreen must exist in the Colors asset catalog")
    }

    func test_warningOrange_resolvesFromCatalog() {
        XCTAssertNotNil(
            TestBundle.testColor(named: "WarningOrange"),
            "WarningOrange must exist in the Colors asset catalog")
    }

    func test_permissionBanner_resolvesFromCatalog() {
        XCTAssertNotNil(
            TestBundle.testColor(named: "PermissionBanner"),
            "PermissionBanner must exist in the Colors asset catalog")
    }

    func test_permissionBannerText_resolvesFromCatalog() {
        XCTAssertNotNil(
            TestBundle.testColor(named: "PermissionBannerText"),
            "PermissionBannerText must exist in the Colors asset catalog")
    }

    func test_warningText_resolvesFromCatalog() {
        XCTAssertNotNil(
            TestBundle.testColor(named: "WarningText"),
            "WarningText must exist in the Colors asset catalog")
    }

    // MARK: - All 6 Tokens: Light and Dark Variants Exist

    func test_reminderBlue_lightVariant_resolves() {
        XCTAssertNotNil(
            resolvedLight(named: "ReminderBlue"),
            "ReminderBlue must have a light-mode variant in the asset catalog")
    }

    func test_reminderBlue_darkVariant_resolves() {
        XCTAssertNotNil(
            resolvedDark(named: "ReminderBlue"),
            "ReminderBlue must have a dark-mode variant in the asset catalog")
    }

    func test_reminderGreen_lightVariant_resolves() {
        XCTAssertNotNil(resolvedLight(named: "ReminderGreen"))
    }

    func test_reminderGreen_darkVariant_resolves() {
        XCTAssertNotNil(resolvedDark(named: "ReminderGreen"))
    }

    func test_warningOrange_lightVariant_resolves() {
        XCTAssertNotNil(resolvedLight(named: "WarningOrange"))
    }

    func test_warningOrange_darkVariant_resolves() {
        XCTAssertNotNil(resolvedDark(named: "WarningOrange"))
    }

    func test_permissionBanner_lightVariant_resolves() {
        XCTAssertNotNil(resolvedLight(named: "PermissionBanner"))
    }

    func test_permissionBanner_darkVariant_resolves() {
        XCTAssertNotNil(resolvedDark(named: "PermissionBanner"))
    }

    func test_permissionBannerText_lightVariant_resolves() {
        XCTAssertNotNil(resolvedLight(named: "PermissionBannerText"))
    }

    func test_permissionBannerText_darkVariant_resolves() {
        XCTAssertNotNil(resolvedDark(named: "PermissionBannerText"))
    }

    func test_warningText_lightVariant_resolves() {
        XCTAssertNotNil(resolvedLight(named: "WarningText"))
    }

    func test_warningText_darkVariant_resolves() {
        XCTAssertNotNil(resolvedDark(named: "WarningText"))
    }

    // MARK: - Adaptive Colors: Light ≠ Dark

    func test_reminderBlue_lightAndDark_areDifferent() {
        guard let light = resolvedLight(named: "ReminderBlue"),
              let dark  = resolvedDark(named: "ReminderBlue") else {
            XCTFail("ReminderBlue must exist in catalog before comparing light/dark")
            return
        }
        // ReminderBlue: light #4A90D9, dark #5BA8F0 — they must differ
        XCTAssertFalse(
            colorsAreEqual(light, dark),
            "ReminderBlue light (#4A90D9) and dark (#5BA8F0) variants must be different")
    }

    func test_reminderGreen_lightAndDark_areDifferent() {
        guard let light = resolvedLight(named: "ReminderGreen"),
              let dark  = resolvedDark(named: "ReminderGreen") else {
            XCTFail("ReminderGreen must exist in catalog before comparing light/dark")
            return
        }
        // ReminderGreen: light #34C759, dark #30D158 — they must differ
        XCTAssertFalse(
            colorsAreEqual(light, dark),
            "ReminderGreen light (#34C759) and dark (#30D158) variants must be different")
    }

    func test_warningOrange_lightAndDark_areDifferent() {
        guard let light = resolvedLight(named: "WarningOrange"),
              let dark  = resolvedDark(named: "WarningOrange") else {
            XCTFail("WarningOrange must exist in catalog before comparing light/dark")
            return
        }
        XCTAssertFalse(
            colorsAreEqual(light, dark),
            "WarningOrange light and dark variants must be different for WCAG compliance")
    }

    func test_warningText_lightAndDark_areDifferent() {
        guard let light = resolvedLight(named: "WarningText"),
              let dark  = resolvedDark(named: "WarningText") else {
            XCTFail("WarningText must exist in catalog before comparing light/dark")
            return
        }
        XCTAssertFalse(
            colorsAreEqual(light, dark),
            "WarningText light and dark variants must be different for WCAG AA compliance")
    }

    // MARK: - Color Names Match DesignSystem Constants

    /// Verifies that the catalog color name "ReminderBlue" matches the AppColor.reminderBlue
    /// constant name convention. Both the camelCase Swift name and PascalCase catalog name
    /// reference the same conceptual token.
    func test_colorNameConvention_reminderBlue_matchesCatalogName() {
        // AppColor.reminderBlue uses UIColor(dynamicProvider:) today.
        // This test validates that the catalog asset name is "ReminderBlue" (not "reminder_blue",
        // "epr_reminderBlue", or another variant) — matching the Swift property name convention.
        let catalogName = "ReminderBlue"
        XCTAssertNotNil(
            TestBundle.testColor(named: catalogName),
            "Catalog name 'ReminderBlue' must match the AppColor.reminderBlue constant name (camelCase → PascalCase)")
    }

    func test_colorNameConvention_allTokensUsePascalCase() {
        let expectedNames = [
            "ReminderBlue",
            "ReminderGreen",
            "WarningOrange",
            "PermissionBanner",
            "PermissionBannerText",
            "WarningText"
        ]
        for name in expectedNames {
            XCTAssertNotNil(
                TestBundle.testColor(named: name),
                "Color '\(name)' must be in the asset catalog with PascalCase naming")
        }
    }

    func test_colorTokenCount_isSix() {
        // The design system defines exactly 6 named color tokens (excludes system/opacity tokens).
        let namedTokens = [
            "ReminderBlue",
            "ReminderGreen",
            "WarningOrange",
            "PermissionBanner",
            "PermissionBannerText",
            "WarningText"
        ]
        let resolvingTokens = namedTokens.filter { TestBundle.testColor(named: $0) != nil }
        XCTAssertEqual(
            resolvingTokens.count,
            6,
            "All 6 named color tokens must resolve from the asset catalog")
    }

    // MARK: - Regression: Colors Load from Module Bundle, Not Bundle.main

    /// Regression guard for the bundle: .module fix.
    /// Asset catalog colors live in the EyePostureReminder module bundle, NOT Bundle.main.
    /// If `Color("name", bundle: .module)` is reverted to `bundle: .main`, every token
    /// will silently resolve to clear/nil and these assertions will catch the regression.
    func test_allTokens_resolveFromModuleBundle() {
        let tokenNames = [
            "ReminderBlue", "ReminderGreen", "WarningOrange",
            "PermissionBanner", "PermissionBannerText", "WarningText"
        ]
        for name in tokenNames {
            XCTAssertNotNil(
                UIColor(named: name, in: TestBundle.module, compatibleWith: nil),
                "\(name) must resolve from the EyePostureReminder module bundle. "
                + "Regression: Color(\"name\", bundle: .module) is required — bundle: .main will return nil.")
        }
    }

    /// Verifies the asset catalog colors are NOT present in the host app's main bundle.
    /// This is the complementary check to `test_allTokens_resolveFromModuleBundle`:
    /// if colors were erroneously copied into the main bundle, the regression would be silent.
    func test_allTokens_areAbsentFromMainBundle() {
        let tokenNames = [
            "ReminderBlue", "ReminderGreen", "WarningOrange",
            "PermissionBanner", "PermissionBannerText", "WarningText"
        ]
        for name in tokenNames {
            XCTAssertNil(
                UIColor(named: name, in: Bundle.main, compatibleWith: nil),
                "\(name) must NOT be in Bundle.main — it belongs to the module asset catalog. "
                + "Regression: using bundle: .main instead of bundle: .module causes all colors to resolve as nil/clear.")
        }
    }

    // MARK: - Regression: All Tokens Have Non-Zero Alpha (Non-Clear)

    /// Verifies each of the 6 AppColor tokens resolves to a fully-opaque color (alpha == 1.0).
    /// A clear/nil color (alpha == 0) is the visible symptom of the bundle: .main regression —
    /// SwiftUI silently falls back to `.clear` when `Color(named:bundle:)` can't find the asset.
    func test_allTokens_haveNonZeroAlpha() {
        let tokenNames = [
            "ReminderBlue", "ReminderGreen", "WarningOrange",
            "PermissionBanner", "PermissionBannerText", "WarningText"
        ]
        for name in tokenNames {
            guard let uiColor = TestBundle.testColor(named: name) else {
                XCTFail("\(name) missing from module bundle — cannot check alpha"); continue
            }
            let resolvedLight = uiColor.resolvedColor(with: lightTraits)
            var alpha: CGFloat = 0
            resolvedLight.getRed(nil, green: nil, blue: nil, alpha: &alpha)
            XCTAssertGreaterThan(
                alpha, 0,
                "\(name) must have alpha > 0 in light mode. "
                + "Regression: alpha == 0 means bundle: .main was used and the color resolved to clear.")
        }
    }

    func test_reminderBlue_lightMode_hasNonZeroAlpha() {
        guard let color = resolvedLight(named: "ReminderBlue") else {
            XCTFail("ReminderBlue must resolve from module bundle"); return
        }
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertGreaterThan(alpha, 0, "ReminderBlue light-mode alpha must be > 0 (non-clear)")
    }

    func test_reminderGreen_lightMode_hasNonZeroAlpha() {
        guard let color = resolvedLight(named: "ReminderGreen") else {
            XCTFail("ReminderGreen must resolve from module bundle"); return
        }
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertGreaterThan(alpha, 0, "ReminderGreen light-mode alpha must be > 0 (non-clear)")
    }

    func test_warningOrange_lightMode_hasNonZeroAlpha() {
        guard let color = resolvedLight(named: "WarningOrange") else {
            XCTFail("WarningOrange must resolve from module bundle"); return
        }
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertGreaterThan(alpha, 0, "WarningOrange light-mode alpha must be > 0 (non-clear)")
    }

    func test_permissionBanner_lightMode_hasNonZeroAlpha() {
        guard let color = resolvedLight(named: "PermissionBanner") else {
            XCTFail("PermissionBanner must resolve from module bundle"); return
        }
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertGreaterThan(alpha, 0, "PermissionBanner light-mode alpha must be > 0 (non-clear)")
    }

    func test_permissionBannerText_lightMode_hasNonZeroAlpha() {
        guard let color = resolvedLight(named: "PermissionBannerText") else {
            XCTFail("PermissionBannerText must resolve from module bundle"); return
        }
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertGreaterThan(alpha, 0, "PermissionBannerText light-mode alpha must be > 0 (non-clear)")
    }

    func test_warningText_lightMode_hasNonZeroAlpha() {
        guard let color = resolvedLight(named: "WarningText") else {
            XCTFail("WarningText must resolve from module bundle"); return
        }
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertGreaterThan(alpha, 0, "WarningText light-mode alpha must be > 0 (non-clear)")
    }

    // MARK: - Regression: All 6 Tokens Resolve to Distinct Colors

    /// Verifies that no two AppColor tokens resolve to the same color in light mode.
    /// If bundle: .module is broken and all colors fall back to `.clear`, every token
    /// would be identical — this test catches that mass-collapse regression.
    func test_allTokens_areDistinctInLightMode() {
        let tokenNames = [
            "ReminderBlue", "ReminderGreen", "WarningOrange",
            "PermissionBanner", "PermissionBannerText", "WarningText"
        ]
        var resolved: [(String, UIColor)] = []
        for name in tokenNames {
            guard let color = resolvedLight(named: name) else {
                XCTFail("\(name) missing — cannot run distinctness check"); return
            }
            resolved.append((name, color))
        }
        for i in 0..<resolved.count {
            for j in (i + 1)..<resolved.count {
                let (nameA, colorA) = resolved[i]
                let (nameB, colorB) = resolved[j]
                XCTAssertFalse(
                    colorsAreEqual(colorA, colorB),
                    "'\(nameA)' and '\(nameB)' must not resolve to the same color. "
                    + "Regression: if all tokens resolve to clear (alpha=0), all are identical.")
            }
        }
    }

    // MARK: - Regression: AppColor.reminderBlue Tint Is Visible

    /// Verifies `AppColor.reminderBlue` — the primary tint applied via `.tint(AppColor.reminderBlue)` —
    /// is a visible, non-clear color when resolved from the module bundle.
    /// This is the most user-facing regression: every tinted control (toggles, buttons) goes
    /// invisible when the bundle: .main bug is present.
    func test_reminderBlue_swiftUIColor_isVisible() {
        let swiftUIColor = AppColor.reminderBlue
        let uiColor = UIColor(swiftUIColor)
        let resolved = uiColor.resolvedColor(with: lightTraits)
        var alpha: CGFloat = 0
        resolved.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertGreaterThan(
            alpha, 0,
            "AppColor.reminderBlue must produce a visible tint (alpha > 0 in light mode). "
            + "Regression: bundle: .main causes Color(named:bundle:) to return clear, "
            + "making every .tint(AppColor.reminderBlue) control invisible.")
    }

    func test_reminderBlue_darkMode_isVisible() {
        let swiftUIColor = AppColor.reminderBlue
        let uiColor = UIColor(swiftUIColor)
        let resolved = uiColor.resolvedColor(with: darkTraits)
        var alpha: CGFloat = 0
        resolved.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        XCTAssertGreaterThan(
            alpha, 0,
            "AppColor.reminderBlue must be visible in dark mode (alpha > 0). "
            + "Regression: bundle: .module is required for both light and dark appearances.")
    }

    // MARK: - Missing Color: Graceful Handling

    func test_unknownColorName_returnsNil() {
        // Regression guard: confirm UIColor(named:) returns nil for non-existent names.
        // This validates the test helper's "not nil" assertions above are meaningful.
        XCTAssertNil(
            TestBundle.testColor(named: "NonExistentColorXYZ123"),
            "UIColor(named:) must return nil for unknown color names")
    }

    // MARK: - Helpers

    /// Returns `true` if two `UIColor` instances have identical RGBA components (tolerance 0.005).
    private func colorsAreEqual(_ colorA: UIColor, _ colorB: UIColor, tolerance: CGFloat = 0.005) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        colorA.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        colorB.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1 - r2) < tolerance
            && abs(g1 - g2) < tolerance
            && abs(b1 - b2) < tolerance
            && abs(a1 - a2) < tolerance
    }
}
