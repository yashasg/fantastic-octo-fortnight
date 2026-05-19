import ComposableArchitecture
import SwiftUI
import UIKit

/// Full-screen overlay displayed when an eye-break or posture reminder fires.
///
/// The view presents a calming gradient background, a countdown ring, and
/// dismiss controls (button, swipe-up, or settings link).
///
/// ## Two presentation paths
///
/// Phase 1 of #919 introduces a `StoreOf<OverlayFeature>` initializer alongside
/// the legacy closure-based one. The wrapper picks an internal body based on
/// which initializer was used:
///
/// - **`init(store:)`** — canonical TCA path used by `RootView`'s overlay
///   `.fullScreenCover`. Presentation state (countdown, dismissal phase,
///   analytics) flows through `OverlayFeature` so the reducer owns the
///   two-phase dismiss contract (#738). Used by the SwiftUI cover path that
///   replaces the `EmptyView()` placeholder.
/// - **`init(type:duration:onDismiss:…)`** — legacy closure path retained
///   for `OverlayManager`'s `UIWindow` + `UIHostingController` presentation
///   and the existing view-body tests. #919 Phase 2 (#920) retires this
///   path along with `OverlayManager`.
struct OverlayView: View {

    // MARK: - Static helpers (preserved for backward compat with existing tests)

    static let swipeDismissMinimumUpwardTravel: CGFloat = 30

    static func shouldDismissForSwipe(translation: CGSize) -> Bool {
        let upwardTravel = -translation.height
        guard upwardTravel >= swipeDismissMinimumUpwardTravel else { return false }
        return upwardTravel > abs(translation.width)
    }

    // MARK: - Mode dispatch

    private enum Mode {
        case closures(LegacyConfig)
        case store(StoreOf<OverlayFeature>)
    }

    fileprivate struct LegacyConfig {
        let type: ReminderType
        let duration: TimeInterval
        let hapticsEnabled: Bool
        let reduceMotionOverride: Bool?
        let onAnalyticsEvent: (AnalyticsEvent) -> Void
        let onSettingsTap: () -> Void
        let onDismiss: () -> Void
    }

    private let mode: Mode

    // MARK: - Backward-compat property accessors
    //
    // Existing tests (e.g. `CoverageBoostTests`) read `view.type`,
    // `view.duration`, `view.hapticsEnabled`, and call `view.onDismiss()` /
    // `view.onSettingsTap()` / `view.onAnalyticsEvent(_:)` directly. Preserve
    // those property surfaces here so the wrapper is a drop-in replacement.

    var type: ReminderType {
        switch mode {
        case .closures(let cfg): return cfg.type
        case .store(let store): return store.type
        }
    }

    var duration: TimeInterval {
        switch mode {
        case .closures(let cfg): return cfg.duration
        case .store(let store): return store.duration
        }
    }

    var hapticsEnabled: Bool {
        switch mode {
        case .closures(let cfg): return cfg.hapticsEnabled
        case .store(let store): return store.hapticsEnabled
        }
    }

    var onAnalyticsEvent: (AnalyticsEvent) -> Void {
        switch mode {
        case .closures(let cfg): return cfg.onAnalyticsEvent
        case .store: return { _ in }
        }
    }

    var onSettingsTap: () -> Void {
        switch mode {
        case .closures(let cfg): return cfg.onSettingsTap
        case .store: return {}
        }
    }

    var onDismiss: () -> Void {
        switch mode {
        case .closures(let cfg): return cfg.onDismiss
        case .store: return {}
        }
    }

    // MARK: - Initializers

    /// Legacy closure-driven initializer used by `OverlayManager`'s `UIWindow`
    /// + `UIHostingController` path and by existing view-body tests. Slated
    /// for removal when #919 Phase 2 (#920) retires the `UIWindow` path.
    init(
        type: ReminderType,
        duration: TimeInterval,
        hapticsEnabled: Bool = true,
        reduceMotionOverride: Bool? = nil,
        onAnalyticsEvent: @escaping (AnalyticsEvent) -> Void = { _ in },
        onSettingsTap: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void
    ) {
        self.mode = .closures(LegacyConfig(
            type: type,
            duration: duration,
            hapticsEnabled: hapticsEnabled,
            reduceMotionOverride: reduceMotionOverride,
            onAnalyticsEvent: onAnalyticsEvent,
            onSettingsTap: onSettingsTap,
            onDismiss: onDismiss
        ))
    }

    /// Canonical TCA initializer (#919 Phase 1). Reads countdown, dismissal,
    /// and analytics state from `OverlayFeature`; preserves the two-phase
    /// dismiss contract (#738) by dispatching `.dismissAnimationCompleted`
    /// once the SwiftUI exit transition finishes.
    init(store: StoreOf<OverlayFeature>) {
        self.mode = .store(store)
    }

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        switch mode {
        case .closures(let config):
            OverlayClosureView(config: config)
        case .store(let store):
            OverlayStoreView(store: store)
        }
    }
}

// MARK: - OverlayClosureView (legacy)

/// Legacy closure-driven overlay body used by `OverlayManager`'s `UIWindow`
/// path. Identical behaviour to the pre-#919 `OverlayView` implementation —
/// kept intact here so the existing test suite and `UIHostingController`
/// presentation continue to work unchanged until #920 retires this path.
private struct OverlayClosureView: View {

    let config: OverlayView.LegacyConfig

    @State private var secondsRemaining: Int
    @State private var timer: Timer?
    @State private var contentOpacity: Double = 0
    @State private var slideOffset: CGFloat = AppLayout.overlayEntranceOffset
    @State private var isDismissing = false

    // Generators created in onAppear and pre-prepared for low-latency haptics.
    @State private var impactGenerator: UIImpactFeedbackGenerator?
    @State private var notificationGenerator: UINotificationFeedbackGenerator?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(config: OverlayView.LegacyConfig) {
        self.config = config
        _secondsRemaining = State(initialValue: Int(config.duration))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            backgroundGradient
            dismissButton
            centerContent
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overlay.root")
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
                .fill(config.type.color.opacity(AppOpacity.iconAura))
            Image(systemName: config.type.symbolName)
                .symbolRenderingMode(.hierarchical)
                .font(AppFont.overlayIcon)
                .foregroundStyle(config.type.color)
        }
        .frame(
            width: AppLayout.overlayIconSize * 1.75,
            height: AppLayout.overlayIconSize * 1.75
        )
        .accessibilityHidden(true)
    }

    private var headlineSection: some View {
        Group {
            Text(config.type.overlayTitle)
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
                .accessibilitySortPriority(1)

            Text(config.type.overlaySupportiveText)
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
                .trim(from: 0, to: CGFloat(secondsRemaining) / CGFloat(max(config.duration, 1)))
                .stroke(
                    config.type.color,
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

    private var swipeUpDismissGesture: some Gesture {
        DragGesture(minimumDistance: OverlayView.swipeDismissMinimumUpwardTravel)
            .onEnded { value in
                if OverlayView.shouldDismissForSwipe(translation: value.translation) {
                    performDismiss(method: .swipe)
                }
            }
    }

    private func handleAppear() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impactGenerator = impact
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notificationGenerator = notification

        if config.hapticsEnabled { notification.notificationOccurred(.warning) }

        withMotionSafe(shouldReduceMotion, animation: AppAnimation.calmingEntranceCurve) {
            contentOpacity = 1
            slideOffset = 0
        }
        startTimer()
    }

    private func performDismiss(method: AnalyticsEvent.DismissMethod = .button) {
        guard !isDismissing else { return }
        isDismissing = true
        timer?.invalidate()
        let elapsedS = config.duration - TimeInterval(secondsRemaining)
        config.onAnalyticsEvent(.overlayDismissed(type: config.type, method: method, elapsedS: elapsedS))
        if method == .settingsTap {
            config.onSettingsTap()
        }
        if config.hapticsEnabled { notificationGenerator?.notificationOccurred(.success) }
        let screenHeight = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.height ?? 1000
        withMotionSafe(shouldReduceMotion, animation: AppAnimation.overlayDismissCurve) {
            contentOpacity = 0
            slideOffset = -screenHeight
        }
        let delay = shouldReduceMotion ? 0.05 : AppAnimation.overlayDismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            config.onDismiss()
        }
    }

    private func performAutoDismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        config.onAnalyticsEvent(.overlayAutoDismissed(type: config.type, durationS: config.duration))
        triggerCompletionHaptic()
        withMotionSafe(shouldReduceMotion, animation: AppAnimation.overlayFadeCurve) {
            contentOpacity = 0
        }
        let delay = shouldReduceMotion ? 0.05 : AppAnimation.overlayAutoDismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            config.onDismiss()
        }
    }

    private var shouldReduceMotion: Bool {
        config.reduceMotionOverride ?? reduceMotion
    }

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

    private func triggerCompletionHaptic() {
        guard config.hapticsEnabled else { return }
        impactGenerator?.impactOccurred()
    }
}

// MARK: - OverlayStoreView (canonical TCA path, #919 Phase 1)

/// TCA-driven overlay body. Reads countdown, dismissal phase, and analytics
/// state from `OverlayFeature`; preserves the two-phase dismiss contract
/// (#738) by dispatching `.dismissAnimationCompleted` after the SwiftUI exit
/// transition finishes. Used by `RootView`'s overlay `.fullScreenCover`.
///
/// Entrance / exit animations remain local `@State` (matching the legacy
/// implementation) so the reducer stays UI-agnostic: it only knows whether
/// the dismiss flow has been acknowledged (`state.isDismissing`) and whether
/// the side-effect tear-down has fired (`state.isFinalized`).
private struct OverlayStoreView: View {

    @Perception.Bindable var store: StoreOf<OverlayFeature>

    @State private var contentOpacity: Double = 0
    @State private var slideOffset: CGFloat = AppLayout.overlayEntranceOffset
    @State private var hasStartedExitAnimation = false

    // Generators created in onAppear and pre-prepared for low-latency haptics.
    @State private var impactGenerator: UIImpactFeedbackGenerator?
    @State private var notificationGenerator: UINotificationFeedbackGenerator?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WithPerceptionTracking {
            ZStack(alignment: .topTrailing) {
                backgroundGradient
                dismissButton
                centerContent
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("overlay.root")
            // Modal suppression: SwiftUI's `accessibilityViewIsModal(_:)` is
            // not available in the current SDK and `.isModal` trait alone
            // does not suppress VoiceOver traversal. The fullScreenCover host
            // already isolates focus, but #920 should add a SwiftUI-native
            // equivalent before the UIKit OverlayManager path is retired.
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
    /// effect (`overlayClient.dismiss()` → `.dismissed`). #738 two-phase
    /// dismiss contract: the reducer never tears the slot down before the
    /// view animation finishes.
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
    OverlayView(type: .eyes, duration: 20) {}
}

#Preview("Posture") {
    OverlayView(type: .posture, duration: 10) {}
}

#Preview("Store-driven") {
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
