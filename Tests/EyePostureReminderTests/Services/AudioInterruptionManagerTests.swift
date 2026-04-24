import XCTest
@testable import EyePostureReminder

/// Unit tests for `AudioInterruptionManager`.
///
/// Phase 2 implementation is intentionally empty stubs — these tests verify
/// the protocol conformance contract and that the stubs do not crash. Full
/// AVAudioSession integration tests belong in a Phase 2 test target.
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
        XCTAssertTrue(sut is MediaControlling)
    }

    func test_assignableAsMediaControlling() {
        let controlling: MediaControlling = sut
        XCTAssertNotNil(controlling)
    }

    // MARK: - Phase 2 Stub — pauseExternalAudio

    func test_pauseExternalAudio_doesNotCrash() {
        sut.pauseExternalAudio()
    }

    func test_pauseExternalAudio_calledMultipleTimes_doesNotCrash() {
        sut.pauseExternalAudio()
        sut.pauseExternalAudio()
        sut.pauseExternalAudio()
    }

    // MARK: - Phase 2 Stub — resumeExternalAudio

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
