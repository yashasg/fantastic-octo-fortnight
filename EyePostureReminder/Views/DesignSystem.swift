// DesignSystem.swift
// Eye & Posture Reminder
//
// Design tokens — single source of truth for all visual decisions.
// Every color, font, spacing, and animation in the app references this file.

import SwiftUI
import UIKit

// MARK: - Semantic Color Literals

enum AppColor {
    /// Eye breaks (#4A90D9) — calming blue
    static let reminderBlue     = Color(red: 0.290, green: 0.565, blue: 0.851)
    /// Posture checks (#34C759) — grounded green
    static let reminderGreen    = Color(red: 0.204, green: 0.780, blue: 0.349)
    /// Overlay tint
    static let overlayBackground = Color(.systemBackground).opacity(0.6)
    /// Rest-of-day snooze warning (#FF9500)
    static let warningOrange    = Color(red: 1.0, green: 0.584, blue: 0.0)
    /// Permission banner (#FFCC00)
    static let permissionBanner = Color(red: 1.0, green: 0.800, blue: 0.0)
    /// Permission banner text — near-black for WCAG AA contrast on yellow
    static let permissionBannerText = Color(red: 0.149, green: 0.149, blue: 0.149)
    /// Warning text colour for body/label contexts — WCAG AA on both backgrounds.
    /// Light mode: dark amber #994F00 (6.1:1 on white). Dark mode: #FF9500 (6.8:1 on near-black).
    static let warningText = Color(UIColor(dynamicProvider: { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0,   green: 0.584, blue: 0.0, alpha: 1)
            : UIColor(red: 0.600, green: 0.310, blue: 0.0, alpha: 1)
    }))
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
    /// Countdown ring — continuous, driven by a 1-second timer tick
    static let countdownRingTick: Double = 1.0
    /// Snooze sheet slide-up — 0.25s ease-out
    static let snoozeSheetAppear: Double = 0.25
    /// Snooze sheet auto-dismiss timeout — 5 seconds of no interaction
    static let snoozeAutoDismiss: Double = 5.0

    // Convenience SwiftUI Animation values
    static let overlayAppearCurve: Animation  = .easeOut(duration: overlayAppear)
    static let overlayDismissCurve: Animation = .easeIn(duration: overlayDismiss)
    static let overlayFadeCurve: Animation    = .linear(duration: overlayAutoDismiss)
    static let settingsExpandCurve: Animation = .easeInOut(duration: settingsExpand)
    static let countdownRingCurve: Animation  = .linear(duration: countdownRingTick)
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
    /// Snooze button height (full-width, comfortable)
    static let snoozeButtonHeight: CGFloat = 50
    /// Bottom sheet corner radius
    static let sheetCornerRadius: CGFloat = 20
    /// Overlay corner radius (for non-fullscreen contexts)
    static let overlayCornerRadius: CGFloat = 24
}
