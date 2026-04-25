import os
import SwiftUI
import UIKit

// MARK: - OverlayPresenting Protocol

/// Abstracts UIWindow overlay lifecycle for testability.
///
/// The concrete implementation creates a secondary `UIWindow` at
/// `UIWindow.Level.alert + 1` so the overlay reliably covers all in-app
/// content. Tests inject a mock to verify scheduling logic without creating
/// real UIWindows.
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
    ///   - onDismiss: Called on the main thread after the overlay is dismissed.
    func showOverlay(
        for type: ReminderType,
        duration: TimeInterval,
        hapticsEnabled: Bool,
        onDismiss: @escaping () -> Void
    )

    /// Programmatically dismiss the overlay (e.g. user tapped "Done" or timer expired).
    func dismissOverlay()

    /// `true` while the overlay window is on screen.
    var isOverlayVisible: Bool { get }

    /// Drop all queued overlays (e.g. on snooze or master-toggle-off).
    func clearQueue()
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

    // MARK: - Singleton

    static let shared = OverlayManager()

    // MARK: - Dependencies

    private let audioManager: MediaControlling

    // MARK: - State

    private var overlayWindow: UIWindow?
    private var dismissCallback: (() -> Void)?

    /// Pending show requests queued while an overlay is already on screen.
    private var overlayQueue: [
        (type: ReminderType, duration: TimeInterval, hapticsEnabled: Bool, onDismiss: () -> Void)
    ] = []

    var isOverlayVisible: Bool {
        overlayWindow != nil && overlayWindow?.isHidden == false
    }

    // MARK: - Init

    init(audioManager: MediaControlling = AudioInterruptionManager()) {
        self.audioManager = audioManager
    }

    // MARK: - OverlayPresenting

    func showOverlay(
        for type: ReminderType,
        duration: TimeInterval,
        hapticsEnabled: Bool,
        onDismiss: @escaping () -> Void
    ) {
        guard !isOverlayVisible else {
            // Queue instead of stacking windows — dequeued after current overlay dismisses.
            overlayQueue.append((type: type, duration: duration, hapticsEnabled: hapticsEnabled, onDismiss: onDismiss))
            Logger.overlay.info("Overlay for \(type.rawValue) queued (overlay already visible). Queue depth: \(self.overlayQueue.count)")
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            Logger.overlay.error("No active UIWindowScene — cannot show overlay")
            return
        }

        audioManager.pauseExternalAudio()
        dismissCallback = onDismiss

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear

        let hostingController = UIHostingController(
            rootView: OverlayView(type: type, duration: duration, hapticsEnabled: hapticsEnabled) { [weak self] in
                Task { @MainActor in self?.dismissOverlay() }
            }
        )
        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        overlayWindow = window
        Logger.overlay.info("Overlay shown for type=\(type.rawValue), duration=\(duration)s")
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

    // MARK: - Private

    private func presentNextQueuedOverlay() {
        guard !overlayQueue.isEmpty else { return }
        let next = overlayQueue.removeFirst()
        Logger.overlay.info("Presenting queued overlay for \(next.type.rawValue). Remaining in queue: \(self.overlayQueue.count)")
        showOverlay(
            for: next.type,
            duration: next.duration,
            hapticsEnabled: next.hapticsEnabled,
            onDismiss: next.onDismiss)
    }
}
