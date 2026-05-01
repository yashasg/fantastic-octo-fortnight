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

    static let swipeDismissMinimumUpwardTravel: CGFloat = 30

    let type: ReminderType
    let duration: TimeInterval
    let hapticsEnabled: Bool
    let onDismiss: () -> Void
    let onSettingsTap: () -> Void
    let onAnalyticsEvent: (AnalyticsEvent) -> Void
    private let reduceMotionOverride: Bool?

    @State private var secondsRemaining: Int
    @State private var timer: Timer?
    @State private var contentOpacity: Double = 0
    @State private var slideOffset: CGFloat = AppLayout.overlayEntranceOffset
    @State private var isDismissing = false

    // Generators created in onAppear and pre-prepared for low-latency haptics.
    @State private var impactGenerator: UIImpactFeedbackGenerator?
    @State private var notificationGenerator: UINotificationFeedbackGenerator?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        type: ReminderType,
        duration: TimeInterval,
        hapticsEnabled: Bool = true,
        reduceMotionOverride: Bool? = nil,
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
        self.reduceMotionOverride = reduceMotionOverride
        _secondsRemaining      = State(initialValue: Int(duration))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            backgroundGradient
            dismissButton
            centerContent
        }
        .accessibilityElement(children: .contain)
        // Modal suppression is handled at the UIKit layer: OverlayManager sets
        // hostingController.view.accessibilityViewIsModal = true on the hosting
        // controller's view, which correctly prevents VoiceOver from escaping
        // the overlay window. SwiftUI's accessibilityViewIsModal(_:) is not
        // available in the current SDK; .accessibilityAddTraits(.isModal) only
        // adds a trait without suppressing traversal, so it is omitted here.
        .accessibilityAction(AccessibilityActionKind.escape) {
            performDismiss(method: .button)
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
                    .accessibilityHidden(true)
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
                .accessibilitySortPriority(1)

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
                    shouldReduceMotion ? .none : AppAnimation.countdownRingCurve,
                    value: secondsRemaining
                )
                .accessibilityHidden(true)

            Text("\(secondsRemaining)")
                .font(AppFont.countdown)
                .foregroundStyle(AppColor.textPrimary)
                .monospacedDigit()
                .contentTransition(
                    shouldReduceMotion ? .identity : .numericText(countsDown: true)
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
            .accessibilityHint(Text("overlay.doneButton.hint", bundle: .module))
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
        DragGesture(minimumDistance: Self.swipeDismissMinimumUpwardTravel)
            .onEnded { value in
                if Self.shouldDismissForSwipe(translation: value.translation) {
                    performDismiss(method: .swipe)
                }
            }
    }

    static func shouldDismissForSwipe(translation: CGSize) -> Bool {
        let upwardTravel = -translation.height
        guard upwardTravel >= swipeDismissMinimumUpwardTravel else { return false }
        return upwardTravel > abs(translation.width)
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

        withMotionSafe(shouldReduceMotion, animation: AppAnimation.calmingEntranceCurve) {
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
        withMotionSafe(shouldReduceMotion, animation: AppAnimation.overlayDismissCurve) {
            contentOpacity = 0
            slideOffset = -screenHeight
        }
        let delay = shouldReduceMotion ? 0.05 : AppAnimation.overlayDismiss
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
        withMotionSafe(shouldReduceMotion, animation: AppAnimation.overlayFadeCurve) {
            contentOpacity = 0
        }
        let delay = shouldReduceMotion ? 0.05 : AppAnimation.overlayAutoDismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            onDismiss()
        }
    }

    // MARK: - Timer

    private var shouldReduceMotion: Bool {
        reduceMotionOverride ?? reduceMotion
    }

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
        newTimer.tolerance = 0.5
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
