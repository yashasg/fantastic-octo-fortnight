import Combine
import Foundation
import os

/// `UserDefaults`-backed observable store for all user-configurable settings.
///
/// `@Published` properties drive SwiftUI reactivity. The initialiser accepts a
/// `SettingsPersisting` dependency so unit tests can inject an in-memory store
/// without touching the file system.
///
/// Key layout (all prefixed `kshana.`):
/// ```
/// kshana.globalEnabled                  Bool   – global on/off toggle
/// kshana.eyes.enabled                   Bool
/// kshana.eyes.interval                  Double – seconds
/// kshana.eyes.breakDuration             Double – seconds
/// kshana.posture.enabled                Bool
/// kshana.posture.interval               Double – seconds
/// kshana.posture.breakDuration          Double – seconds
/// kshana.snoozedUntil                   Double – Date.timeIntervalSince1970, 0 = not snoozed
/// kshana.snoozeCount                    Int    – consecutive snoozes since last reminder fired
/// kshana.pauseMediaDuringBreaks         Bool   – default false
/// kshana.hapticsEnabled                 Bool   – default true
/// kshana.pauseDuringFocus               Bool   – default true
/// kshana.pauseWhileDriving              Bool   – default true
/// kshana.notificationFallbackEnabled    Bool   – default true
/// ```
@MainActor
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

    @Published private var eyesBreakDurationStorage: TimeInterval
    @Published private var postureBreakDurationStorage: TimeInterval

    var eyesBreakDuration: TimeInterval {
        get { eyesBreakDurationStorage }
        set {
            let validated = Self.validBreakDurationForAssignment(
                newValue,
                previousValue: eyesBreakDurationStorage,
                fallbackValue: AppConfig.fallback.defaults.eyeBreakDuration,
                key: Keys.eyesBreakDuration
            )
            eyesBreakDurationStorage = validated
            store.set(validated, forKey: Keys.eyesBreakDuration)
        }
    }

    var postureBreakDuration: TimeInterval {
        get { postureBreakDurationStorage }
        set {
            let validated = Self.validBreakDurationForAssignment(
                newValue,
                previousValue: postureBreakDurationStorage,
                fallbackValue: AppConfig.fallback.defaults.postureBreakDuration,
                key: Keys.postureBreakDuration
            )
            postureBreakDurationStorage = validated
            store.set(validated, forKey: Keys.postureBreakDuration)
        }
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

    /// When `true`, schedules local notifications only as a backup path while
    /// Screen Time shielding is unavailable. Default is `true`.
    @Published var notificationFallbackEnabled: Bool {
        didSet { store.set(notificationFallbackEnabled, forKey: Keys.notificationFallbackEnabled) }
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
    private let makeConfig: AppConfigFactory

    typealias SettingsStoreFactory = () -> SettingsPersisting
    typealias AppConfigFactory = () -> AppConfig

    init(
        store: SettingsPersisting? = nil,
        makeStore: @escaping SettingsStoreFactory = { UserDefaults.standard },
        config: AppConfig? = nil,
        makeConfig: @escaping AppConfigFactory = { AppConfig.load() }
    ) {
        let resolvedStore = store ?? makeStore()
        let resolvedConfigFactory: AppConfigFactory = {
            if let config {
                return config
            }
            return makeConfig()
        }
        let resolvedConfig = resolvedConfigFactory()
        self.store = resolvedStore
        self.makeConfig = resolvedConfigFactory
        let defaultEyesBreakDuration = Self.sanitizedBreakDuration(
            resolvedConfig.defaults.eyeBreakDuration,
            defaultValue: AppConfig.fallback.defaults.eyeBreakDuration,
            key: Keys.eyesBreakDuration
        )
        let defaultPostureBreakDuration = Self.sanitizedBreakDuration(
            resolvedConfig.defaults.postureBreakDuration,
            defaultValue: AppConfig.fallback.defaults.postureBreakDuration,
            key: Keys.postureBreakDuration
        )

        globalEnabled = resolvedStore.bool(
            forKey: Keys.globalEnabled,
            defaultValue: resolvedConfig.features.globalEnabledDefault
        )
        eyesEnabled = resolvedStore.bool(forKey: Keys.eyesEnabled, defaultValue: true)
        postureEnabled = resolvedStore.bool(forKey: Keys.postureEnabled, defaultValue: true)

        eyesInterval = resolvedStore.double(
            forKey: Keys.eyesInterval,
            defaultValue: resolvedConfig.defaults.eyeInterval
        )
        eyesBreakDurationStorage = Self.sanitizedBreakDuration(
            resolvedStore.double(forKey: Keys.eyesBreakDuration, defaultValue: defaultEyesBreakDuration),
            defaultValue: defaultEyesBreakDuration,
            key: Keys.eyesBreakDuration
        )
        postureInterval = resolvedStore.double(
            forKey: Keys.postureInterval,
            defaultValue: resolvedConfig.defaults.postureInterval
        )
        postureBreakDurationStorage = Self.sanitizedBreakDuration(
            resolvedStore.double(forKey: Keys.postureBreakDuration, defaultValue: defaultPostureBreakDuration),
            defaultValue: defaultPostureBreakDuration,
            key: Keys.postureBreakDuration
        )

        let rawSnooze = resolvedStore.double(forKey: Keys.snoozedUntil, defaultValue: 0)
        snoozedUntil = rawSnooze > 0 ? Date(timeIntervalSince1970: rawSnooze) : nil

        snoozeCount = resolvedStore.integer(forKey: Keys.snoozeCount, defaultValue: 0)

        pauseMediaDuringBreaks = resolvedStore.bool(forKey: Keys.pauseMediaDuringBreaks, defaultValue: false)
        hapticsEnabled = resolvedStore.bool(forKey: Keys.hapticsEnabled, defaultValue: true)
        pauseDuringFocus = resolvedStore.bool(forKey: Keys.pauseDuringFocus, defaultValue: true)
        pauseWhileDriving = resolvedStore.bool(forKey: Keys.pauseWhileDriving, defaultValue: true)
        notificationFallbackEnabled = resolvedStore.bool(
            forKey: Keys.notificationFallbackEnabled,
            defaultValue: true
        )

        Logger.settings.debug("SettingsStore initialised")
    }

    // MARK: - Reset to Defaults

    /// Restores all user-configurable settings to the values specified in `defaults.json`.
    func resetToDefaults(config: AppConfig? = nil) {
        let resolvedConfig = config ?? makeConfig()
        globalEnabled = resolvedConfig.features.globalEnabledDefault
        eyesEnabled = true
        postureEnabled = true
        eyesInterval = resolvedConfig.defaults.eyeInterval
        eyesBreakDuration = Self.sanitizedBreakDuration(
            resolvedConfig.defaults.eyeBreakDuration,
            defaultValue: AppConfig.fallback.defaults.eyeBreakDuration,
            key: Keys.eyesBreakDuration
        )
        postureInterval = resolvedConfig.defaults.postureInterval
        postureBreakDuration = Self.sanitizedBreakDuration(
            resolvedConfig.defaults.postureBreakDuration,
            defaultValue: AppConfig.fallback.defaults.postureBreakDuration,
            key: Keys.postureBreakDuration
        )
        hapticsEnabled = true
        pauseMediaDuringBreaks = false
        pauseDuringFocus = true
        pauseWhileDriving = true
        notificationFallbackEnabled = true
        snoozedUntil = nil
        snoozeCount = 0
        // Clear the True Interrupt banner dismissal so the rediscovery affordance reappears.
        store.set(false, forKey: AppStorageKey.trueInterruptSkippedBannerDismissed)
        Logger.settings.debug("SettingsStore reset to defaults")
    }

    private static func sanitizedBreakDuration(
        _ duration: TimeInterval,
        defaultValue: TimeInterval,
        key: String
    ) -> TimeInterval {
        guard ShieldSession.isValidDurationSeconds(duration) else {
            Logger.settings.error("Invalid break duration for \(key, privacy: .public); using default")
            guard ShieldSession.isValidDurationSeconds(defaultValue) else {
                Logger.settings.error("Invalid break duration default for \(key, privacy: .public); using fallback")
                return hardcodedBreakDurationFallback(for: key)
            }
            return defaultValue
        }
        return duration
    }

    private static func validBreakDurationForAssignment(
        _ duration: TimeInterval,
        previousValue: TimeInterval,
        fallbackValue: TimeInterval,
        key: String
    ) -> TimeInterval {
        guard ShieldSession.isValidDurationSeconds(duration) else {
            Logger.settings.error("Rejected invalid break duration assignment for \(key, privacy: .public)")
            return sanitizedBreakDuration(previousValue, defaultValue: fallbackValue, key: key)
        }
        return duration
    }

    private static func hardcodedBreakDurationFallback(for key: String) -> TimeInterval {
        let fallback: TimeInterval
        switch key {
        case Keys.eyesBreakDuration:
            fallback = 20
        case Keys.postureBreakDuration:
            fallback = 10
        default:
            preconditionFailure("Unknown break duration key: \(key)")
        }

        precondition(
            ShieldSession.isValidDurationSeconds(fallback),
            "Hardcoded break duration fallback must be positive and finite"
        )
        return fallback
    }
}

// MARK: - Keys

extension SettingsStore {
    /// `UserDefaults` key namespace for every persisted `SettingsStore`
    /// property. Exposed at module scope (not `private`) so non-`@MainActor`
    /// callers — for example the `EyePostureReminderApp.init` synchronous
    /// settings seed (#737) — can read the same canonical keys without
    /// duplicating string literals that would silently drift on rename.
    enum Keys {
        static let globalEnabled          = "kshana.globalEnabled"
        static let eyesEnabled            = "kshana.eyes.enabled"
        static let eyesInterval           = "kshana.eyes.interval"
        static let eyesBreakDuration      = "kshana.eyes.breakDuration"
        static let postureEnabled         = "kshana.posture.enabled"
        static let postureInterval        = "kshana.posture.interval"
        static let postureBreakDuration   = "kshana.posture.breakDuration"
        static let snoozedUntil           = "kshana.snoozedUntil"
        static let snoozeCount            = "kshana.snoozeCount"
        static let pauseMediaDuringBreaks = "kshana.pauseMediaDuringBreaks"
        static let hapticsEnabled         = "kshana.hapticsEnabled"
        static let pauseDuringFocus       = "kshana.pauseDuringFocus"
        static let pauseWhileDriving      = "kshana.pauseWhileDriving"
        static let notificationFallbackEnabled = "kshana.notificationFallbackEnabled"
    }
}

// MARK: - Synchronous Seed (#737)

extension SettingsStore {
    /// Synchronous, non-actor-isolated read of the persisted eyes-side
    /// `ReminderSettings` directly from the supplied `UserDefaults`.
    ///
    /// `EyePostureReminderApp.init()` calls this to seed the TCA root
    /// `state.scheduling.settings` *before* `SchedulingFeature.start` runs,
    /// closing the settings-load race that previously left
    /// `reminderNotificationEffect` reading `breakDuration: 0` and showing
    /// auto-dismissing overlays during the UI-test backdoor (#737).
    ///
    /// Falls back to `ReminderSettings.defaultEyes` for any key not yet
    /// persisted (first cold launch after install). Per the docstring at the
    /// top of `SchedulingFeature` the eyes-side snapshot is shared by both
    /// reminder types until per-type settings land.
    ///
    /// Follow-up (#737): retire this helper once `SettingsClient.liveValue`
    /// exposes a synchronous initial-value accessor that the AppFeature root
    /// reducer can read at construction time without bouncing to the main
    /// actor.
    nonisolated static func eyesSnapshotFromUserDefaults(
        _ defaults: UserDefaults = .standard
    ) -> ReminderSettings {
        let fallback = ReminderSettings.defaultEyes
        let interval = defaults.object(forKey: Keys.eyesInterval) != nil
            ? defaults.double(forKey: Keys.eyesInterval)
            : fallback.interval
        let breakDuration = defaults.object(forKey: Keys.eyesBreakDuration) != nil
            ? defaults.double(forKey: Keys.eyesBreakDuration)
            : fallback.breakDuration
        return ReminderSettings(interval: interval, breakDuration: breakDuration)
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
