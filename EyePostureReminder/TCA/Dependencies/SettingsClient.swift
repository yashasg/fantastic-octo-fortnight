import ComposableArchitecture
import Foundation

/// Snapshot of the three persisted enable-flag keys
/// (`globalEnabled` / `eyesEnabled` / `postureEnabled`).
///
/// Vended by `SettingsClient.enabledFlagsSnapshot` /
/// `enabledFlagsStream` so reducers (notably `HomeFeature`) stay in lock-step
/// with master-toggle changes made from `SettingsView` — including the writes
/// `SettingsView` makes directly via `@AppStorage` bindings, which bypass the
/// `SettingsStore` setters and therefore do not fire the existing
/// `SettingsStore` observer surface. See #785.
struct EnabledFlags: Sendable, Equatable {
    var global: Bool
    var eyes: Bool
    var posture: Bool

    /// All-on default used as the cold-start seed and the `liveValue`
    /// fallback before `LiveSettingsBridge.bootstrap()` runs.
    static let allEnabled = EnabledFlags(global: true, eyes: true, posture: true)
}

/// TCA dependency client wrapping `SettingsStore` for reducer consumption.
///
/// Phase 0 of the MVVM → TCA migration (#665). The closure surface is the
/// normative contract Phase 1 reducers will copy verbatim. The `liveValue`
/// adapter routes every getter and setter through the existing `@MainActor`
/// `SettingsStore` so both worlds coexist during the migration.
@DependencyClient
struct SettingsClient: Sendable {
    /// Synchronous snapshot of the latest published `ReminderSettings` for the
    /// eyes side. The live adapter caches the most recent value so reducers
    /// can read it without hopping to the main actor.
    var snapshot: @Sendable () -> ReminderSettings = {
        ReminderSettings(interval: 0, breakDuration: 0)
    }

    /// Multicast stream of `ReminderSettings` snapshots. A new subscriber
    /// receives the current snapshot and every subsequent change.
    var stream: @Sendable () -> AsyncStream<ReminderSettings> = { .finished }

    /// Synchronous snapshot of the persisted enable-flag triplet. Cached on
    /// the file-scope `enabledFlagsCache` so reducers can read it off the
    /// main actor. See #785 for why this is separate from `snapshot()`.
    var enabledFlagsSnapshot: @Sendable () -> EnabledFlags = { .allEnabled }

    /// Multicast stream of `EnabledFlags` snapshots. A new subscriber
    /// receives the current snapshot synchronously and every subsequent
    /// change — including writes that bypass `SettingsStore` setters (e.g.
    /// `SettingsView`'s `@AppStorage` master-toggle binding). See #785.
    var enabledFlagsStream: @Sendable () -> AsyncStream<EnabledFlags> = { .finished }

    /// Toggles the global reminders master switch.
    var updateGlobalEnabled: @Sendable (Bool) async -> Void

    /// Toggles the eyes reminder type.
    var updateEyesEnabled: @Sendable (Bool) async -> Void

    /// Toggles the posture reminder type.
    var updatePostureEnabled: @Sendable (Bool) async -> Void

    /// Updates the eyes reminder interval, in seconds.
    var updateEyesInterval: @Sendable (TimeInterval) async -> Void

    /// Updates the posture reminder interval, in seconds.
    var updatePostureInterval: @Sendable (TimeInterval) async -> Void

    /// Updates the eyes break duration, in seconds.
    var updateEyesBreakDuration: @Sendable (TimeInterval) async -> Void

    /// Updates the posture break duration, in seconds.
    var updatePostureBreakDuration: @Sendable (TimeInterval) async -> Void

    /// Toggles the "pause media during breaks" feature.
    var updatePauseMediaDuringBreaks: @Sendable (Bool) async -> Void

    /// Toggles haptics on overlay events.
    var updateHapticsEnabled: @Sendable (Bool) async -> Void

    /// Toggles "pause during Focus mode".
    var updatePauseDuringFocus: @Sendable (Bool) async -> Void

    /// Toggles "pause while driving".
    var updatePauseWhileDriving: @Sendable (Bool) async -> Void

    /// Toggles the notification fallback path.
    var updateNotificationFallbackEnabled: @Sendable (Bool) async -> Void

    /// Sets the snoozed-until date, or clears snooze when `nil`.
    var setSnoozedUntil: @Sendable (Date?) async -> Void

    /// Sets the consecutive snooze count.
    var setSnoozeCount: @Sendable (Int) async -> Void

    /// Restores all settings to the bundled defaults.
    var resetToDefaults: @Sendable () async -> Void
}

extension SettingsClient: DependencyKey {
    static let liveValue: SettingsClient = {
        Task { @MainActor in LiveSettingsBridge.shared.bootstrap() }
        return SettingsClient(
            snapshot: { settingsSnapshotCache.value },
            stream: { makeSettingsStream() },
            enabledFlagsSnapshot: { enabledFlagsCache.value },
            enabledFlagsStream: { makeEnabledFlagsStream() },
            updateGlobalEnabled: { value in
                await MainActor.run { LiveSettingsBridge.shared.store.globalEnabled = value }
            },
            updateEyesEnabled: { value in
                await MainActor.run { LiveSettingsBridge.shared.store.eyesEnabled = value }
            },
            updatePostureEnabled: { value in
                await MainActor.run { LiveSettingsBridge.shared.store.postureEnabled = value }
            },
            updateEyesInterval: { value in
                await MainActor.run { LiveSettingsBridge.shared.store.eyesInterval = value }
            },
            updatePostureInterval: { value in
                await MainActor.run { LiveSettingsBridge.shared.store.postureInterval = value }
            },
            updateEyesBreakDuration: { value in
                await MainActor.run { LiveSettingsBridge.shared.store.eyesBreakDuration = value }
            },
            updatePostureBreakDuration: { value in
                await MainActor.run {
                    LiveSettingsBridge.shared.store.postureBreakDuration = value
                }
            },
            updatePauseMediaDuringBreaks: { value in
                await MainActor.run {
                    LiveSettingsBridge.shared.store.pauseMediaDuringBreaks = value
                }
            },
            updateHapticsEnabled: { value in
                await MainActor.run { LiveSettingsBridge.shared.store.hapticsEnabled = value }
            },
            updatePauseDuringFocus: { value in
                await MainActor.run { LiveSettingsBridge.shared.store.pauseDuringFocus = value }
            },
            updatePauseWhileDriving: { value in
                await MainActor.run { LiveSettingsBridge.shared.store.pauseWhileDriving = value }
            },
            updateNotificationFallbackEnabled: { value in
                await MainActor.run {
                    LiveSettingsBridge.shared.store.notificationFallbackEnabled = value
                }
            },
            setSnoozedUntil: { value in
                await MainActor.run { LiveSettingsBridge.shared.store.snoozedUntil = value }
            },
            setSnoozeCount: { value in
                await MainActor.run { LiveSettingsBridge.shared.store.snoozeCount = value }
            },
            resetToDefaults: {
                await MainActor.run { LiveSettingsBridge.shared.store.resetToDefaults() }
            }
        )
    }()
}

extension DependencyValues {
    /// TCA accessor for the shared `SettingsClient`.
    var settingsClient: SettingsClient {
        get { self[SettingsClient.self] }
        set { self[SettingsClient.self] = newValue }
    }
}

/// Main-actor-isolated owner of the live `SettingsStore` plus the observer
/// subscription that mirrors mutations into the file-scope snapshot cache and
/// continuation registry.
@MainActor
private final class LiveSettingsBridge {
    nonisolated static let shared = LiveSettingsBridge()

    let store = SettingsStore()
    private var hasBootstrapped = false
    private var defaultsObservationToken: NSObjectProtocol?

    private nonisolated init() {}

    /// Idempotent bootstrap. Called from `liveValue` via a `@MainActor` task
    /// so the observer subscription is wired exactly once on the main actor.
    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        let initial = store.settings(for: .eyes)
        settingsSnapshotCache.setValue(initial)
        broadcastSettings(initial)

        let initialFlags = EnabledFlags(
            global: store.globalEnabled,
            eyes: store.eyesEnabled,
            posture: store.postureEnabled
        )
        enabledFlagsCache.setValue(initialFlags)
        broadcastEnabledFlags(initialFlags)

        store.addObserver { snapshot in
            settingsSnapshotCache.setValue(snapshot)
            broadcastSettings(snapshot)
        }

        // `SettingsView` writes the master / per-type enable flags directly to
        // `UserDefaults` through `@AppStorage`, which bypasses `SettingsStore`
        // setters and therefore the existing `addObserver` surface. Listen for
        // `UserDefaults.didChangeNotification` so both write paths (store
        // setter and direct `@AppStorage`) keep the file-scope cache and the
        // multicast continuations in sync. See #785.
        defaultsObservationToken = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { _ in
            let defaults = UserDefaults.standard
            let flags = EnabledFlags(
                global: defaults.bool(
                    forKey: SettingsStore.Keys.globalEnabled,
                    defaultValue: true
                ),
                eyes: defaults.bool(
                    forKey: SettingsStore.Keys.eyesEnabled,
                    defaultValue: true
                ),
                posture: defaults.bool(
                    forKey: SettingsStore.Keys.postureEnabled,
                    defaultValue: true
                )
            )
            guard flags != enabledFlagsCache.value else { return }
            enabledFlagsCache.setValue(flags)
            broadcastEnabledFlags(flags)
        }
    }
}

/// File-scoped snapshot cache; safe to read from any actor.
private let settingsSnapshotCache = LockIsolated<ReminderSettings>(
    ReminderSettings(interval: 0, breakDuration: 0)
)

/// File-scoped enable-flag cache; safe to read from any actor. Seeded to
/// `.allEnabled` so reads before `LiveSettingsBridge.bootstrap()` finishes
/// (e.g. during early Phase-2 `state.home.*` initialisation) match the
/// all-on shipping default.
private let enabledFlagsCache = LockIsolated<EnabledFlags>(.allEnabled)

/// File-scoped multicast continuations. Held outside the `@MainActor` bridge
/// to side-step a Swift constraint-solver bug that surfaces when
/// `Continuation.onTermination` captures `@MainActor`-isolated static storage.
private let settingsContinuations =
    LockIsolated<[UUID: AsyncStream<ReminderSettings>.Continuation]>([:])

/// File-scoped multicast continuations for `EnabledFlags` subscribers. Kept
/// alongside `settingsContinuations` for the same `@MainActor` reason.
private let enabledFlagsContinuations =
    LockIsolated<[UUID: AsyncStream<EnabledFlags>.Continuation]>([:])

/// File-scoped factory used by the live `stream` closure to register a new
/// multicast subscriber. Yields the current snapshot synchronously so first
/// reads never block on a settings mutation.
private func makeSettingsStream() -> AsyncStream<ReminderSettings> {
    let (stream, continuation) = AsyncStream<ReminderSettings>.makeStream()
    let id = UUID()
    continuation.yield(settingsSnapshotCache.value)
    settingsContinuations.withValue { $0[id] = continuation }
    continuation.onTermination = { _ in
        settingsContinuations.withValue { dict in
            dict[id] = nil
        }
    }
    return stream
}

/// File-scoped factory used by the live `enabledFlagsStream` closure to
/// register a new multicast subscriber. Yields the current cached flags
/// synchronously so the first emission carries the persisted truth without
/// waiting for the next `UserDefaults` mutation.
private func makeEnabledFlagsStream() -> AsyncStream<EnabledFlags> {
    let (stream, continuation) = AsyncStream<EnabledFlags>.makeStream()
    let id = UUID()
    continuation.yield(enabledFlagsCache.value)
    enabledFlagsContinuations.withValue { $0[id] = continuation }
    continuation.onTermination = { _ in
        enabledFlagsContinuations.withValue { dict in
            dict[id] = nil
        }
    }
    return stream
}

private func broadcastSettings(_ value: ReminderSettings) {
    settingsContinuations.withValue { dict in
        for continuation in dict.values { continuation.yield(value) }
    }
}

private func broadcastEnabledFlags(_ value: EnabledFlags) {
    enabledFlagsContinuations.withValue { dict in
        for continuation in dict.values { continuation.yield(value) }
    }
}
