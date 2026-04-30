import SwiftUI

struct YinYangEyeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var spinComplete = false
    @State private var breathing = false
    @State private var hasStarted = false
    @State private var isVisible = false

    private let reduceMotionOverride: Bool?
    private let diameter = AppLayout.overlayIconSize * 1.55

    init(reduceMotionOverride: Bool? = nil) {
        self.reduceMotionOverride = reduceMotionOverride
    }

    var body: some View {
        let half = diameter / 2
        let dotSize = diameter * 0.13

        ZStack {
            // Base circle — yin color (sage)
            Circle()
                .fill(AppColor.primaryRest)

            // Right half — yang color (mint), clipped to right semicircle
            Circle()
                .fill(AppColor.logoYangMint)
                .clipShape(RightHalf())

            // Top small circle — sage (yin bulges into yang territory)
            Circle()
                .fill(AppColor.primaryRest)
                .frame(width: half, height: half)
                .offset(y: -half / 2)

            // Bottom small circle — mint (yang bulges into yin territory)
            Circle()
                .fill(AppColor.logoYangMint)
                .frame(width: half, height: half)
                .offset(y: half / 2)

            // Yin dot (mint inside yin, upper area)
            Circle()
                .fill(AppColor.logoYangMint)
                .frame(width: dotSize, height: dotSize)
                .offset(y: -half / 2)

            // Yang dot (sage inside yang, lower area)
            Circle()
                .fill(AppColor.primaryRest)
                .frame(width: dotSize, height: dotSize)
                .offset(y: half / 2)

            // Border ring
            Circle()
                .strokeBorder(AppColor.separatorSoft.opacity(AppOpacity.subtleBorder), lineWidth: AppLayout.borderBold)
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(spinComplete ? 360 : 0))
        .scaleEffect(breathing ? 1.06 : 1.0)
        .accessibilityHidden(true)
        .onAppear {
            isVisible = true
            startAnimations()
        }
        .onDisappear {
            isVisible = false
            withAnimation(.easeInOut(duration: 0.3)) {
                breathing = false
            }
        }
        .onChange(of: shouldReduceMotion) { newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.3)) {
                    breathing = false
                }
            } else if isVisible {
                startAnimations()
            }
        }
    }

    private var shouldReduceMotion: Bool {
        reduceMotionOverride ?? reduceMotion
    }

    private func startAnimations() {
        guard !shouldReduceMotion else { return }

        if hasStarted {
            // Returning to view — restart breathing only
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard isVisible else { return }
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
            return
        }

        hasStarted = true

        withAnimation(AppAnimation.yinYangSpinCurve) {
            spinComplete = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard isVisible else { return }
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
