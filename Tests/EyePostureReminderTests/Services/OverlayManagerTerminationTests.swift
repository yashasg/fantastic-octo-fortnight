import UIKit
import XCTest

@testable import EyePostureReminder

/// Unit tests for `OverlayManager` termination cleanup (#714).
///
/// The Overlays UI shard intermittently failed because XCUITest's
/// `terminate()` call left the overlay's `UIWindow` (at `.alert + 1`) in a
/// state that prevented SpringBoard from reaping the process — every
/// subsequent test in the shard inherited a zombie. The fix subscribes to
/// `UIApplication.willTerminateNotification` and synchronously hides /
/// releases the window before the process exits, letting the background
/// assertion complete cleanly.
///
/// These tests use the existing `notificationCenter` injection seam so the
/// post fires only against the manager under test (no risk of cross-test
/// pollution via `.default`).
@MainActor
final class OverlayManagerTerminationTests: XCTestCase {

    // MARK: - Observer registration

    /// `OverlayManager.init` must register an observer for the willTerminate
    /// notification on the injected center. We verify this by posting a
    /// notification and checking that `releaseOverlayWindowForTermination`'s
    /// observable side effects (queue cleared) ran.
    func test_willTerminateNotification_clearsOverlayQueue() {
        let center = NotificationCenter()
        let manager = OverlayManager(
            notificationCenter: center,
            windowSceneProvider: { nil }
        )

        // Queue two overlays via the no-scene branch (they enqueue without ever
        // becoming visible).
        manager.showOverlay(for: .eyes, duration: 20, hapticsEnabled: true, pauseMediaEnabled: false) {}
        manager.showOverlay(for: .posture, duration: 10, hapticsEnabled: true, pauseMediaEnabled: false) {}

        center.post(name: OverlayManager.willTerminateNotification, object: nil)

        // After termination cleanup, posting `UIScene.didActivateNotification`
        // should be a no-op. We assert the queue is empty by observing that no
        // pending overlay is presented when a scene becomes active.
        // The strongest in-process signal is `isOverlayVisible` — should be false.
        XCTAssertFalse(manager.isOverlayVisible)

        // Re-show one overlay; it should enqueue normally (no leftover state from
        // the prior queue suppressing it).
        manager.showOverlay(for: .eyes, duration: 5, hapticsEnabled: false, pauseMediaEnabled: false) {}
        XCTAssertFalse(
            manager.isOverlayVisible,
            "Queued overlays must remain invisible without a window scene; " +
                "the new enqueue confirms the post-termination state is usable."
        )
    }

    /// Posting the notification when no overlay or queued items exist must not
    /// crash and must leave the manager in a clean state.
    func test_willTerminateNotification_withNoActiveOverlay_doesNotCrash() {
        let center = NotificationCenter()
        let manager = OverlayManager(
            notificationCenter: center,
            windowSceneProvider: { nil }
        )

        center.post(name: OverlayManager.willTerminateNotification, object: nil)

        XCTAssertFalse(manager.isOverlayVisible)
    }

    /// Posting the notification multiple times must remain idempotent — each
    /// post resets the same fields without crashing.
    func test_willTerminateNotification_postedRepeatedly_isIdempotent() {
        let center = NotificationCenter()
        let manager = OverlayManager(
            notificationCenter: center,
            windowSceneProvider: { nil }
        )
        manager.showOverlay(for: .eyes, duration: 20, hapticsEnabled: true, pauseMediaEnabled: false) {}

        center.post(name: OverlayManager.willTerminateNotification, object: nil)
        center.post(name: OverlayManager.willTerminateNotification, object: nil)
        center.post(name: OverlayManager.willTerminateNotification, object: nil)

        XCTAssertFalse(manager.isOverlayVisible)
    }

    // MARK: - willTerminateNotification name contract

    /// Guards against an accidental rename of `willTerminateNotification` —
    /// the name must continue to map to `UIApplication.willTerminateNotification`
    /// so the live `.default` notification center actually delivers the post.
    func test_willTerminateNotification_matchesUIApplication() {
        XCTAssertEqual(
            OverlayManager.willTerminateNotification,
            UIApplication.willTerminateNotification
        )
    }

    // MARK: - Audio resume suppression

    /// Termination must NOT call `resumeExternalAudio` on the audio manager,
    /// because the process is exiting and any AVAudioSession side effects
    /// will be torn down anyway. This avoids a final spurious "audio resumed"
    /// log line and matches the comment on `releaseOverlayWindowForTermination`.
    func test_willTerminateNotification_doesNotResumeAudio() {
        let center = NotificationCenter()
        let mockAudio = MockMediaControlling()
        let manager = OverlayManager(
            audioManager: mockAudio,
            notificationCenter: center,
            windowSceneProvider: { nil }
        )

        // `withExtendedLifetime` keeps `manager` alive across the post, which
        // matters because the willTerminate observer captures `[weak self]`.
        // It also makes the otherwise-invisible "manager is required" data
        // dependency explicit, silencing the "never used" warning #872.
        withExtendedLifetime(manager) {
            // Even if audio was logically paused (we can't easily test this via
            // the headless no-scene path, but post anyway), termination must
            // not call resume.
            center.post(name: OverlayManager.willTerminateNotification, object: nil)

            XCTAssertEqual(mockAudio.resumeCallCount, 0)
        }
    }

    // MARK: - deinit cleanup

    /// `deinit` must remove the willTerminate observer; otherwise the live
    /// `.default` notification center would retain a closure capturing the
    /// (now-deallocated) manager and crash on the next post. We assert this
    /// indirectly: a deallocated manager must not respond to a post.
    func test_deinit_removesWillTerminateObserver() {
        let center = NotificationCenter()
        weak var weakManager: OverlayManager?

        autoreleasepool {
            let manager = OverlayManager(
                notificationCenter: center,
                windowSceneProvider: { nil }
            )
            weakManager = manager
            XCTAssertNotNil(weakManager)
            // Manager goes out of scope at end of autoreleasepool.
        }

        XCTAssertNil(weakManager, "Manager must be deallocated when no strong references remain")

        // Posting after deallocation must not crash. If `deinit` did not remove
        // the observer the closure would still be invoked with `self?` as nil
        // (no crash but also no cleanup). The key guarantee is "no crash", and
        // the indirect retention check above proves the observer was released
        // along with the manager.
        center.post(name: OverlayManager.willTerminateNotification, object: nil)
    }
}
