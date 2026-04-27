import SwiftUI

struct YinYangEyeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var spinComplete = false
    @State private var breathing = false
    @State private var hasStarted = false

    private let diameter = AppLayout.overlayIconSize * 1.55

    var body: some View {
        let dotSize = diameter * 0.18

        ZStack {
            // Yin half (left teardrop) — sage green
            YinYangHalfShape(isYin: true)
                .fill(AppColor.primaryRest)
                .frame(width: diameter, height: diameter)

            // Yang half (right teardrop) — mint
            YinYangHalfShape(isYin: false)
                .fill(AppColor.surfaceTint)
                .frame(width: diameter, height: diameter)

            // Yin dot (yang color inside yin half, at 25% from top)
            Circle()
                .fill(AppColor.surfaceTint)
                .frame(width: dotSize, height: dotSize)
                .offset(y: -diameter * 0.25)

            // Yang dot (yin color inside yang half, at 75% from top)
            Circle()
                .fill(AppColor.primaryRest)
                .frame(width: dotSize, height: dotSize)
                .offset(y: diameter * 0.25)

            // Border ring
            Circle()
                .strokeBorder(AppColor.separatorSoft.opacity(0.65), lineWidth: 1)
                .frame(width: diameter, height: diameter)
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

        // Phase 1: Spin 360° over 2 seconds with deceleration
        withAnimation(.timingCurve(0.2, 0.0, 0.0, 1.0, duration: 2)) {
            spinComplete = true
        }

        // Phase 2: Breathe after spin completes
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

// MARK: - Yin-Yang Half Shape

/// Draws one half of a yin-yang symbol using SwiftUI Path.
/// `isYin` = true draws the left (yin) half, false draws the right (yang) half.
private struct YinYangHalfShape: Shape {
    let isYin: Bool

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cx = w / 2
        let cy = h / 2
        let r = min(w, h) / 2
        let smallR = r / 2

        var path = Path()

        if isYin {
            // Start at top center
            path.move(to: CGPoint(x: cx, y: 0))
            // Large arc: top-center to bottom-center going LEFT (counter-clockwise)
            path.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: r,
                startAngle: .degrees(-90),
                endAngle: .degrees(90),
                clockwise: true
            )
            // Small arc: bottom-center back to center going RIGHT (S-curve bottom)
            path.addArc(
                center: CGPoint(x: cx, y: cy + smallR),
                radius: smallR,
                startAngle: .degrees(90),
                endAngle: .degrees(-90),
                clockwise: true
            )
            // Small arc: center to top-center going LEFT (S-curve top)
            path.addArc(
                center: CGPoint(x: cx, y: cy - smallR),
                radius: smallR,
                startAngle: .degrees(90),
                endAngle: .degrees(-90),
                clockwise: false
            )
        } else {
            // Start at top center
            path.move(to: CGPoint(x: cx, y: 0))
            // Large arc: top-center to bottom-center going RIGHT (clockwise)
            path.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: r,
                startAngle: .degrees(-90),
                endAngle: .degrees(90),
                clockwise: false
            )
            // Small arc: bottom-center back to center going LEFT (S-curve bottom)
            path.addArc(
                center: CGPoint(x: cx, y: cy + smallR),
                radius: smallR,
                startAngle: .degrees(90),
                endAngle: .degrees(-90),
                clockwise: false
            )
            // Small arc: center to top-center going RIGHT (S-curve top)
            path.addArc(
                center: CGPoint(x: cx, y: cy - smallR),
                radius: smallR,
                startAngle: .degrees(90),
                endAngle: .degrees(-90),
                clockwise: true
            )
        }

        path.closeSubpath()
        return path
    }
}

#Preview {
    YinYangEyeView()
        .padding()
        .background(AppColor.background)
}
