import SwiftUI

struct YinYangEyeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var spinComplete = false
    @State private var breathing = false
    @State private var hasStarted = false

    private let diameter = AppLayout.overlayIconSize * 1.55

    var body: some View {
        let half = diameter / 2
        let dotSize = diameter * 0.13

        ZStack {
            // Base circle — yin color (sage)
            Circle()
                .fill(AppColor.primaryRest)

            // Right half — yang color (mint), clipped to right semicircle
            Circle()
                .fill(AppColor.surfaceTint)
                .clipShape(RightHalf())

            // Top small circle — sage (yin bulges into yang territory)
            Circle()
                .fill(AppColor.primaryRest)
                .frame(width: half, height: half)
                .offset(y: -half / 2)

            // Bottom small circle — mint (yang bulges into yin territory)
            Circle()
                .fill(AppColor.surfaceTint)
                .frame(width: half, height: half)
                .offset(y: half / 2)

            // Yin dot (mint inside yin, upper area)
            Circle()
                .fill(AppColor.surfaceTint)
                .frame(width: dotSize, height: dotSize)
                .offset(y: -half / 2)

            // Yang dot (sage inside yang, lower area)
            Circle()
                .fill(AppColor.primaryRest)
                .frame(width: dotSize, height: dotSize)
                .offset(y: half / 2)

            // Border ring
            Circle()
                .strokeBorder(AppColor.separatorSoft.opacity(AppOpacity.subtleBorder), lineWidth: 1.5)
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(spinComplete ? 360 : 0))
        .scaleEffect(breathing ? 1.06 : 1.0)
        .accessibilityIdentifier("home.statusIcon")
        .accessibilityHidden(true)
        .onAppear(perform: startAnimations)
    }

    private func startAnimations() {
        guard !hasStarted else { return }
        hasStarted = true

        guard !reduceMotion else { return }

        withAnimation(AppAnimation.yinYangSpinCurve) {
            spinComplete = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(
                .easeInOut(duration: 4)
                .repeatForever(autoreverses: true)
            ) {
                breathing = true
            }
        }
    }
}

// MARK: - Right Half Clip Shape

/// Clips to the right half of the bounding rect.
struct RightHalf: Shape {
    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height))
    }
}

#Preview {
    YinYangEyeView()
        .padding()
        .background(AppColor.background)
}
