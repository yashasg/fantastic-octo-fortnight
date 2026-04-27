@testable import EyePostureReminder
import Foundation

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
    private(set) var clearQueueForTypeCallCount = 0
    private(set) var clearQueueForTypeArgs: [ReminderType] = []

    // MARK: - Ordered Call History

    /// `ReminderType` arguments passed to `showOverlay`, in call order.
    /// Use this to verify FIFO ordering at the AppCoordinator integration level.
    private(set) var showCallOrder: [ReminderType] = []

    /// Duration arguments passed to `showOverlay`, parallel to `showCallOrder`.
    private(set) var showCallDurations: [TimeInterval] = []

    /// `hapticsEnabled` arguments passed to `showOverlay`, parallel to `showCallOrder`.
    private(set) var showCallHapticsEnabled: [Bool] = []

    /// `pauseMediaEnabled` arguments passed to `showOverlay`, parallel to `showCallOrder`.
    private(set) var showCallPauseMediaEnabled: [Bool] = []

    /// `onDismiss` closures passed to `showOverlay`, in call order.
    /// Previously discarded; now stored so tests can verify the post-dismiss callback chain.
    private(set) var onDismissCalls: [() -> Void] = []

    // MARK: - State

    var isOverlayVisible = false

    // MARK: - Reset

    func reset() {
        showCallCount = 0
        dismissCallCount = 0
        clearQueueCallCount = 0
        clearQueueForTypeCallCount = 0
        clearQueueForTypeArgs = []
        showCallOrder = []
        showCallDurations = []
        showCallHapticsEnabled = []
        showCallPauseMediaEnabled = []
        onDismissCalls = []
        isOverlayVisible = false
    }

    // MARK: - Simulation Helpers

    /// Simulates an overlay dismissal by calling the stored `onDismiss` closure at
    /// the given index and marking the overlay as no longer visible.
    /// Use `index: 0` (default) for the most common case of a single pending dismiss.
    func simulateDismiss(index: Int = 0) {
        guard index < onDismissCalls.count else { return }
        isOverlayVisible = false
        onDismissCalls[index]()
    }

    // MARK: - OverlayPresenting

    func showOverlay(
        for type: ReminderType,
        duration: TimeInterval,
        hapticsEnabled: Bool,
        pauseMediaEnabled: Bool,
        onDismiss: @escaping () -> Void
    ) {
        showCallCount += 1
        showCallOrder.append(type)
        showCallDurations.append(duration)
        showCallHapticsEnabled.append(hapticsEnabled)
        showCallPauseMediaEnabled.append(pauseMediaEnabled)
        onDismissCalls.append(onDismiss)
        isOverlayVisible = true
    }

    func dismissOverlay() {
        dismissCallCount += 1
        isOverlayVisible = false
    }

    func clearQueue() {
        clearQueueCallCount += 1
    }

    func clearQueue(for type: ReminderType) {
        clearQueueForTypeCallCount += 1
        clearQueueForTypeArgs.append(type)
    }
}
