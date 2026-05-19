import ComposableArchitecture
import SwiftUI
import UIKit

/// Full-screen overlay displayed when an eye-break or posture reminder fires.
///
/// The view presents a calming gradient background, a countdown ring, and
/// dismiss controls (button, swipe-up, or settings link). All presentation
/// state — countdown, dismissal phase, analytics — flows through
/// `OverlayFeature` so the reducer owns the two-phase dismiss contract
/// (`#738`).
///
/// `#919` Phase 1 introduced the `init(store:)` initializer alongside a
/// legacy closure-driven body that was used by the now-retired
/// `OverlayManager` `UIWindow` + `UIHostingController` presentation.
/// `#920` Phase 2 retired the `OverlayManager` path entirely; the
/// canonical `StoreOf<OverlayFeature>`-driven body is now the only
/// path, rendered by
/// `RootView.fullScreenCover(item: $store.scope(state: \.$overlay, …))`.
struct OverlayView: View {

    // MARK: - Swipe-up gesture helpers (preserved for unit-test access)

    static let swipeDismissMinimumUpwardTravel: CGFloat = 30

    static func shouldDismissForSwipe(translation: CGSize) -> Bool {
        let upwardTravel = -translation.height
        guard upwardTravel >= swipeDismissMinimumUpwardTravel else { return false }
        return upwardTravel > abs(translation.width)
    }

    @Perception.Bindable var store: StoreOf<OverlayFeature>

    @State private var contentOpacity: Double = 0
    @State private var slideOffset: CGFloat = AppLayout.overlayEntranceOffset
    @State private var hasStartedExitAnimation = false

    // Generators created in onAppear and pre-prepared for low-latency haptics.
    @State private var impactGenerator: UIImpactFeedbackGenerator?
    @State private var notificationGenerator: UINotificationFeedbackGenerator?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: StoreOf<OverlayFeature>) {
        self.store = store
    }

    // MARK: - Backward-compat property accessors
    //
    // Existing view-body tests (`CoverageBoostTests`, `ViewBodyCoverageTests`,
    // `OverlayAccessibilityTests`, `PreviewTests`) read `view.type`,
    // `view.duration`, and `view.hapticsEnabled` directly on the wrapper.
    // Preserve those property surfaces so the migration of those tests to
    // `init(store:)` doesn't have to rewrite every assertion in lockstep.

    var type: ReminderType { store.type }
    var duration: TimeInterval { store.duration }
    var hapticsEnabled: Bool { store.hapticsEnabled }

    // MARK: - Body

    var body: some View {
        WithPerceptionTracking {
            ZStack(alignment: .topTrailing) {
                backgroundGradient
                dismissButton
                centerContent
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("overlay.root")
            // SwiftUI's `accessibilityViewIsModal(_:)` is not available in
            // the current SDK and `.isModal` trait alone does not suppress
            // VoiceOver traversal. The `.fullScreenCover` host already
            // isolates focus to the overlay's window, and `postScreenChanged`
            // (fired by `OverlayFeature.onAppear` / `.dismissed`) returns
            // VoiceOver focus to the underlying content on exit.
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(AccessibilityActionKind.escape) {
                handleDismissTapped()
            }
            .opacity(contentOpacity)
            .offset(y: slideOffset)
            .gesture(swipeUpDismissGesture)
            .onAppear(perform: handleAppear)
            .onChangeCompat(of: store.isDismissing) { isDismissing in
                if isDismissing { runExitAnimation() }
            }
        }
    }

    // MARK: - Body Sections

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [AppColor.background, AppColor.surfaceTint],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var dismissButton: some View {
        Button(
            action: { handleDismissTapped() },
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

    private var iconAura: some View {
        ZStack {
            Circle()
                .fill(store.type.color.opacity(AppOpacity.iconAura))
            Image(systemName: store.type.symbolName)
                .symbolRenderingMode(.hierarchical)
                .font(AppFont.overlayIcon)
                .foregroundStyle(store.type.color)
        }
        .frame(
            width: AppLayout.overlayIconSize * 1.75,
            height: AppLayout.overlayIconSize * 1.75
        )
        .accessibilityHidden(true)
    }

    private var headlineSection: some View {
        Group {
            Text(store.type.overlayTitle)
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
                .accessibilitySortPriority(1)

            Text(store.type.overlaySupportiveText)
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
                .accessibilityIdentifier("overlay.supportiveText")
        }
    }

    private var countdownRing: some View {
        ZStack {
            Circle()
                .stroke(AppColor.separatorSoft, lineWidth: AppLayout.countdownRingStroke)
                .accessibilityHidden(true)

            Circle()
                .trim(from: 0, to: CGFloat(store.secondsRemaining) / CGFloat(max(store.duration, 1)))
                .stroke(
                    store.type.color,
                    style: StrokeStyle(lineWidth: AppLayout.countdownRingStroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? .none : AppAnimation.countdownRingCurve,
                    value: store.secondsRemaining
                )
                .accessibilityHidden(true)

            Text("\(store.secondsRemaining)")
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
                store.secondsRemaining
            )
        )
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var actionSection: some View {
        Group {
            Button(
                action: { handleDismissTapped() },
                label: { Text("overlay.doneButton", bundle: .module) }
            )
            .buttonStyle(.primary)
            .frame(minHeight: AppLayout.minTapTarget)
            .accessibilityHint(Text("overlay.doneButton.hint", bundle: .module))
            .accessibilityIdentifier("overlay.doneButton")

            Button(
                action: { handleSettingsTapped() },
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

    private var swipeUpDismissGesture: some Gesture {
        DragGesture(minimumDistance: OverlayView.swipeDismissMinimumUpwardTravel)
            .onEnded { value in
                if OverlayView.shouldDismissForSwipe(translation: value.translation) {
                    handleDismissTapped()
                }
            }
    }

    // MARK: - Action handlers

    private func handleAppear() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impactGenerator = impact
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notificationGenerator = notification

        if store.hapticsEnabled { notification.notificationOccurred(.warning) }

        withMotionSafe(reduceMotion, animation: AppAnimation.calmingEntranceCurve) {
            contentOpacity = 1
            slideOffset = 0
        }
        store.send(.onAppear)
    }

    private func handleDismissTapped() {
        guard !store.isDismissing else { return }
        store.send(.dismissTapped)
    }

    private func handleSettingsTapped() {
        guard !store.isDismissing else { return }
        store.send(.settingsTapped)
        store.send(.dismissTapped)
    }

    /// Runs the exit transition (slide-up + fade for manual dismiss, fade-only
    /// for auto-dismiss when the countdown hit zero) and then dispatches
    /// `.dismissAnimationCompleted` so the reducer can fire its tear-down
    /// effect chain (`resumeExternalAudio` + `broadcast(.dismissed)` +
    /// `postScreenChanged` via `OverlayClient`). `#738` two-phase dismiss
    /// contract: the reducer never tears the slot down before the view
    /// animation finishes — `AppFeature` clears `state.overlay` only when
    /// `.dismissed` arrives.
    private func runExitAnimation() {
        guard !hasStartedExitAnimation else { return }
        hasStartedExitAnimation = true

        let isAutoDismiss = store.secondsRemaining == 0

        if store.hapticsEnabled {
            if isAutoDismiss {
                impactGenerator?.impactOccurred()
            } else {
                notificationGenerator?.notificationOccurred(.success)
            }
        }

        if isAutoDismiss {
            withMotionSafe(reduceMotion, animation: AppAnimation.overlayFadeCurve) {
                contentOpacity = 0
            }
        } else {
            let screenHeight = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.screen.bounds.height ?? 1000
            withMotionSafe(reduceMotion, animation: AppAnimation.overlayDismissCurve) {
                contentOpacity = 0
                slideOffset = -screenHeight
            }
        }

        let baseDelay = isAutoDismiss ? AppAnimation.overlayAutoDismiss : AppAnimation.overlayDismiss
        let delay = reduceMotion ? 0.05 : baseDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            store.send(.dismissAnimationCompleted)
        }
    }
}

// MARK: - Previews

#Preview {
    OverlayView(
        store: Store(
            initialState: OverlayFeature.State(
                type: .eyes,
                duration: 20,
                hapticsEnabled: true
            )
        ) { OverlayFeature() }
    )
}

#Preview("Posture") {
    OverlayView(
        store: Store(
            initialState: OverlayFeature.State(
                type: .posture,
                duration: 10,
                hapticsEnabled: true
            )
        ) { OverlayFeature() }
    )
}
