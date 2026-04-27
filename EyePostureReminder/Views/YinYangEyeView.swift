import SwiftUI

struct YinYangEyeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hasSettled = false
    @State private var hasStarted = false

    private let entranceDuration: Double = 1.35
    private let diameter = AppLayout.overlayIconSize * 1.55
    private let restingOrbitRadius = AppSpacing.lg
    private let entranceOrbitRadius = AppSpacing.xxl * 1.45
    private let startRotation = -145.0
    private let settledRotation = 360.0

    private var orbitRadius: CGFloat {
        hasSettled ? restingOrbitRadius : entranceOrbitRadius
    }

    private var rotationDegrees: Double {
        hasSettled ? settledRotation : startRotation
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColor.surfaceTint)
                .frame(width: diameter, height: diameter)
                .overlay {
                    Circle()
                        .strokeBorder(AppColor.separatorSoft.opacity(0.65), lineWidth: 1)
                }
                .softElevation()

            Circle()
                .fill(AppColor.primaryRest.opacity(0.12))
                .frame(width: diameter * 0.48, height: diameter * 0.48)
                .offset(y: -restingOrbitRadius)

            Circle()
                .fill(AppColor.secondaryCalm.opacity(0.13))
                .frame(width: diameter * 0.48, height: diameter * 0.48)
                .offset(y: restingOrbitRadius)

            orbitingEye(
                symbol: "eye.fill",
                color: AppColor.primaryRest,
                offsetY: -orbitRadius,
                accessibilityIdentifier: "home.statusIcon"
            )

            orbitingEye(
                symbol: "eye.slash.fill",
                color: AppColor.secondaryCalm,
                offsetY: orbitRadius,
                accessibilityIdentifier: "home.closedStatusIcon"
            )
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(hasSettled ? 1 : 0.92)
        .opacity(hasSettled ? 1 : 0.72)
        .onAppear(perform: startEntranceIfNeeded)
    }

    private func orbitingEye(
        symbol: String,
        color: Color,
        offsetY: CGFloat,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        Image(systemName: symbol)
            .symbolRenderingMode(.hierarchical)
            .font(AppTypography.homeLogoIcon)
            .foregroundStyle(color)
            .offset(y: offsetY)
            .rotationEffect(.degrees(-rotationDegrees))
            .accessibilityHidden(true)
            .accessibilityIdentifier(accessibilityIdentifier ?? symbol)
            .rotationEffect(.degrees(rotationDegrees))
    }

    private func startEntranceIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        if reduceMotion {
            hasSettled = true
            return
        }

        withAnimation(.easeInOut(duration: entranceDuration)) {
            hasSettled = true
        }
    }
}

#Preview {
    YinYangEyeView()
        .padding()
        .background(AppColor.background)
}
