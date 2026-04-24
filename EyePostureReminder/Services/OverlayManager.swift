import UIKit
import SwiftUI
import os

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
    /// - Parameters:
    ///   - type: Which reminder triggered the overlay.
    ///   - duration: Suggested break duration in seconds (overlay may use this
    ///               for a countdown UI).
    ///   - onDismiss: Called on the main thread after the overlay is dismissed.
    func showOverlay(
        for type: ReminderType,
        duration: TimeInterval,
        onDismiss: @escaping () -> Void
    )

    /// Programmatically dismiss the overlay (e.g. user tapped "Done" or timer expired).
    func dismissOverlay()

    /// `true` while the overlay window is on screen.
    var isOverlayVisible: Bool { get }
}

// MARK: - OverlayManager

/// Concrete `OverlayPresenting` implementation.
///
/// Lifecycle rules:
/// 1. `overlayWindow` is created on-demand and set to `nil` after dismissal —
///    never cached — to avoid retain cycles and memory pressure between breaks.
/// 2. All mutations must occur on the main thread (`@MainActor`).
/// 3. Callers are responsible for requesting window scene access before calling
///    `showOverlay`. `OverlayManager` does not traverse the scene graph itself.
@MainActor
final class OverlayManager: OverlayPresenting {

    // MARK: - Singleton

    static let shared = OverlayManager()

    // MARK: - State

    private var overlayWindow: UIWindow?
    private var dismissCallback: (() -> Void)?

    var isOverlayVisible: Bool {
        overlayWindow != nil && overlayWindow?.isHidden == false
    }

    // MARK: - OverlayPresenting

    func showOverlay(
        for type: ReminderType,
        duration: TimeInterval,
        onDismiss: @escaping () -> Void
    ) {
        guard !isOverlayVisible else {
            Logger.overlay.warning("showOverlay called while overlay already visible — ignoring")
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            Logger.overlay.error("No active UIWindowScene — cannot show overlay")
            return
        }

        dismissCallback = onDismiss

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear

        let hostingController = UIHostingController(
            rootView: OverlayView(type: type, duration: duration) { [weak self] in
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

        let callback = dismissCallback
        dismissCallback = nil
        callback?()

        Logger.overlay.info("Overlay dismissed")

        // Debug assertion to catch accidental window retention.
        assert(overlayWindow == nil, "OverlayManager: overlayWindow must be nil after dismissal")
    }
}
