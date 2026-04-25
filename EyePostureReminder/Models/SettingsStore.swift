import Combine
import Foundation
import os

/// `UserDefaults`-backed observable store for all user-configurable settings.
///
/// `@Published` properties drive SwiftUI reactivity. The initialiser accepts a
/// `SettingsPersisting` dependency so unit tests can inject an in-memory store
/// without touching the file system.
///
/// Key layout (all prefixed `epr.`):
/// ```
/// epr.globalEnabled          Bool   – global on/off toggle
/// epr.eyes.enabled           Bool
/// epr.eyes.interval          Double – seconds
/// epr.eyes.breakDuration     Double – seconds
/// epr.posture.enabled        Bool
/// epr.posture.interval       Double – seconds
/// epr.posture.breakDuration  Double – seconds
/// epr.snoozedUntil           Double – Date.timeIntervalSince1970, 0 = not snoozed
/// epr.snoozeCount            Int    – consecutive snoozes since last reminder fired
/// epr.pauseMediaDuringBreaks Bool   – Phase 2, default false
/// epr.pauseDuringFocus       Bool   – pause reminders while a Focus mode is active, default true
/// epr.pauseWhileDriving      Bool   – pause reminders while driving or CarPlay is active, default true
/// ```
final class SettingsStore: ObservableObject {

    // MARK: - Global Toggle

    @Published var globalEnabled: Bool {
        didSet { store.set(globalEnabled, forKey: Keys.globalEnabled) }
    }

    // MARK: - Per-Type Toggles

    @Published var eyesEnabled: Bool {
        didSet { store.set(eyesEnabled, forKey: Keys.eyesEnabled) }
    }

    @Published var postureEnabled: Bool {
        didSet { store.set(postureEnabled, forKey: Keys.postureEnabled) }
    }

    // MARK: - Per-Type Intervals (seconds)

    @Published var eyesInterval: TimeInterval {
        didSet { store.set(eyesInterval, forKey: Keys.eyesInterval) }
    }

    @Published var postureInterval: TimeInterval {
        didSet { store.set(postureInterval, forKey: Keys.postureInterval) }
    }

    // MARK: - Per-Type Break Durations (seconds)

    @Published var eyesBreakDuration: TimeInterval {
        didSet { store.set(eyesBreakDuration, forKey: Keys.eyesBreakDuration) }
    }

    @Published var postureBreakDuration: TimeInterval {
        didSet { store.set(postureBreakDuration, forKey: Keys.postureBreakDuration) }
    }

    // MARK: - Snooze

    /// `nil` when not snoozed; a future `Date` when snoozed until that moment.
    @Published var snoozedUntil: Date? {
        didSet {
            let value = snoozedUntil?.timeIntervalSince1970 ?? 0
            store.set(value, forKey: Keys.snoozedUntil)
        }
    }

    /// Number of consecutive snoozes applied since the last reminder actually fired.
    /// Reset to 0 whenever a real reminder overlay is shown.
    @Published var snoozeCount: Int {
        didSet { store.set(snoozeCount, forKey: Keys.snoozeCount) }
    }

    // MARK: - Pause Conditions

    /// When `true`, pauses reminders while a Focus mode is active.
    /// Default is `true`. Requires `NSFocusStatusUsageDescription` in Info.plist.
    @Published var pauseDuringFocus: Bool {
        didSet { store.set(pauseDuringFocus, forKey: Keys.pauseDuringFocus) }
    }

    /// When `true`, pauses reminders while driving or CarPlay is connected.
    /// Covers both `CMMotionActivity.automotive` and `AVAudioSession.Port.carPlay`.
    /// Default is `true`. Requires `NSMotionUsageDescription` in Info.plist.
    @Published var pauseWhileDriving: Bool {
        didSet { store.set(pauseWhileDriving, forKey: Keys.pauseWhileDriving) }
    }

    // MARK: - Phase 2

    /// When `true`, activates `AVAudioSession` on overlay show to interrupt
    /// other apps' audio. Default is `false`. Phase 2 feature.
    @Published var pauseMediaDuringBreaks: Bool {
        didSet { store.set(pauseMediaDuringBreaks, forKey: Keys.pauseMediaDuringBreaks) }
    }

    /// When `true`, plays haptic feedback on overlay events (appear, dismiss,
    /// countdown completion). Respects device silent mode automatically.
    /// Default is `true`. Phase 2 feature.
    @Published var hapticsEnabled: Bool {
        didSet { store.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    // MARK: - Convenience Accessors

    /// Returns `ReminderSettings` for a given `ReminderType`.
    func settings(for type: ReminderType) -> ReminderSettings {
        switch type {
        case .eyes:
            return ReminderSettings(interval: eyesInterval, breakDuration: eyesBreakDuration)
        case .posture:
            return ReminderSettings(interval: postureInterval, breakDuration: postureBreakDuration)
        }
    }

    /// Returns whether a given type is enabled (master toggle AND per-type toggle).
    func isEnabled(for type: ReminderType) -> Bool {
        guard globalEnabled else { return false }
        switch type {
        case .eyes:    return eyesEnabled
        case .posture: return postureEnabled
        }
    }

    // MARK: - Init

    private let store: SettingsPersisting

    init(store: SettingsPersisting = UserDefaults.standard, config: AppConfig = AppConfig.load()) {
        self.store = store

        globalEnabled       = store.bool(forKey: Keys.globalEnabled, defaultValue: config.features.globalEnabledDefault)
        eyesEnabled         = store.bool(forKey: Keys.eyesEnabled, defaultValue: true)
        postureEnabled      = store.bool(forKey: Keys.postureEnabled, defaultValue: true)

        eyesInterval        = store.double(forKey: Keys.eyesInterval, defaultValue: config.defaults.eyeInterval)
        eyesBreakDuration   = store.double(
            forKey: Keys.eyesBreakDuration, defaultValue: config.defaults.eyeBreakDuration)
        postureInterval     = store.double(forKey: Keys.postureInterval, defaultValue: config.defaults.postureInterval)
        postureBreakDuration = store.double(
            forKey: Keys.postureBreakDuration, defaultValue: config.defaults.postureBreakDuration)

        let rawSnooze = store.double(forKey: Keys.snoozedUntil, defaultValue: 0)
        snoozedUntil = rawSnooze > 0 ? Date(timeIntervalSince1970: rawSnooze) : nil

        snoozeCount = store.integer(forKey: Keys.snoozeCount, defaultValue: 0)

        pauseMediaDuringBreaks = store.bool(forKey: Keys.pauseMediaDuringBreaks, defaultValue: false)
        hapticsEnabled         = store.bool(forKey: Keys.hapticsEnabled, defaultValue: true)
        pauseDuringFocus       = store.bool(forKey: Keys.pauseDuringFocus, defaultValue: true)
        pauseWhileDriving      = store.bool(forKey: Keys.pauseWhileDriving, defaultValue: true)

        Logger.settings.debug("SettingsStore initialised")
    }
}

// MARK: - Keys

private extension SettingsStore {
    enum Keys {
        static let globalEnabled          = "epr.globalEnabled"
        static let eyesEnabled            = "epr.eyes.enabled"
        static let eyesInterval           = "epr.eyes.interval"
        static let eyesBreakDuration      = "epr.eyes.breakDuration"
        static let postureEnabled         = "epr.posture.enabled"
        static let postureInterval        = "epr.posture.interval"
        static let postureBreakDuration   = "epr.posture.breakDuration"
        static let snoozedUntil           = "epr.snoozedUntil"
        static let snoozeCount            = "epr.snoozeCount"
        static let pauseMediaDuringBreaks = "epr.pauseMediaDuringBreaks"
        static let hapticsEnabled         = "epr.hapticsEnabled"
        static let pauseDuringFocus       = "epr.pauseDuringFocus"
        static let pauseWhileDriving      = "epr.pauseWhileDriving"
    }
}

// MARK: - SettingsPersisting Protocol

/// Abstracts `UserDefaults` for testability. Provides typed accessors with
/// explicit `defaultValue` parameters so callers never rely on Foundation's
/// implicit zero/false returns.
protocol SettingsPersisting {
    func bool(forKey key: String, defaultValue: Bool) -> Bool
    func set(_ value: Bool, forKey key: String)

    func double(forKey key: String, defaultValue: Double) -> Double
    func set(_ value: Double, forKey key: String)

    func integer(forKey key: String, defaultValue: Int) -> Int
    func set(_ value: Int, forKey key: String)
}

// MARK: - UserDefaults Conformance

extension UserDefaults: SettingsPersisting {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        guard object(forKey: key) != nil else { return defaultValue }
        return bool(forKey: key)
    }

    func double(forKey key: String, defaultValue: Double) -> Double {
        guard object(forKey: key) != nil else { return defaultValue }
        return double(forKey: key)
    }

    func integer(forKey key: String, defaultValue: Int) -> Int {
        guard object(forKey: key) != nil else { return defaultValue }
        return integer(forKey: key)
    }
}
