// Components.swift
// Eye & Posture Reminder
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
            .applyIf(elevated) { $0.softElevation() }
    }
}

extension View {
    /// Applies the `WellnessCard` modifier — surface background, rounded corners, soft border.
    /// - Parameter elevated: Also applies `SoftElevation` when `true`. Default is `false`.
    func wellnessCard(elevated: Bool = false) -> some View {
        modifier(WellnessCard(elevated: elevated))
    }
}

// MARK: - StatusPill

/// A small pill-shaped label combining an SF Symbol icon and a text label.
/// Background is `AppColor.surfaceTint`; text/icon are `AppColor.primaryRest`.
struct StatusPill: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(AppTypography.caption)
            Text(label)
                .font(AppTypography.caption)
        }
        .foregroundStyle(AppColor.primaryRest)
        .padding(.horizontal, AppSpacing.sm + 2)
        .padding(.vertical, AppSpacing.xs + 1)
        .background(AppColor.surfaceTint)
        .clipShape(Capsule())
    }
}

// MARK: - PrimaryButton

/// A pill-shaped button style with a `primaryRest` fill and white foreground.
/// Applies a subtle 0.98 scale animation on press.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyEmphasized)
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm + 4)
            .background(AppColor.primaryRest)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.radiusPill, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    /// Pill-shaped primary button: `primaryRest` fill, white text, subtle press scale.
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
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(AppColor.surfaceTint)
            .clipShape(Circle())
    }
}

// MARK: - SectionHeader

/// A styled section header row using `textSecondary` colour and Nunito caption font.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(AppTypography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(AppColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
    }
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
