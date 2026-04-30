import AVFoundation
import os

// MARK: - MediaControlling Protocol

/// Abstracts audio session interruption for testability.
///
/// The concrete implementation activates `AVAudioSession` using the
/// `.soloAmbient` category to interrupt other apps' audio when an overlay is
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
/// Uses `.soloAmbient` — the system default category that respects the silent
/// switch and interrupts other apps' audio (Spotify, Podcasts, etc.) when
/// the session becomes active. No audio is played by this app, so there is
/// no Control Center "now playing" entry and no `UIBackgroundModes: audio`
/// entitlement is needed.
final class AudioInterruptionManager: MediaControlling {

    // MARK: - MediaControlling

    func pauseExternalAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.soloAmbient)
            try session.setActive(true)
            Logger.overlay.debug("AudioInterruptionManager: external audio paused")
        } catch {
            // If `setActive(true)` throws (e.g., audio session stolen by a phone
            // call), log the error but continue. `resumeExternalAudio()` will still
            // call `setActive(false)` on dismiss — calling setActive(false) on an
            // already-inactive session is a no-op, so dismissal is always safe.
            // System API error — localizedDescription comes from AVAudioSession/AVFoundation domain, not user input.
            Logger.overlay.error(
                """
                AudioInterruptionManager.pauseExternalAudio failed: \
                \(error.localizedDescription, privacy: .public) — overlay shown without audio interruption
                """
            )
        }
    }

    func resumeExternalAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .notifyOthersOnDeactivation lets Spotify / Podcasts / etc. resume automatically.
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            Logger.overlay.debug("AudioInterruptionManager: external audio resumed")
        } catch {
            // System API error — localizedDescription comes from AVAudioSession/AVFoundation domain, not user input.
            Logger.overlay.error("AudioInterruptionManager.resumeExternalAudio failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
