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

protocol AudioSessionControlling: AnyObject {
    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

extension AVAudioSession: AudioSessionControlling {}

typealias AudioSessionFactory = () -> AudioSessionControlling

// MARK: - AudioInterruptionManager

/// Concrete `MediaControlling` implementation.
///
/// Uses `.soloAmbient` — the system default category that respects the silent
/// switch and interrupts other apps' audio (Spotify, Podcasts, etc.) when
/// the session becomes active. No audio is played by this app, so there is
/// no Control Center "now playing" entry and no `UIBackgroundModes: audio`
/// entitlement is needed.
final class AudioInterruptionManager: MediaControlling {
    private let audioSession: AudioSessionControlling

    /// Creates an audio-interruption manager bound to a specific audio session.
    ///
    /// - Parameters:
    ///   - audioSession: Pre-built session used directly when supplied (test seam).
    ///   - makeAudioSession: Factory invoked only when `audioSession` is `nil`;
    ///     defaults to `AVAudioSession.sharedInstance()` for production use.
    init(
        audioSession: AudioSessionControlling? = nil,
        makeAudioSession: @escaping AudioSessionFactory = { AVAudioSession.sharedInstance() }
    ) {
        self.audioSession = audioSession ?? makeAudioSession()
    }

    // MARK: - MediaControlling

    /// Activates `AVAudioSession` with the `.soloAmbient` category to interrupt other apps' audio.
    ///
    /// Called immediately before an overlay appears. Failures are logged but
    /// non-fatal — the overlay still presents, and `resumeExternalAudio()` remains
    /// safe to call on dismissal because deactivating an inactive session is a no-op.
    func pauseExternalAudio() {
        do {
            try audioSession.setCategory(.soloAmbient, mode: .default, options: [])
            try audioSession.setActive(true, options: [])
            Logger.overlay.debug("AudioInterruptionManager: external audio paused")
        } catch {
            // If `setActive(true)` throws (e.g., audio session stolen by a phone
            // call), log the error but continue. `resumeExternalAudio()` will still
            // call `setActive(false)` on dismiss — calling setActive(false) on an
            // already-inactive session is a no-op, so dismissal is always safe.
            Logger.overlay.error(
                """
                AudioInterruptionManager.pauseExternalAudio failed: \
                \(error.localizedDescription, privacy: .public) — overlay shown without audio interruption
                """
            )
        }
    }

    /// Deactivates `AVAudioSession` and notifies other apps to resume playback.
    ///
    /// Must be called from every overlay dismiss path to release the audio
    /// interruption. Uses `.notifyOthersOnDeactivation` so apps such as
    /// Spotify or Podcasts resume automatically. Failures are logged and
    /// otherwise ignored.
    func resumeExternalAudio() {
        do {
            // .notifyOthersOnDeactivation lets Spotify / Podcasts / etc. resume automatically.
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            Logger.overlay.debug("AudioInterruptionManager: external audio resumed")
        } catch {
            Logger.overlay.error("""
                AudioInterruptionManager.resumeExternalAudio failed: \
                \(error.localizedDescription, privacy: .public)
                """)
        }
    }
}
