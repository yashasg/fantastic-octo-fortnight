import XCTest
@testable import EyePostureReminder

/// Unit tests for `AudioInterruptionManager`.
///
/// These tests verify protocol conformance and that the `AVAudioSession` calls
/// do not crash in the headless test environment. In the simulator the session
/// API is a no-op, so we validate the interface contract rather than actual
/// audio interruption behaviour (which is exercised in the simulator suite).
final class AudioInterruptionManagerTests: XCTestCase {

    var sut: AudioInterruptionManager!

    override func setUp() {
        super.setUp()
        sut = AudioInterruptionManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Protocol Conformance

    func test_conformsToMediaControlling() {
        let controlling: MediaControlling? = sut
        XCTAssertNotNil(controlling, "AudioInterruptionManager must conform to MediaControlling")
    }

    func test_assignableAsMediaControlling() {
        let controlling: MediaControlling = sut
        XCTAssertNotNil(controlling)
    }

    // MARK: - pauseExternalAudio

    func test_pauseExternalAudio_doesNotCrash() {
        sut.pauseExternalAudio()
    }

    func test_pauseExternalAudio_calledMultipleTimes_doesNotCrash() {
        sut.pauseExternalAudio()
        sut.pauseExternalAudio()
        sut.pauseExternalAudio()
    }

    // MARK: - resumeExternalAudio

    func test_resumeExternalAudio_doesNotCrash() {
        sut.resumeExternalAudio()
    }

    func test_resumeExternalAudio_calledMultipleTimes_doesNotCrash() {
        sut.resumeExternalAudio()
        sut.resumeExternalAudio()
    }

    // MARK: - Critical Invariant: resume without prior pause

    /// Verifies `resumeExternalAudio` is safe to call even if
    /// `pauseExternalAudio` was never invoked — e.g. crash-on-launch recovery.
    func test_resumeWithoutPause_doesNotCrash() {
        sut.resumeExternalAudio()
    }

    // MARK: - Paired Lifecycle

    func test_pauseThenResume_doesNotCrash() {
        sut.pauseExternalAudio()
        sut.resumeExternalAudio()
    }

    func test_multiplePauseThenResumeCycles_doNotCrash() {
        for _ in 0..<3 {
            sut.pauseExternalAudio()
            sut.resumeExternalAudio()
        }
    }
}
