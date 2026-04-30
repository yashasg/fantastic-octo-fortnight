// DesignSystem.swift
// kshana
//
// Design tokens — single source of truth for all visual decisions.
// Every color, font, spacing, and animation in the app references this file.

import CoreText
import SwiftUI

// MARK: - Semantic Color Literals

enum AppColor {
    /// Eye breaks — calming blue, adaptive for dark mode.
    /// Light: #2868B0 (5.6:1 on white — WCAG AA for normal text and CTA button text).
    /// Dark:  #82C3FF (high contrast on near-black — vivid, accessible blue for dark mode).
    static let reminderBlue = Color("ReminderBlue", bundle: .module)

    /// Posture checks — green, adaptive for dark mode.
    /// Light: #34C759. Dark: #30D158.
    static let reminderGreen = Color("ReminderGreen", bundle: .module)

    /// Warning icon tint — orange, adaptive for WCAG 1.4.11 non-text contrast (≥3:1).
    /// Light: #E07000 (~3.5:1 on white). Dark: #FF9500 (6.8:1 on near-black).
    static let warningOrange = Color("WarningOrange", bundle: .module)

    /// Warning text colour for body/label contexts — WCAG AA on both backgrounds.
    /// Light mode: dark amber #994F00 (6.1:1 on white). Dark mode: #FF9500 (6.8:1 on near-black).
    static let warningText = Color("WarningText", bundle: .module)

    // MARK: - Restful Grove Palette

    /// App background — warm off-white / deep forest night.
    /// Light: #F8F4EC. Dark: #101714.
    static let background = Color("RGBackground", bundle: .module)

    /// Card / sheet surface — pure warm white / slightly lighter forest.
    /// Light: #FFFDF8. Dark: #18221E.
    static let surface = Color("RGSurface", bundle: .module)

    /// Elevated surface tint — pale green wash / muted deep green.
    /// Light: #EEF6F1. Dark: #203128.
    static let surfaceTint = Color("RGSurfaceTint", bundle: .module)

    /// Primary action / eye-break tint — forest green / sage mint.
    /// Light: #2F6F5E (4.7:1 on white — WCAG AA large). Dark: #8ED2B1.
    static let primaryRest = Color("RGPrimaryRest", bundle: .module)

    /// Secondary / posture-check tint — teal blue / sky blue.
    /// Light: #286C8E (4.5:1 on white — WCAG AA). Dark: #8DBFE4.
    static let secondaryCalm = Color("RGSecondaryCalm", bundle: .module)

    /// Accent warm — terracotta / peach.
    /// Light: #9E4F39 (4.6:1 on white — WCAG AA). Dark: #F0B79B.
    static let accentWarm = Color("RGAccentWarm", bundle: .module)

    /// Primary text — deep forest / near-white mint.
    /// Light: #22352D. Dark: #EEF7F1.
    static let textPrimary = Color("RGTextPrimary", bundle: .module)

    /// Secondary / muted text — sage grey / light sage.
    /// Light: #5F6F67. Dark: #B9C8BF.
    static let textSecondary = Color("RGTextSecondary", bundle: .module)

    /// Subtle separator / divider — pale green / dark forest.
    /// Light: #D8E4DC. Dark: #314039.
    static let separatorSoft = Color("RGSeparatorSoft", bundle: .module)

    /// Card shadow tint — deep forest tint used by `SoftElevation` in light mode.
    /// Applied at 10% opacity; dark mode uses a border overlay instead.
    static let shadowCard = Color("RGShadowCard", bundle: .module)

    // MARK: - Logo-specific tokens

    /// Yang (mint) half of the yin-yang logo — logo-scoped, do NOT use for generic surface fills.
    /// Light: #50C4A4 (visible saturated mint against sage and cream bg).
    /// Dark:  #2A6A52 (mid-green, 3.7:1 contrast against the light sage half #8ED2B1).
    static let logoYangMint = Color("LogoYangMint", bundle: .module)
}

// MARK: - Typography

enum AppTypography {
    private static let fontFamilyName = "Nunito"
    private static let fontFileNames = [
        "Nunito-Regular",
        "Nunito-Italic"
    ]

    /// Registers bundled OFL-licensed Nunito font files for SwiftUI custom-font lookup.
    static func registerFonts() {
        for fileName in fontFileNames {
            guard
                let url = Bundle.module.url(forResource: fileName, withExtension: "ttf", subdirectory: "Fonts"),
                let dataProvider = CGDataProvider(url: url as CFURL),
                let font = CGFont(dataProvider)
            else {
                continue
            }

            var error: Unmanaged<CFError>?
            CTFontManagerRegisterGraphicsFont(font, &error)
        }
    }

    /// Overlay headline — custom font scales with Dynamic Type (base: 28pt bold).
    static let headline: Font = .custom(fontFamilyName, size: 28, relativeTo: .title).weight(.bold)

    /// Body text — custom font scales with Dynamic Type (base: 17pt regular).
    static let body: Font = .custom(fontFamilyName, size: 17, relativeTo: .body)

    /// Snooze sheet title / settings labels — custom font scales with Dynamic Type (17pt semibold).
    static let bodyEmphasized: Font = .custom(fontFamilyName, size: 17, relativeTo: .headline).weight(.semibold)

    /// Caption — custom font scales with Dynamic Type (base: 13pt regular).
    static let caption: Font = .custom(fontFamilyName, size: 13, relativeTo: .footnote)

    /// Caption emphasized — custom font scales with Dynamic Type (base: 13pt semibold).
    static let captionEmphasized: Font = .custom(fontFamilyName, size: 13, relativeTo: .footnote).weight(.semibold)

    /// Secondary action buttons (onboarding, secondary CTAs) — custom font scales with Dynamic Type (base: 15pt regular).
    static let secondaryAction: Font = .custom(fontFamilyName, size: 15, relativeTo: .subheadline)

    /// Overlay dismiss button — custom font scales with Dynamic Type (base: 28pt medium).
    static let overlayDismiss: Font = .custom(fontFamilyName, size: 28, relativeTo: .title).weight(.medium)

    /// Countdown digits — fixed 64pt monospaced bold (decorative; not scaled).
    /// VoiceOver exposes a labelled accessibility element instead of reading this text directly.
    static let countdown: Font = .system(size: 64, weight: .bold, design: .monospaced)

    /// Settings row icon — SF Symbol inside a 32 pt tinted circle (decorative, accessibility-hidden).
    static let settingsRowIcon: Font = .system(size: 15, weight: .semibold)

    /// Warning icon — SF Symbol inside a 36 pt warning banner circle (decorative, accessibility-hidden).
    static let warningIcon: Font = .system(size: 16, weight: .semibold)

    /// Reminder card icon — SF Symbol in an onboarding reminder card; scales with Dynamic Type.
    static let reminderCardIcon: Font = .system(.title2)
}

enum AppFont {
    static let headline = AppTypography.headline
    static let body = AppTypography.body
    static let bodyEmphasized = AppTypography.bodyEmphasized
    static let caption = AppTypography.caption
    static let captionEmphasized = AppTypography.captionEmphasized
    static let secondaryAction = AppTypography.secondaryAction
    static let overlayDismiss = AppTypography.overlayDismiss
    static let countdown = AppTypography.countdown
    static let settingsRowIcon = AppTypography.settingsRowIcon
    static let warningIcon = AppTypography.warningIcon
    static let reminderCardIcon = AppTypography.reminderCardIcon
}

// MARK: - Spacing (4pt grid)

enum AppSpacing {
    /// 4pt — hair gap, icon badges
    static let xs: CGFloat = 4
    /// 8pt — tight internal padding, icon-label gap
    static let sm: CGFloat = 8
    /// 16pt — standard section padding, card insets
    static let md: CGFloat = 16
    /// 24pt — section gap, large card padding
    static let lg: CGFloat = 24
    /// 32pt — screen-level breathing room, hero spacing
    static let xl: CGFloat = 32
    /// 40pt — large section dividers, full-bleed padding
    static let xxl: CGFloat = 40
}

// MARK: - Animation Durations

enum AppAnimation {
    /// Overlay appears (slide up from bottom) — 0.3s ease-out
    static let overlayAppear: Double = 0.3
    /// Overlay manual dismiss (slide down) — 0.2s ease-in
    static let overlayDismiss: Double = 0.2
    /// Overlay auto-dismiss (fade out) — 0.3s linear
    static let overlayAutoDismiss: Double = 0.3
    /// Settings row inline expansion — 0.2s ease-in-out
    static let settingsExpand: Double = 0.2
    /// Onboarding screen fade-in entrance — 0.4s
    static let onboardingFadeIn: Double = 0.4
    /// Onboarding screen fade-in entrance delay — 0.1s
    static let onboardingFadeInDelay: Double = 0.1
    /// Countdown ring — continuous, driven by a 1-second timer tick
    static let countdownRingTick: Double = 1.0
    /// Calming entrance for focal panels / overlay: 0.5s ease-out.
    /// Linus: use `calmingEntranceCurve` in OverlayView in place of the current 0.3s slide.
    static let calmingEntranceDuration: Double = 0.5
    /// Status crossfade duration — icon + text fade when active ↔ paused changes.
    static let statusCrossfadeDuration: Double = 0.25

    // Convenience SwiftUI Animation values
    static let overlayAppearCurve: Animation  = .easeOut(duration: overlayAppear)
    static let overlayDismissCurve: Animation = .easeIn(duration: overlayDismiss)
    static let overlayFadeCurve: Animation    = .linear(duration: overlayAutoDismiss)
    static let settingsExpandCurve: Animation = .easeInOut(duration: settingsExpand)
    static let countdownRingCurve: Animation  = .linear(duration: countdownRingTick)
    /// Onboarding transition used in ContentView (hasSeenOnboarding toggle)
    static let onboardingTransition: Animation = .easeInOut(duration: onboardingFadeIn)
    /// Onboarding screen fade-in entrance animation (easeOut + delay)
    static let onboardingFadeInCurve: Animation = .easeOut(duration: onboardingFadeIn).delay(onboardingFadeInDelay)
    /// Calming entrance — slower ease-out for fade + gentle slide. No bounce.
    /// Adopt in OverlayView for a softer, less utilitarian entrance.
    static let calmingEntranceCurve: Animation = .easeOut(duration: calmingEntranceDuration)
    /// Status crossfade — drives icon + text opacity when active/paused state changes.
    static let statusCrossfadeCurve: Animation = .easeInOut(duration: statusCrossfadeDuration)
    /// Yin-yang entrance spin — custom deceleration curve for the initial rotation.
    static let yinYangSpinCurve: Animation = .timingCurve(0.2, 0.0, 0.0, 1.0, duration: 2)
}

// MARK: - SF Symbol Names

enum AppSymbol {
    /// Eye break reminder icon (overlay + settings row)
    static let eyeBreak      = "eye.fill"
    /// Posture check reminder icon (overlay + settings row)
    static let postureCheck  = "figure.stand"
    /// Dismiss / close button on overlay
    static let dismiss       = "xmark.circle.fill"
    /// Settings / gear button on overlay (bottom-center)
    static let settings      = "gearshape.fill"
    /// Chevron for collapsed settings row
    static let chevronDown   = "chevron.down"
    /// Chevron for expanded settings row
    static let chevronUp     = "chevron.up"
    /// Permission warning banner icon
    static let warning       = "exclamationmark.triangle.fill"
    /// Snoozed / paused state icon
    static let snoozed       = "moon.zzz.fill"
    /// Bell / snooze-cancel icon
    static let bell              = "bell.fill"
    /// Smart Pause — pause during Focus mode
    static let pauseDuringFocus  = "moon.fill"
    /// Smart Pause — pause while driving
    static let pauseWhileDriving = "car.fill"
    /// Interval / clock icon
    static let clock             = "clock"
    /// Break duration / timer icon
    static let timer             = "timer"
    static let trueInterrupt     = "lock.shield.fill"
    static let masterToggle      = "power"
    static let haptics           = "hand.tap.fill"
    static let chevronTrailing   = "chevron.right"
    static let checkmark         = "checkmark.circle.fill"
    static let lock              = "lock.fill"
}

// MARK: - Layout Constants

enum AppLayout {
    /// Minimum tap target size (iOS HIG minimum)
    static let minTapTarget: CGFloat = 44
    /// Overlay icon size (centered, prominent)
    static let overlayIconSize: CGFloat = 80
    /// Countdown ring diameter
    static let countdownRingDiameter: CGFloat = 160
    /// Countdown ring stroke width
    static let countdownRingStroke: CGFloat = 8
    /// Onboarding content max width for iPad-friendly layout
    static let onboardingMaxContentWidth: CGFloat = 540
    /// Onboarding hero illustration icon size
    static let onboardingIllustrationSize: CGFloat = 72
    /// Entrance slide offset for CalmingEntrance animations — gentle 20pt upward drift.
    static let entranceSlideOffset: CGFloat = 20
    // AppLayout.overlayIconSize / onboardingIllustrationSize / settingsRowIconWidth are
    // intentionally fixed-size (decorative, accessibility-hidden). See AppFont.countdown for precedent.
    /// Setup preview card icon column width (decorative icon frame)
    static let settingsRowIconWidth: CGFloat = 40

    // MARK: Corner Radii
    /// 12pt — small interactive controls (chips, tags, compact buttons)
    static let radiusSmall: CGFloat = 12
    /// 20pt — content cards, modals, sheets
    static let radiusCard: CGFloat = 20
    /// 28pt — large surfaces, hero cards, bottom sheets
    static let radiusLarge: CGFloat = 28
    /// 999pt — pill shape (capsule buttons, toggles); use `.infinity` semantics
    static let radiusPill: CGFloat = 999
}

// MARK: - Opacity Constants

enum AppOpacity {
    /// Soft icon aura / decorative glow ring — 12%.
    static let iconAura: Double = 0.12
    /// Warning row background wash — 10%.
    static let warningBackground: Double = 0.10
    /// Warning row separator tint — 25%.
    static let warningSeparator: Double = 0.25
    /// Pressed-state button dimming — 68%.
    static let pressedButton: Double = 0.68
    /// Muted timestamp / tertiary text — 72%.
    static let mutedTimestamp: Double = 0.72
    /// Subtle border ring (SoftElevation, yin-yang) — 65%.
    static let subtleBorder: Double = 0.65
}

// MARK: - Elevation

/// Icon font tokens that depend on AppLayout size constants.
extension AppTypography {
    /// Overlay / home-screen status icon — SF Symbol sized to `overlayIconSize` (decorative).
    static let overlayIcon: Font = .system(size: AppLayout.overlayIconSize)
    /// Home yin-yang logo symbol — sized relative to the home hero icon frame.
    static let homeLogoIcon: Font = .system(size: AppLayout.overlayIconSize * 0.42, weight: .semibold)
    /// Onboarding hero illustration icon — SF Symbol sized to `onboardingIllustrationSize` (decorative).
    static let illustrationIcon: Font = .system(size: AppLayout.onboardingIllustrationSize, weight: .semibold)
}

extension AppFont {
    static let overlayIcon = AppTypography.overlayIcon
    static let homeLogoIcon = AppTypography.homeLogoIcon
    static let illustrationIcon = AppTypography.illustrationIcon
}

/// Applies a soft shadow in light mode and a flat border in dark mode.
///
/// Use `.softElevation()` instead of a raw `.shadow()` to ensure the effect
/// adapts correctly between colour schemes without any additional boilerplate.
struct SoftElevation: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = AppLayout.radiusCard

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(AppColor.separatorSoft.opacity(AppOpacity.subtleBorder), lineWidth: 0.5)
                )
        } else {
            content
                .shadow(
                    color: AppColor.shadowCard.opacity(AppOpacity.warningBackground),
                    radius: 8,
                    x: 0,
                    y: 3
                )
        }
    }
}

extension View {
    /// Applies `SoftElevation` — soft shadow in light mode, thin border in dark mode.
    /// - Parameter cornerRadius: Corner radius used for the dark-mode border overlay.
    ///   Defaults to `AppLayout.radiusCard`.
    func softElevation(cornerRadius: CGFloat = AppLayout.radiusCard) -> some View {
        modifier(SoftElevation(cornerRadius: cornerRadius))
    }
}
