import Foundation
@testable import EyePostureReminder

/// Mock implementation of `OverlayPresenting` for unit tests.
///
/// Records every call to `showOverlay`, `dismissOverlay`, and `clearQueue`
/// so tests can assert correct overlay lifecycle without touching UIKit.
/// `isOverlayVisible` is writable so tests can simulate an overlay already being on screen.
@MainActor
final class MockOverlayPresenting: OverlayPresenting {

    // MARK: - Call Counts

    private(set) var showCallCount = 0
    private(set) var dismissCallCount = 0
    private(set) var clearQueueCallCount = 0

    // MARK: - Ordered Call History

    /// `ReminderType` arguments passed to `showOverlay`, in call order.
    /// Use this to verify FIFO ordering at the AppCoordinator integration level.
    private(set) var showCallOrder: [ReminderType] = []

    /// Duration arguments passed to `showOverlay`, parallel to `showCallOrder`.
    private(set) var showCallDurations: [TimeInterval] = []

    /// `hapticsEnabled` arguments passed to `showOverlay`, parallel to `showCallOrder`.
    private(set) var showCallHapticsEnabled: [Bool] = []

    // MARK: - State

    var isOverlayVisible = false

    // MARK: - Reset

    func reset() {
        showCallCount = 0
        dismissCallCount = 0
        clearQueueCallCount = 0
        showCallOrder = []
        showCallDurations = []
        showCallHapticsEnabled = []
        isOverlayVisible = false
    }

    // MARK: - OverlayPresenting

    func showOverlay(
        for type: ReminderType,
        duration: TimeInterval,
        hapticsEnabled: Bool,
        onDismiss: @escaping () -> Void
    ) {
        showCallCount += 1
        showCallOrder.append(type)
        showCallDurations.append(duration)
        showCallHapticsEnabled.append(hapticsEnabled)
        isOverlayVisible = true
    }

    func dismissOverlay() {
        dismissCallCount += 1
        isOverlayVisible = false
    }

    func clearQueue() {
        clearQueueCallCount += 1
    }
}
