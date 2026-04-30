import os
// SwiftUI required for UIHostingController<OverlayView>
import SwiftUI
import UIKit

// MARK: - OverlayPresenting Protocol

struct OverlayLifecycleCallbacks {
    let onPresent: () -> Void
    let onDismiss: () -> Void

    init(
        onPresent: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.onPresent = onPresent
        self.onDismiss = onDismiss
    }
}

/// Abstracts UIWindow overlay lifecycle for testability.
///
/// The concrete implementation creates a secondary `UIWindow` at
/// `UIWindow.Level.alert + 1` so the overlay reliably covers all in-app
/// content. Tests inject a mock to verify scheduling logic without creating
/// real UIWindows.
@MainActor
protocol OverlayPresenting: AnyObject {
    /// Present a full-screen break overlay for the given reminder type.
    ///
    /// If an overlay is already on screen the request is queued and presented
    /// automatically after the current overlay dismisses.
    ///
    /// - Parameters:
    ///   - type: Which reminder triggered the overlay.
    ///   - duration: Suggested break duration in seconds (overlay may use this
    ///               for a countdown UI).
    ///   - hapticsEnabled: Whether haptic feedback should fire on this overlay.
    ///   - pauseMediaEnabled: Whether to interrupt external audio during this overlay.
    ///   - callbacks: Lifecycle hooks called after presentation and dismissal.
    func showOverlay(
        for type: ReminderType,
        duration: TimeInterval,
        hapticsEnabled: Bool,
        pauseMediaEnabled: Bool,
        callbacks: OverlayLifecycleCallbacks
    )

    /// Programmatically dismiss the overlay (e.g. user tapped "Done" or timer expired).
    func dismissOverlay()

    /// `true` while the overlay window is on screen.
    var isOverlayVisible: Bool { get }

    /// Drop all queued overlays (e.g. on snooze or master-toggle-off).
    func clearQueue()

    /// Drop all queued overlays for a specific reminder type (e.g. when a single
    /// reminder type is cancelled without affecting other queued types).
    func clearQueue(for type: ReminderType)
}

extension OverlayPresenting {
    func showOverlay(
        for type: ReminderType,
        duration: TimeInterval,
        hapticsEnabled: Bool,
        pauseMediaEnabled: Bool,
        onDismiss: @escaping () -> Void
    ) {
        showOverlay(
            for: type,
            duration: duration,
            hapticsEnabled: hapticsEnabled,
            pauseMediaEnabled: pauseMediaEnabled,
            callbacks: OverlayLifecycleCallbacks(onDismiss: onDismiss)
        )
    }
}

// MARK: - OverlayManager

/// Concrete `OverlayPresenting` implementation.
///
/// Lifecycle rules:
/// 1. `overlayWindow` is created on-demand and set to `nil` after dismissal —
///    never cached — to avoid retain cycles and memory pressure between breaks.
/// 2. All mutations must occur on the main thread (`@MainActor`).
/// 3. If `showOverlay` is called while an overlay is already visible the request
///    is appended to `overlayQueue`. After each dismissal the manager pops the
///    next queued entry and presents it automatically.
/// 4. `audioManager.pauseExternalAudio()` is called before the overlay appears
///    and `resumeExternalAudio()` is called in every dismiss path.
@MainActor
final class OverlayManager: OverlayPresenting {

    // MARK: - Dependencies

    private let audioManager: MediaControlling
    private let accessibilityNotificationPoster: AccessibilityNotificationPosting

    // MARK: - State

    private var overlayWindow: UIWindow?
    private var dismissCallback: (() -> Void)?
    private var sceneActivationObserver: NSObjectProtocol?

    /// A single queued overlay-show request.
    private struct QueuedOverlay {
        let type: ReminderType
        let duration: TimeInterval
        let hapticsEnabled: Bool
        let pauseMediaEnabled: Bool
        let callbacks: OverlayLifecycleCallbacks
    }

    /// Pending show requests queued while an overlay is already on screen.
    private var overlayQueue: [QueuedOverlay] = []

    var isOverlayVisible: Bool {
        overlayWindow != nil && overlayWindow?.isHidden == false
    }

    // MARK: - Init

    init(
        audioManager: MediaControlling = AudioInterruptionManager(),
        accessibilityNotificationPoster: AccessibilityNotificationPosting = LiveAccessibilityNotificationPoster()
    ) {
        self.audioManager = audioManager
        self.accessibilityNotificationPoster = accessibilityNotificationPoster
        sceneActivationObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.presentNextQueuedOverlay()
            }
        }
    }

    deinit {
        if let obs = sceneActivationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - OverlayPresenting

    func showOverlay(
        for type: ReminderType,
        duration: TimeInterval,
        hapticsEnabled: Bool,
        pauseMediaEnabled: Bool,
        callbacks: OverlayLifecycleCallbacks
    ) {
        guard !isOverlayVisible else {
            // Queue instead of stacking windows — dequeued after current overlay dismisses.
            overlayQueue.append(QueuedOverlay(
                type: type,
                duration: duration,
                hapticsEnabled: hapticsEnabled,
                pauseMediaEnabled: pauseMediaEnabled,
                callbacks: callbacks))
            Logger.overlay.info("Overlay for \(type.rawValue) queued (overlay already visible). Queue depth: \(self.overlayQueue.count)")
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            // Queue the request so it is shown once a scene becomes foreground-active.
            overlayQueue.append(QueuedOverlay(
                type: type,
                duration: duration,
                hapticsEnabled: hapticsEnabled,
                pauseMediaEnabled: pauseMediaEnabled,
                callbacks: callbacks))
            Logger.overlay.warning(
                "No active UIWindowScene — overlay for \(type.rawValue) queued (depth: \(self.overlayQueue.count))"
            )
            return
        }

        if pauseMediaEnabled {
            audioManager.pauseExternalAudio()
        }
        dismissCallback = callbacks.onDismiss

        // Do NOT set window.overrideUserInterfaceStyle — the window must inherit the
        // scene's appearance so the overlay renders correctly in both light and dark mode.
        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear

        let hostingController = UIHostingController(
            rootView: OverlayView(
                type: type,
                duration: duration,
                hapticsEnabled: hapticsEnabled,
                onAnalyticsEvent: AnalyticsLogger.log,
                onSettingsTap: {
                    UserDefaults.standard.set(true, forKey: AppStorageKey.openSettingsOnLaunch)
                },
                onDismiss: { [weak self] in
                    Task { @MainActor in self?.dismissOverlay() }
                }
            )
        )
        hostingController.view.backgroundColor = .clear
        hostingController.view.accessibilityViewIsModal = true
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        overlayWindow = window
        accessibilityNotificationPoster.postScreenChanged(focusElement: nil)
        Logger.overlay.info("Overlay shown for type=\(type.rawValue), duration=\(duration)s")
        callbacks.onPresent()
    }

    func dismissOverlay() {
        guard isOverlayVisible else { return }

        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayWindow = nil

        audioManager.resumeExternalAudio()

        let callback = dismissCallback
        dismissCallback = nil
        callback?()

        Logger.overlay.info("Overlay dismissed")

        // Debug assertion to catch accidental window retention.
        assert(overlayWindow == nil, "OverlayManager: overlayWindow must be nil after dismissal")

        // Present the next queued overlay, if any.
        presentNextQueuedOverlay()
    }

    // MARK: - Queue Management

    /// Drop all queued overlays (e.g. on snooze or master-toggle-off).
    func clearQueue() {
        overlayQueue.removeAll()
        Logger.overlay.info("Overlay queue cleared")
    }

    /// Drop all queued overlays for a specific reminder type.
    func clearQueue(for type: ReminderType) {
        let before = overlayQueue.count
        overlayQueue.removeAll { $0.type == type }
        let removed = before - overlayQueue.count
        if removed > 0 {
            Logger.overlay.info(
                "Overlay queue removed \(removed) item(s) for \(type.rawValue); remaining \(self.overlayQueue.count)"
            )
        }
    }

    // MARK: - Private

    private func presentNextQueuedOverlay() {
        // Guard: do not dequeue while an overlay is already visible.
        // Without this, a UIScene.didActivateNotification arriving mid-display
        // would remove the queue head, call showOverlay (which re-appends it at
        // the tail because isOverlayVisible is true), corrupting FIFO order. (#289)
        guard !isOverlayVisible else { return }
        guard !overlayQueue.isEmpty else { return }
        guard UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .contains(where: { $0.activationState == .foregroundActive })
        else {
            Logger.overlay.warning(
                "presentNextQueuedOverlay: no active scene — item retained in queue for next attempt"
            )
            return
        }
        let next = overlayQueue.removeFirst()
        Logger.overlay.info("Presenting queued overlay for \(next.type.rawValue). Remaining in queue: \(self.overlayQueue.count)")
        showOverlay(
            for: next.type,
            duration: next.duration,
            hapticsEnabled: next.hapticsEnabled,
            pauseMediaEnabled: next.pauseMediaEnabled,
            callbacks: next.callbacks)
    }
}
