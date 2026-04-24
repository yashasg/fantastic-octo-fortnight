import AVFoundation
import os

// MARK: - MediaControlling Protocol

/// Abstracts audio session interruption for testability and Phase 2 isolation.
///
/// **Phase 2 feature.** The concrete implementation activates `AVAudioSession`
/// without `.mixWithOthers` to interrupt other apps' audio when an overlay is
/// shown. The session is deactivated with `.notifyOthersOnDeactivation` in ALL
/// dismiss paths — this is the single most critical invariant.
///
/// **What to never do:**
/// - Never add `UIBackgroundModes: audio` — App Review rejects apps that don't
///   actually play audio.
/// - Never set `MPNowPlayingInfoCenter.nowPlayingInfo` — creates a phantom
///   Control Center entry the user cannot dismiss.
/// - Never hold the audio session open between reminders — activate on show,
///   deactivate on dismiss, every time.
protocol MediaControlling: AnyObject {
    /// Activate `AVAudioSession` to interrupt other apps' audio.
    /// Called immediately before the overlay appears.
    func pauseExternalAudio()

    /// Deactivate `AVAudioSession` and notify other apps to resume.
    /// Must be called in every overlay dismiss path.
    func resumeExternalAudio()
}

// MARK: - AudioInterruptionManager

/// Concrete `MediaControlling` implementation.
///
/// Phase 2 body is intentionally empty — the protocol contract is what matters
/// for Phase 1 compilation. Implementation lands in the Phase 2 milestone.
final class AudioInterruptionManager: MediaControlling {

    // MARK: - MediaControlling

    func pauseExternalAudio() {
        // Phase 2: Activate AVAudioSession(.ambient or .playback without .mixWithOthers)
        // to interrupt other apps' audio. Example:
        //
        //   let session = AVAudioSession.sharedInstance()
        //   try? session.setCategory(.playback, options: [])
        //   try? session.setActive(true)
        //
        Logger.overlay.debug("AudioInterruptionManager.pauseExternalAudio — Phase 2 not yet implemented")
    }

    func resumeExternalAudio() {
        // Phase 2: Deactivate session and notify others.
        // CRITICAL: .notifyOthersOnDeactivation must always be set here.
        //
        //   let session = AVAudioSession.sharedInstance()
        //   try? session.setActive(false, options: .notifyOthersOnDeactivation)
        //
        Logger.overlay.debug("AudioInterruptionManager.resumeExternalAudio — Phase 2 not yet implemented")
    }
}
