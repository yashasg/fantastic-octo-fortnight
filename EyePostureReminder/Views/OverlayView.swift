import SwiftUI

struct OverlayView: View {

    let type: ReminderType
    let duration: TimeInterval
    let onDismiss: () -> Void

    @State private var secondsRemaining: Int
    @State private var timer: Timer?

    init(type: ReminderType, duration: TimeInterval, onDismiss: @escaping () -> Void) {
        self.type      = type
        self.duration  = duration
        self.onDismiss = onDismiss
        _secondsRemaining = State(initialValue: Int(duration))
    }

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: type.symbolName)
                    .font(.system(size: AppLayout.overlayIconSize))
                    .foregroundStyle(type.color)

                Text(type.overlayTitle)
                    .font(AppFont.headline)
                    .multilineTextAlignment(.center)

                // Circular countdown ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: AppLayout.countdownRingStroke)

                    Circle()
                        .trim(from: 0, to: CGFloat(secondsRemaining) / CGFloat(max(duration, 1)))
                        .stroke(type.color, style: StrokeStyle(lineWidth: AppLayout.countdownRingStroke, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(AppAnimation.countdownRingCurve, value: secondsRemaining)

                    Text("\(secondsRemaining)")
                        .font(AppFont.countdown)
                        .monospacedDigit()
                }
                .frame(
                    width: AppLayout.countdownRingDiameter,
                    height: AppLayout.countdownRingDiameter
                )

                Button(action: onDismiss) {
                    Label("Dismiss", systemImage: AppSymbol.dismiss)
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: AppLayout.minTapTarget)
                .accessibilityLabel("Dismiss reminder")
            }
            .padding(AppSpacing.xl)
        }
        .accessibilityAddTraits(.isModal)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height > 0 { onDismiss() }
                }
        )
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                timer?.invalidate()
                onDismiss()
            }
        }
    }
}

#Preview {
    OverlayView(type: .eyes, duration: 20, onDismiss: {})
}
