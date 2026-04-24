import SwiftUI
import UIKit

struct OverlayView: View {

    let type: ReminderType
    let duration: TimeInterval
    let onDismiss: () -> Void

    @State private var secondsRemaining: Int
    @State private var timer: Timer?
    @State private var contentOpacity: Double = 0
    @State private var isDismissing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(type: ReminderType, duration: TimeInterval, onDismiss: @escaping () -> Void) {
        self.type      = type
        self.duration  = duration
        self.onDismiss = onDismiss
        _secondsRemaining = State(initialValue: Int(duration))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // MARK: Blur background
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            // MARK: × Dismiss — fixed top-right corner
            Button(action: performDismiss) {
                Image(systemName: AppSymbol.dismiss)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: AppLayout.minTapTarget, minHeight: AppLayout.minTapTarget)
                    .contentShape(Rectangle())
            }
            .padding(.top, AppSpacing.lg)
            .padding(.trailing, AppSpacing.lg)
            .accessibilityLabel("Dismiss reminder")

            // MARK: Center content
            VStack(spacing: AppSpacing.lg) {
                Spacer()

                // Icon — decorative; headline conveys the meaning for VoiceOver
                Image(systemName: type.symbolName)
                    .font(.system(size: AppLayout.overlayIconSize))
                    .foregroundStyle(type.color)
                    .accessibilityHidden(true)

                // Headline
                Text(type.overlayTitle)
                    .font(AppFont.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)

                // Circular countdown ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: AppLayout.countdownRingStroke)
                        .accessibilityHidden(true)

                    Circle()
                        .trim(from: 0, to: CGFloat(secondsRemaining) / CGFloat(max(duration, 1)))
                        .stroke(
                            type.color,
                            style: StrokeStyle(lineWidth: AppLayout.countdownRingStroke, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(
                            reduceMotion ? .none : AppAnimation.countdownRingCurve,
                            value: secondsRemaining
                        )
                        .accessibilityHidden(true)

                    Text("\(secondsRemaining)")
                        .font(AppFont.countdown)
                        .monospacedDigit()
                        .contentTransition(
                            reduceMotion ? .identity : .numericText(countsDown: true)
                        )
                }
                .frame(
                    width: AppLayout.countdownRingDiameter,
                    height: AppLayout.countdownRingDiameter
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(secondsRemaining) seconds remaining")

                Spacer()

                // Settings gear — dismisses overlay, revealing SettingsView underneath
                Button(action: performDismiss) {
                    Label("Settings", systemImage: AppSymbol.settings)
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: AppLayout.minTapTarget)
                .accessibilityLabel("Open Settings")
                .accessibilityHint("Dismisses this reminder and reveals Settings")
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(contentOpacity)
        .accessibilityViewIsModal(true)
        // Swipe UP to dismiss (negative Y translation = upward drag)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height < 0 { performDismiss() }
                }
        )
        .onAppear {
            if reduceMotion {
                contentOpacity = 1
            } else {
                withAnimation(AppAnimation.overlayAppearCurve) {
                    contentOpacity = 1
                }
            }
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: - Manual dismiss (× button, swipe up, or Settings tap)

    private func performDismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        timer?.invalidate()
        if reduceMotion {
            contentOpacity = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { onDismiss() }
        } else {
            withAnimation(AppAnimation.overlayDismissCurve) {
                contentOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + AppAnimation.overlayDismiss) {
                onDismiss()
            }
        }
    }

    // MARK: - Auto-dismiss (countdown reaches zero)

    private func performAutoDismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        triggerCompletionHaptic()
        if reduceMotion {
            contentOpacity = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { onDismiss() }
        } else {
            withAnimation(AppAnimation.overlayFadeCurve) {
                contentOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + AppAnimation.overlayAutoDismiss) {
                onDismiss()
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                timer?.invalidate()
                performAutoDismiss()
            }
        }
    }

    // MARK: - Haptic Feedback

    private func triggerCompletionHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
}

#Preview {
    OverlayView(type: .eyes, duration: 20, onDismiss: {})
}

#Preview("Posture") {
    OverlayView(type: .posture, duration: 10, onDismiss: {})
}
