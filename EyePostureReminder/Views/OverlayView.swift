import SwiftUI
import UIKit

struct OverlayView: View {

    let type: ReminderType
    let duration: TimeInterval
    let hapticsEnabled: Bool
    let onDismiss: () -> Void

    @State private var secondsRemaining: Int
    @State private var timer: Timer?
    @State private var contentOpacity: Double = 0
    @State private var isDismissing = false

    // Generators created in onAppear and pre-prepared for low-latency haptics.
    @State private var impactGenerator: UIImpactFeedbackGenerator?
    @State private var notificationGenerator: UINotificationFeedbackGenerator?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(type: ReminderType, duration: TimeInterval, hapticsEnabled: Bool = true, onDismiss: @escaping () -> Void) {
        self.type            = type
        self.duration        = duration
        self.hapticsEnabled  = hapticsEnabled
        self.onDismiss       = onDismiss
        _secondsRemaining    = State(initialValue: Int(duration))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // MARK: Blur background
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            // MARK: × Dismiss — fixed top-right corner
            Button(
                action: { performDismiss(method: .button) },
                label: {
                    Image(systemName: AppSymbol.dismiss)
                        .font(.system(.title).weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: AppLayout.minTapTarget, minHeight: AppLayout.minTapTarget)
                        .contentShape(Rectangle())
                }
            )
            .padding(.top, AppSpacing.lg)
            .padding(.trailing, AppSpacing.lg)
            .accessibilityLabel(Text("overlay.dismissButton", bundle: .module))
            .accessibilityHint(Text("overlay.dismissButton.hint", bundle: .module))

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
                .accessibilityLabel(Text("overlay.countdown.label", bundle: .module))
                .accessibilityValue(
                    String(
                        format: String(localized: "overlay.countdown.value", bundle: .module),
                        secondsRemaining
                    )
                )
                .accessibilityAddTraits(.updatesFrequently)

                Spacer()

                // Settings gear — dismisses overlay, revealing SettingsView underneath
                Button(
                    action: { performDismiss(method: .settingsTap) },
                    label: {
                        Label(
                            title: { Text("overlay.settingsLabel", bundle: .module) },
                            icon: { Image(systemName: AppSymbol.settings) }
                        )
                            .font(AppFont.body)
                            .foregroundStyle(.secondary)
                    }
                )
                .frame(minHeight: AppLayout.minTapTarget)
                .accessibilityLabel(Text("overlay.settingsButton", bundle: .module))
                .accessibilityHint(Text("overlay.settingsButton.hint", bundle: .module))
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(contentOpacity)
        // Swipe UP to dismiss (negative Y translation = upward drag)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height < 0 { performDismiss(method: .swipe) }
                }
        )
        .onAppear {
            // Prepare haptic generators up front so they are ready when needed.
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.prepare()
            impactGenerator = impact
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notificationGenerator = notification

            if hapticsEnabled { notification.notificationOccurred(.warning) }

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

    private func performDismiss(method: AnalyticsEvent.DismissMethod = .button) {
        guard !isDismissing else { return }
        isDismissing = true
        timer?.invalidate()
        let elapsedS = duration - TimeInterval(secondsRemaining)
        AnalyticsLogger.log(.overlayDismissed(type: type, method: method, elapsedS: elapsedS))
        if hapticsEnabled { notificationGenerator?.notificationOccurred(.success) }
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
        AnalyticsLogger.log(.overlayAutoDismissed(type: type, durationS: duration))
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
        let newTimer = Timer(timeInterval: 1, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                timer?.invalidate()
                performAutoDismiss()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    // MARK: - Haptic Feedback

    private func triggerCompletionHaptic() {
        guard hapticsEnabled else { return }
        impactGenerator?.impactOccurred()
    }
}

#Preview {
    OverlayView(type: .eyes, duration: 20) {}
}

#Preview("Posture") {
    OverlayView(type: .posture, duration: 10) {}
}
