import SwiftUI
import UIKit

/// Full-screen overlay displayed when an eye-break or posture reminder fires.
///
/// The view presents a calming gradient background, a countdown ring, and
/// dismiss controls (button, swipe-up, or settings link). It is shown inside
/// a dedicated `UIWindow` managed by ``OverlayManager`` and communicates
/// dismissal exclusively through closure callbacks — it never writes to
/// persistence directly.
struct OverlayView: View {

    let type: ReminderType
    let duration: TimeInterval
    let hapticsEnabled: Bool
    let onDismiss: () -> Void
    let onSettingsTap: () -> Void
    let onAnalyticsEvent: (AnalyticsEvent) -> Void

    @State private var secondsRemaining: Int
    @State private var timer: Timer?
    @State private var contentOpacity: Double = 0
    @State private var slideOffset: CGFloat = 300
    @State private var isDismissing = false

    // Generators created in onAppear and pre-prepared for low-latency haptics.
    @State private var impactGenerator: UIImpactFeedbackGenerator?
    @State private var notificationGenerator: UINotificationFeedbackGenerator?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        type: ReminderType,
        duration: TimeInterval,
        hapticsEnabled: Bool = true,
        onAnalyticsEvent: @escaping (AnalyticsEvent) -> Void = { _ in },
        onSettingsTap: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void
    ) {
        self.type              = type
        self.duration          = duration
        self.hapticsEnabled    = hapticsEnabled
        self.onAnalyticsEvent  = onAnalyticsEvent
        self.onSettingsTap     = onSettingsTap
        self.onDismiss         = onDismiss
        _secondsRemaining      = State(initialValue: Int(duration))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            backgroundGradient
            dismissButton
            centerContent
        }
        .opacity(contentOpacity)
        .offset(y: slideOffset)
        .gesture(swipeUpDismissGesture)
        .onAppear(perform: handleAppear)
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Body Sections

    /// Adaptive top-to-bottom gradient filling the entire screen behind overlay content.
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [AppColor.background, AppColor.surfaceTint],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// Secondary dismiss control (× icon) anchored to the top-trailing corner.
    private var dismissButton: some View {
        Button(
            action: { performDismiss(method: .button) },
            label: {
                Image(systemName: AppSymbol.dismiss)
                    .font(AppFont.overlayDismiss)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(minWidth: AppLayout.minTapTarget, minHeight: AppLayout.minTapTarget)
                    .contentShape(Rectangle())
            }
        )
        .padding(.top, AppSpacing.lg)
        .padding(.trailing, AppSpacing.lg)
        .accessibilityLabel(Text("overlay.dismissButton", bundle: .module))
        .accessibilityHint(Text("overlay.dismissButton.hint", bundle: .module))
        .accessibilityIdentifier("overlay.dismissButton")
    }

    /// Vertically-centered content stack containing the icon, headline, countdown, and action buttons.
    private var centerContent: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            iconAura
            headlineSection
            countdownRing
            Spacer()
            actionSection
            Spacer(minLength: AppSpacing.lg)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Soft circular glow ring behind the reminder-type SF Symbol icon.
    private var iconAura: some View {
        ZStack {
            Circle()
                .fill(type.color.opacity(AppOpacity.iconAura))
            Image(systemName: type.symbolName)
                .symbolRenderingMode(.hierarchical)
                .font(AppFont.overlayIcon)
                .foregroundStyle(type.color)
        }
        .frame(
            width: AppLayout.overlayIconSize * 1.75,
            height: AppLayout.overlayIconSize * 1.75
        )
        .accessibilityHidden(true)
    }

    /// Title and supportive-text labels for the active reminder type.
    private var headlineSection: some View {
        Group {
            Text(type.overlayTitle)
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Text(type.overlaySupportiveText)
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
                .accessibilityIdentifier("overlay.supportiveText")
        }
    }

    /// Animated circular countdown ring showing remaining seconds until auto-dismiss.
    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(AppColor.separatorSoft, lineWidth: AppLayout.countdownRingStroke)
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
                .foregroundStyle(AppColor.textPrimary)
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
            String.localizedStringWithFormat(
                NSLocalizedString("overlay.countdown.value", bundle: .module, comment: ""),
                secondsRemaining
            )
        )
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Primary "Done" button and secondary "Settings" link at the bottom of the overlay.
    private var actionSection: some View {
        Group {
            Button(
                action: { performDismiss(method: .button) },
                label: { Text("overlay.doneButton", bundle: .module) }
            )
            .buttonStyle(.primary)
            .frame(minHeight: AppLayout.minTapTarget)
            .accessibilityIdentifier("overlay.doneButton")

            Button(
                action: { performDismiss(method: .settingsTap) },
                label: {
                    Label(
                        title: { Text("overlay.settingsLabel", bundle: .module) },
                        icon: { Image(systemName: AppSymbol.settings) }
                    )
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
                }
            )
            .frame(minHeight: AppLayout.minTapTarget)
            .accessibilityLabel(Text("overlay.settingsButton", bundle: .module))
            .accessibilityHint(Text("overlay.settingsButton.hint", bundle: .module))
            .accessibilityIdentifier("overlay.settingsLink")
        }
    }

    /// Swipe-up drag gesture that dismisses the overlay, mirroring the upward slide entrance.
    private var swipeUpDismissGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if value.translation.height < 0 { performDismiss(method: .swipe) }
            }
    }

    /// Prepares haptic generators, fires entrance animation, and starts the countdown timer.
    private func handleAppear() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impactGenerator = impact
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notificationGenerator = notification

        if hapticsEnabled { notification.notificationOccurred(.warning) }

        withMotionSafe(reduceMotion, animation: AppAnimation.calmingEntranceCurve) {
            contentOpacity = 1
            slideOffset = 0
        }
        startTimer()
    }

    // MARK: - Manual dismiss (× button, swipe up, or Settings tap)

    /// Animates the overlay out and invokes `onDismiss` after the exit transition completes.
    private func performDismiss(method: AnalyticsEvent.DismissMethod = .button) {
        guard !isDismissing else { return }
        isDismissing = true
        timer?.invalidate()
        let elapsedS = duration - TimeInterval(secondsRemaining)
        onAnalyticsEvent(.overlayDismissed(type: type, method: method, elapsedS: elapsedS))
        if method == .settingsTap {
            onSettingsTap()
        }
        if hapticsEnabled { notificationGenerator?.notificationOccurred(.success) }
        let screenHeight = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.height ?? 1000
        withMotionSafe(reduceMotion, animation: AppAnimation.overlayDismissCurve) {
            contentOpacity = 0
            slideOffset = -screenHeight
        }
        let delay = reduceMotion ? 0.05 : AppAnimation.overlayDismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            onDismiss()
        }
    }

    // MARK: - Auto-dismiss (countdown reaches zero)

    /// Fades out the overlay when the countdown expires and invokes `onDismiss`.
    private func performAutoDismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        onAnalyticsEvent(.overlayAutoDismissed(type: type, durationS: duration))
        triggerCompletionHaptic()
        withMotionSafe(reduceMotion, animation: AppAnimation.overlayFadeCurve) {
            contentOpacity = 0
        }
        let delay = reduceMotion ? 0.05 : AppAnimation.overlayAutoDismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            onDismiss()
        }
    }

    // MARK: - Timer

    /// Starts a one-second repeating timer that decrements `secondsRemaining` and triggers auto-dismiss at zero.
    private func startTimer() {
        guard timer == nil else { return }
        let newTimer = Timer(timeInterval: 1, repeats: true) { _ in
            if secondsRemaining > 1 {
                secondsRemaining -= 1
            } else {
                secondsRemaining = 0
                timer?.invalidate()
                performAutoDismiss()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    // MARK: - Haptic Feedback

    /// Fires an impact haptic when the break completes, if haptics are enabled.
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
