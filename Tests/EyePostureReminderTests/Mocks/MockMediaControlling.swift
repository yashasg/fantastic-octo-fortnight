import Foundation
@testable import EyePostureReminder

/// Mock implementation of `MediaControlling` for unit tests.
///
/// Records every `pauseExternalAudio` and `resumeExternalAudio` call so tests
/// can assert correct audio-session lifecycle without touching `AVAudioSession`.
final class MockMediaControlling: MediaControlling {

    // MARK: - Call Counts

    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0

    // MARK: - Reset

    func reset() {
        pauseCallCount = 0
        resumeCallCount = 0
    }

    // MARK: - MediaControlling

    func pauseExternalAudio() {
        pauseCallCount += 1
    }

    func resumeExternalAudio() {
        resumeCallCount += 1
    }
}
