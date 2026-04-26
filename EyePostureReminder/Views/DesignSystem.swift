// DesignSystem.swift
// Eye & Posture Reminder
//
// Design tokens — single source of truth for all visual decisions.
// Every color, font, spacing, and animation in the app references this file.

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

    /// Permission banner background (#FFCC00) — intentionally static warm yellow in both modes
    /// to signal caution. Only used on banner backgrounds; not for text or icon-only contexts.
    static let permissionBanner = Color("PermissionBanner", bundle: .module)

    /// Permission banner text — near-black (#262626) for WCAG AA contrast on the yellow banner.
    /// Always dark because it is exclusively used on the static yellow permissionBanner background.
    static let permissionBannerText = Color("PermissionBannerText", bundle: .module)

    /// Warning text colour for body/label contexts — WCAG AA on both backgrounds.
    /// Light mode: dark amber #994F00 (6.1:1 on white). Dark mode: #FF9500 (6.8:1 on near-black).
    static let warningText = Color("WarningText", bundle: .module)
}

// MARK: - Typography

enum AppFont {
    /// Overlay headline — scales with Dynamic Type (base: 28pt bold).
    static let headline: Font = .system(.title).weight(.bold)

    /// Body text — scales with Dynamic Type (base: 17pt regular).
    static let body: Font = .system(.body)

    /// Snooze sheet title / settings labels — scales with Dynamic Type (17pt semibold).
    static let bodyEmphasized: Font = .system(.headline)

    /// Caption — scales with Dynamic Type (base: 13pt regular).
    static let caption: Font = .system(.footnote)

    /// Secondary action buttons (onboarding, secondary CTAs) — scales with Dynamic Type (base: 15pt regular).
    static let secondaryAction: Font = .system(.subheadline)

    /// Overlay dismiss button — scales with Dynamic Type (base: 28pt medium).
    static let overlayDismiss: Font = .system(.title).weight(.medium)

    /// Countdown digits — fixed 64pt monospaced bold (decorative; not scaled).
    /// VoiceOver exposes a labelled accessibility element instead of reading this text directly.
    static let countdown: Font = .system(size: 64, weight: .bold, design: .monospaced)
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
    /// Overlay corner radius (for non-fullscreen contexts)
    static let overlayCornerRadius: CGFloat = 24
    /// Card / small-surface corner radius (onboarding cards, preview tiles)
    static let cardCornerRadius: CGFloat = 16
    /// Onboarding content max width for iPad-friendly layout
    static let onboardingMaxContentWidth: CGFloat = 540
    /// Onboarding hero illustration icon size
    static let onboardingIllustrationSize: CGFloat = 72
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

// MARK: - Elevation

/// Applies a soft shadow in light mode and a flat border in dark mode.
///
/// Use `.softElevation()` instead of a raw `.shadow()` to ensure the effect
/// adapts correctly between colour schemes without any additional boilerplate.
struct SoftElevation: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: AppLayout.radiusCard)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                )
        } else {
            content
                .shadow(color: Color(red: 0.18, green: 0.22, blue: 0.20).opacity(0.10),
                        radius: 8, x: 0, y: 3)
        }
    }
}

extension View {
    /// Applies `SoftElevation` — soft shadow in light mode, thin border in dark mode.
    func softElevation() -> some View {
        modifier(SoftElevation())
    }
}
