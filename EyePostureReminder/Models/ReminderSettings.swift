import Foundation

/// Immutable value type holding the schedule parameters for a single reminder type.
///
/// Both `interval` and `breakDuration` are expressed in seconds so they map
/// directly onto `TimeInterval` arithmetic in `ReminderScheduler`.
///
/// `hapticsEnabled` and `pauseMediaDuringBreaks` are global overlay-presentation
/// flags that ride along on the snapshot so `SchedulingFeature` can forward
/// them to `OverlayClient.show` without a second `SettingsClient` round-trip
/// (#899). Both default to `false` so the pre-#899 behaviour — the reducer
/// passing `false` literals — is preserved for the zero-seeded snapshot used
/// by `ReminderSettings(interval: 0, breakDuration: 0)` placeholders in
/// caches and `TestStore` initial state.
struct ReminderSettings: Equatable {
    /// Time between reminders (seconds). e.g. 1200 = every 20 minutes.
    let interval: TimeInterval

    /// How long the break overlay is shown (seconds). e.g. 20 = 20-second eye break.
    let breakDuration: TimeInterval

    /// Whether haptic feedback is played on overlay events (appear, dismiss,
    /// countdown completion). Mirrors `SettingsStore.hapticsEnabled`.
    let hapticsEnabled: Bool

    /// Whether the overlay should activate `AVAudioSession` on show to
    /// interrupt other apps' audio. Mirrors
    /// `SettingsStore.pauseMediaDuringBreaks`.
    let pauseMediaDuringBreaks: Bool

    init(
        interval: TimeInterval,
        breakDuration: TimeInterval,
        hapticsEnabled: Bool = false,
        pauseMediaDuringBreaks: Bool = false
    ) {
        self.interval = interval
        self.breakDuration = breakDuration
        self.hapticsEnabled = hapticsEnabled
        self.pauseMediaDuringBreaks = pauseMediaDuringBreaks
    }
}

// MARK: - Defaults

extension ReminderSettings {
    /// 20-20-20 rule defaults driven by `AppConfig` (reads `defaults.json`).
    /// `static let` ensures `AppConfig.load()` is called at most once.
    ///
    /// `hapticsEnabled: true` mirrors `SettingsStore.init`'s persisted default
    /// for `kshana.hapticsEnabled`; `pauseMediaDuringBreaks` keeps the struct
    /// default (`false`), matching `SettingsStore.init`'s persisted default
    /// for `kshana.pauseMediaDuringBreaks` (#899).
    static let defaultEyes: ReminderSettings = {
        let config = AppConfig.load()
        return ReminderSettings(
            interval: config.defaults.eyeInterval,
            breakDuration: config.defaults.eyeBreakDuration,
            hapticsEnabled: true
        )
    }()

    /// Posture check defaults driven by `AppConfig` (reads `defaults.json`).
    /// `static let` ensures `AppConfig.load()` is called at most once.
    ///
    /// `hapticsEnabled: true` mirrors `SettingsStore.init`'s persisted default
    /// (#899).
    static let defaultPosture: ReminderSettings = {
        let config = AppConfig.load()
        return ReminderSettings(
            interval: config.defaults.postureInterval,
            breakDuration: config.defaults.postureBreakDuration,
            hapticsEnabled: true
        )
    }()
}
