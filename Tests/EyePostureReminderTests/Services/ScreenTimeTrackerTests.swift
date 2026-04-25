@testable import EyePostureReminder
import UIKit
import XCTest

/// Unit tests for `ScreenTimeTracker`.
///
/// Tests are split into two groups:
/// 1. **Synchronous** — configuration, state mutation, and guard checks that
///    do not require the tick timer to fire.
/// 2. **Timer-driven** — async tests that post lifecycle notifications so the
///    real 1-second `Timer` fires and asserts threshold-callback behavior.
///
/// Note: `startIfActive()` checks `UIApplication.shared.applicationState`. In the
/// test runner the state is `.background`, so it does **not** start the timer.
/// Instead these tests post `UIApplication.didBecomeActiveNotification` directly
/// to drive `handleDidBecomeActive` → `startTicking()`.
///
/// The class is `@MainActor` so that `NotificationCenter.default.post` calls are
/// made from the main thread, ensuring `Timer.scheduledTimer` is scheduled on
/// the main RunLoop — which `await fulfillment(of:)` keeps spinning.
@MainActor
final class ScreenTimeTrackerTests: XCTestCase {

    var sut: ScreenTimeTracker!

    override func setUp() {
        super.setUp()
        sut = ScreenTimeTracker()
    }

    override func tearDown() {
        sut.stop()
        sut = nil
        super.tearDown()
    }

    // MARK: - setThreshold

    func test_setThreshold_doesNotCrash() {
        sut.setThreshold(30, for: .eyes)
        sut.setThreshold(20, for: .posture)
    }

    func test_setThreshold_zero_doesNotCrash() {
        sut.setThreshold(0, for: .eyes)
    }

    func test_setThreshold_updatedForSameType_doesNotCrash() {
        sut.setThreshold(30, for: .eyes)
        sut.setThreshold(60, for: .eyes)
    }

    func test_setThreshold_largeValue_doesNotCrash() {
        sut.setThreshold(86_400, for: .posture) // 24h
    }

    // MARK: - disableTracking

    func test_disableTracking_afterThresholdSet_doesNotCrash() {
        sut.setThreshold(30, for: .eyes)
        sut.disableTracking(for: .eyes)
    }

    func test_disableTracking_withNoThresholdSet_doesNotCrash() {
        sut.disableTracking(for: .posture)
    }

    func test_disableTracking_calledTwice_doesNotCrash() {
        sut.setThreshold(30, for: .eyes)
        sut.disableTracking(for: .eyes)
        sut.disableTracking(for: .eyes)
    }

    // MARK: - pause / resume

    func test_pause_forType_doesNotCrash() {
        sut.pause(for: .eyes)
    }

    func test_pause_multipleTypes_doesNotCrash() {
        sut.pause(for: .eyes)
        sut.pause(for: .posture)
    }

    func test_pause_calledTwice_forSameType_doesNotCrash() {
        sut.pause(for: .eyes)
        sut.pause(for: .eyes)
    }

    func test_resume_withNoPauseActive_doesNotCrash() {
        sut.resume(for: .eyes)
    }

    func test_pause_thenResume_doesNotCrash() {
        sut.pause(for: .eyes)
        sut.resume(for: .eyes)
    }

    func test_resume_calledTwice_doesNotCrash() {
        sut.pause(for: .eyes)
        sut.resume(for: .eyes)
        sut.resume(for: .eyes)
    }

    // MARK: - pauseAll / resumeAll

    func test_pauseAll_doesNotCrash() {
        sut.pauseAll()
    }

    func test_pauseAll_calledTwice_doesNotCrash() {
        sut.pauseAll()
        sut.pauseAll()
    }

    func test_resumeAll_withNothingPaused_doesNotCrash() {
        sut.resumeAll()
    }

    func test_pauseAll_thenResumeAll_doesNotCrash() {
        sut.pauseAll()
        sut.resumeAll()
    }

    func test_resumeAll_afterPauseAll_allowsTickingToResumeWithoutCrash() {
        sut.setThreshold(30, for: .eyes)
        sut.pauseAll()
        sut.resumeAll()
    }

    // MARK: - reset

    func test_reset_forType_doesNotCrash() {
        sut.reset(for: .eyes)
        sut.reset(for: .posture)
    }

    func test_reset_afterThresholdSet_doesNotCrash() {
        sut.setThreshold(30, for: .eyes)
        sut.reset(for: .eyes)
    }

    func test_resetAll_doesNotCrash() {
        sut.resetAll()
    }

    func test_resetAll_afterThresholds_doesNotCrash() {
        sut.setThreshold(30, for: .eyes)
        sut.setThreshold(20, for: .posture)
        sut.resetAll()
    }

    // MARK: - stop

    func test_stop_doesNotCrash() {
        sut.stop()
    }

    func test_stop_calledTwice_doesNotCrash() {
        sut.stop()
        sut.stop()
    }

    func test_stop_afterConfiguration_doesNotCrash() {
        sut.setThreshold(30, for: .eyes)
        sut.setThreshold(20, for: .posture)
        sut.stop()
    }

    func test_stop_afterPauseAll_doesNotCrash() {
        sut.pauseAll()
        sut.stop()
    }

    // MARK: - startIfActive

    /// `startIfActive()` must not crash even when UIApplication state is `.background`
    /// (the case in the test runner — it silently no-ops).
    func test_startIfActive_doesNotCrash() {
        sut.startIfActive()
    }

    func test_startIfActive_calledTwice_doesNotCrash() {
        sut.startIfActive()
        sut.startIfActive()
    }

    // MARK: - onThresholdReached callback

    func test_onThresholdReached_canBeAssigned() {
        var fired = false
        sut.onThresholdReached = { _ in fired = true }
        XCTAssertFalse(fired, "Setting the callback must not fire it")
    }

    func test_onThresholdReached_canBeSetToNil() {
        sut.onThresholdReached = { _ in }
        sut.onThresholdReached = nil
    }

    func test_onThresholdReached_setThenReplaced_doesNotCrash() {
        sut.onThresholdReached = { _ in }
        sut.onThresholdReached = { type in _ = type }
        sut.onThresholdReached = nil
    }

    // MARK: - Grace-period: willResignActive → immediate didBecomeActive (cancel path)

    /// If `didBecomeActiveNotification` fires within the 5 s grace period, the
    /// pending reset task is cancelled and counting resumes without clearing counters.
    /// This test posts both notifications synchronously and verifies no crash.
    func test_willResignActive_immediatelyFollowedByDidBecomeActive_doesNotCrash() {
        sut.setThreshold(60, for: .eyes)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    func test_willResignActive_postedTwice_doesNotCrash() {
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        sut.stop() // cancel any pending task
    }

    func test_didBecomeActive_postedWithNoThreshold_doesNotCrash() {
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    // MARK: - Timer-driven threshold callback (2-second integration)

    /// Verifies the full tick → threshold → callback path.
    ///
    /// Sets threshold = 2, posts `didBecomeActiveNotification` to arm the 1 s
    /// tick timer, then waits up to 5 s for the callback to fire.
    func test_thresholdReached_callbackFires_afterSufficientTicks() async throws {
        let exp = expectation(description: "threshold callback fires for .eyes")
        sut.setThreshold(2, for: .eyes)
        sut.onThresholdReached = { type in
            if type == .eyes { exp.fulfill() }
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        await fulfillment(of: [exp], timeout: 5.0)
        sut.stop()
    }

    func test_thresholdReached_callbackFires_forPosture() async throws {
        let exp = expectation(description: "threshold callback fires for .posture")
        sut.setThreshold(2, for: .posture)
        sut.onThresholdReached = { type in
            if type == .posture { exp.fulfill() }
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        await fulfillment(of: [exp], timeout: 5.0)
        sut.stop()
    }

    /// After a threshold fires, the elapsed counter resets to 0, so the callback
    /// fires again after another `threshold` seconds of continuous ticking.
    func test_thresholdReached_elapsedResets_allowsSubsequentCallbacks() async throws {
        var callCount = 0
        let firstFire = expectation(description: "first threshold fire")
        let secondFire = expectation(description: "second threshold fire")

        sut.setThreshold(2, for: .eyes)
        sut.onThresholdReached = { type in
            guard type == .eyes else { return }
            callCount += 1
            if callCount == 1 { firstFire.fulfill() }
            if callCount == 2 { secondFire.fulfill() }
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        await fulfillment(of: [firstFire, secondFire], timeout: 8.0)
        XCTAssertGreaterThanOrEqual(callCount, 2, "Callback must fire multiple times after counter reset")
        sut.stop()
    }

    // MARK: - Pause prevents threshold from firing

    /// A paused type must never trigger the callback even after the tick timer runs.
    func test_pausedType_doesNotFireCallback() async throws {
        var callbackFired = false
        let noCallback = expectation(description: "paused type must not fire callback")
        noCallback.isInverted = true
        sut.setThreshold(2, for: .eyes)
        sut.pause(for: .eyes)
        sut.onThresholdReached = { _ in
            callbackFired = true
            noCallback.fulfill()
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        await fulfillment(of: [noCallback], timeout: 3.5)
        XCTAssertFalse(callbackFired, "Paused type must not fire the threshold callback")
        sut.stop()
    }

    // MARK: - setThreshold guard: only calls resumeAll on actual change

    /// Verifies that calling `setThreshold` with the same value still works and
    /// resets the elapsed counter (the guard is in the caller, not here — both
    /// calls succeed without crashing).
    func test_setThreshold_calledWithSameValue_doesNotCrash() {
        sut.setThreshold(30, for: .eyes)
        sut.setThreshold(30, for: .eyes) // same value — no crash expected
    }

    /// `disableTracking` followed immediately by `setThreshold` must not
    /// leave the tracker in an inconsistent state.
    func test_disableTracking_thenSetThreshold_doesNotCrash() {
        sut.setThreshold(30, for: .eyes)
        sut.disableTracking(for: .eyes)
        sut.setThreshold(60, for: .eyes)
    }

    // MARK: - Behavioral: resume after pause

    /// `pause` followed by `resume` must allow the threshold callback to fire again.
    /// This verifies the pause/resume cycle is reversible and counting resumes from 0
    /// (pause resets elapsed to 0 per the ScreenTimeTracker contract).
    func test_resume_afterPause_callbackEventuallyFires() async throws {
        let exp = expectation(description: "callback fires after resume")
        sut.setThreshold(2, for: .eyes)
        sut.pause(for: .eyes)
        sut.onThresholdReached = { type in
            if type == .eyes { exp.fulfill() }
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        // Timer is running but .eyes is paused — wait 1 s, then resume.
        // After resume the elapsed counter is 0 (pause resets it), so the threshold
        // must fire after another ~2 s of ticking.
        try await Task.sleep(nanoseconds: 1_000_000_000)
        sut.resume(for: .eyes)

        await fulfillment(of: [exp], timeout: 5.0)
        sut.stop()
    }

    // MARK: - Behavioral: disableTracking prevents callback permanently

    /// After `disableTracking` the type must never fire a threshold callback,
    /// even if the tick timer is running — the threshold entry is removed.
    func test_disableTracking_preventsCallback() async throws {
        var eyesFired = false
        let postureExp = expectation(description: "posture callback fires (timer is alive)")

        sut.setThreshold(2, for: .eyes)
        sut.setThreshold(2, for: .posture)
        sut.onThresholdReached = { type in
            if type == .eyes    { eyesFired = true }
            if type == .posture { postureExp.fulfill() }
        }

        // Disable .eyes BEFORE starting the timer so the threshold entry is removed.
        sut.disableTracking(for: .eyes)

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        // Wait for posture to fire (proves the timer is alive).
        await fulfillment(of: [postureExp], timeout: 5.0)
        XCTAssertFalse(eyesFired, "disableTracking must permanently prevent .eyes from firing")
        sut.stop()
    }

    // MARK: - Behavioral: setThreshold(0) never fires callback

    /// A threshold of exactly 0 must be ignored by the tick logic (guard: threshold > 0).
    func test_setThreshold_zero_neverFiresCallback() async throws {
        var eyesFired = false
        let postureExp = expectation(description: "posture fires (non-zero threshold)")

        sut.setThreshold(0, for: .eyes)
        sut.setThreshold(2, for: .posture)
        sut.onThresholdReached = { type in
            if type == .eyes    { eyesFired = true }
            if type == .posture { postureExp.fulfill() }
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        await fulfillment(of: [postureExp], timeout: 5.0)
        XCTAssertFalse(eyesFired, "threshold = 0 must never trigger the callback")
        sut.stop()
    }

    // MARK: - Behavioral: pauseAll / resumeAll

    /// `pauseAll` must prevent ALL types from firing their threshold callbacks.
    func test_pauseAll_preventsAllCallbacks() async throws {
        var eyesFired = false
        var postureFired = false

        sut.setThreshold(2, for: .eyes)
        sut.setThreshold(2, for: .posture)
        sut.pauseAll()
        sut.onThresholdReached = { type in
            if type == .eyes    { eyesFired   = true }
            if type == .posture { postureFired = true }
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        try await Task.sleep(nanoseconds: 3_000_000_000)
        XCTAssertFalse(eyesFired, "pauseAll must prevent .eyes callback")
        XCTAssertFalse(postureFired, "pauseAll must prevent .posture callback")
        sut.stop()
    }

    /// After `resumeAll`, ALL types paused with `pauseAll` must be able to fire again.
    func test_resumeAll_afterPauseAll_allowsAllCallbacks() async throws {
        let eyesExp    = expectation(description: ".eyes fires after resumeAll")
        let postureExp = expectation(description: ".posture fires after resumeAll")

        sut.setThreshold(2, for: .eyes)
        sut.setThreshold(2, for: .posture)
        sut.pauseAll()
        sut.onThresholdReached = { type in
            if type == .eyes    { eyesExp.fulfill() }
            if type == .posture { postureExp.fulfill() }
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 s — still paused
        sut.resumeAll()

        await fulfillment(of: [eyesExp, postureExp], timeout: 6.0)
        sut.stop()
    }

}

// MARK: - Stop & Reset Tests

extension ScreenTimeTrackerTests {

    // MARK: - Behavioral: stop invalidates timer

    /// After `stop()`, no threshold callbacks must fire even if the timer would have
    /// fired had it kept running.
    func test_stop_preventsCallbacksAfterStop() async throws {
        let firstExp = expectation(description: "first callback fires before stop")
        var callCount = 0

        sut.setThreshold(1, for: .eyes)
        sut.onThresholdReached = { type in
            guard type == .eyes else { return }
            callCount += 1
            firstExp.fulfill()
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        await fulfillment(of: [firstExp], timeout: 5.0)
        sut.stop() // invalidates the timer immediately

        let countAfterStop = callCount
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 s — timer should be dead
        XCTAssertEqual(callCount, countAfterStop, "stop() must invalidate the timer — no callbacks after stop")
    }

    // MARK: - Behavioral: reset zeroes elapsed counter

    /// After `reset(for:)`, the type must require a full threshold period before
    /// firing the callback — i.e. the elapsed counter is genuinely zeroed.
    ///
    /// Strategy: set threshold = 1, start the timer, wait 0.8 s (close to threshold
    /// but before it fires), reset the counter, then measure the time until the
    /// callback fires.  It must be ≥ ~0.8 s from the reset (not ~0.2 s), proving
    /// the counter was zeroed.
    func test_reset_zeroesElapsed_delaysNextCallback() async throws {
        let exp = expectation(description: "callback fires after reset")
        var callCount = 0

        sut.setThreshold(2, for: .eyes)
        sut.onThresholdReached = { type in
            guard type == .eyes else { return }
            callCount += 1
            exp.fulfill()
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        // Wait ~1 s so elapsed is approximately 1 (half of threshold=2).
        try await Task.sleep(nanoseconds: 1_100_000_000)
        // Reset elapsed to 0 — callback should NOT fire for another ~2 s.
        sut.reset(for: .eyes)

        let resetTime = Date()
        await fulfillment(of: [exp], timeout: 5.0)
        let elapsed = Date().timeIntervalSince(resetTime)

        XCTAssertGreaterThanOrEqual(
            elapsed,
            1.5,
            "After reset, callback must not fire sooner than ~threshold (2 s) — elapsed was \(elapsed) s"
        )
        XCTAssertEqual(callCount, 1, "Exactly one callback must fire after reset")
        sut.stop()
    }
}
