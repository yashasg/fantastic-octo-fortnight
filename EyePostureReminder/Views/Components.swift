// Components.swift
// kshana
//
// Reusable SwiftUI view modifiers and views for the Restful Grove design system.
// All components consume AppColor, AppLayout, and AppTypography tokens.

import SwiftUI

// MARK: - WellnessCard

/// Wraps content in a surface-coloured rounded card with a subtle separator border.
/// Pass `elevated: true` to also apply the `SoftElevation` modifier.
struct WellnessCard: ViewModifier {
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.radiusCard, style: .continuous)
                    .strokeBorder(AppColor.separatorSoft, lineWidth: 1)
            )
            .applyIf(elevated) { $0.softElevation(cornerRadius: AppLayout.radiusCard) }
    }
}

extension View {
    /// Applies the `WellnessCard` modifier — surface background, rounded corners, soft border.
    /// - Parameter elevated: Also applies `SoftElevation` when `true`. Default is `false`.
    func wellnessCard(elevated: Bool = false) -> some View {
        modifier(WellnessCard(elevated: elevated))
    }
}

// MARK: - PrimaryButton

/// A pill-shaped button style with a `primaryRest` fill and adaptive high-contrast foreground.
/// Applies a subtle 0.98 scale animation on press (guarded by `accessibilityReduceMotion`).
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration)
    }

    private struct PrimaryButtonBody: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let configuration: ButtonStyleConfiguration

        var body: some View {
            configuration.label
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(AppColor.background)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm + 4)
                .background(AppColor.primaryRest)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.radiusPill, style: .continuous))
                .scaleEffect((!reduceMotion && configuration.isPressed) ? 0.98 : 1.0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    /// Pill-shaped primary button: `primaryRest` fill, adaptive high-contrast text, subtle press scale.
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

// MARK: - IconContainer

/// A circular container with a `surfaceTint` background, used for settings section icons.
struct IconContainer: View {
    let icon: String
    var color: Color = AppColor.primaryRest
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: icon)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(AppColor.surfaceTint)
            .clipShape(Circle())
    }
}

// MARK: - CalmingEntrance

/// Animates a view into position with a soft fade + gentle upward slide on first appear.
///
/// When `accessibilityReduceMotion` is enabled, the view appears immediately with no
/// motion — opacity snaps to 1 without any slide offset.
///
/// Usage: `.calmingEntrance()` or `.calmingEntrance(delay: 0.1)` for staggered reveals.
struct CalmingEntrance: ViewModifier {
    @State private var appeared = false
    @State private var hasEverAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: (!reduceMotion && !appeared) ? AppLayout.entranceSlideOffset : 0)
            .onAppear {
                guard !hasEverAppeared else { appeared = true; return }
                hasEverAppeared = true
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(AppAnimation.calmingEntranceCurve.delay(delay)) {
                        appeared = true
                    }
                }
            }
    }
}

extension View {
    /// Applies a calming fade + gentle upward slide entrance animation on first appear.
    /// No animation is applied when `accessibilityReduceMotion` is enabled.
    /// - Parameter delay: Optional delay before the animation begins. Default is `0`.
    func calmingEntrance(delay: Double = 0) -> some View {
        modifier(CalmingEntrance(delay: delay))
    }
}

// MARK: - Reduce-Motion Animation Helper

extension View {
    /// Performs an action optionally wrapped in an animation, respecting reduce-motion.
    /// Use instead of repeating `if reduceMotion { action() } else { withAnimation { action() } }`.
    @MainActor
    func withMotionSafe(_ reduceMotion: Bool, animation: Animation, action: @escaping () -> Void) {
        if reduceMotion {
            action()
        } else {
            withAnimation(animation) { action() }
        }
    }
}

// MARK: - SecondaryButton

/// A low-prominence button style used for secondary actions (e.g., onboarding skip/customize).
/// Applies a subtle opacity change on press.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.secondaryAction)
            .foregroundStyle(AppColor.textSecondary)
            .frame(minHeight: AppLayout.minTapTarget)
            .padding(.horizontal, AppSpacing.md)
            .opacity(configuration.isPressed ? AppOpacity.pressedButton : 1)
    }
}

/// Legacy alias — prefer `.buttonStyle(.secondary)`.
typealias OnboardingSecondaryButtonStyle = SecondaryButtonStyle

extension ButtonStyle where Self == SecondaryButtonStyle {
    /// Low-prominence secondary button: muted text, subtle press opacity.
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

// MARK: - Internal helpers

private extension View {
    /// Conditionally applies a transform. Used to optionally apply SoftElevation.
    @ViewBuilder
    func applyIf<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
