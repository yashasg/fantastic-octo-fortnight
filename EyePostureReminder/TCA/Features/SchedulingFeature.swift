import ComposableArchitecture
import Foundation
import ScreenTimeExtensionShared
import UserNotifications

/// TCA reducer (`p0-tca-10` / #673) owning the long-running scheduling
/// orchestration: streams installed at init plus `scheduleReminders`,
/// `reschedule(for:)`, `handleNotification(for:)`,
/// `handleForegroundTransition`, and `appWillResignActive`. It is the
/// canonical runtime for that surface (`#755` Phase E) and consumes the
/// dependency clients defined by `p0-tca-2`.
///
/// Behavioural fidelity caveats (intentional deferrals, each tracked by a
/// dedicated open issue — the closed `p0-tca-15` (#678) meta-tracker no
/// longer owns these follow-ups, and the umbrella drift from referencing
/// it was resolved in #895 by splitting per bullet; the dependency-client
/// surface bundle (#898) was likewise split per surface so each piece has
/// its own tracker rather than sharing an umbrella):
///   * `OverlayClient.lifecycleEvents`-driven bookkeeping: the
///     reducer subscribes to the multicast stream from `startEffect`
///     (cancellable from `stopEffect`) and routes every `.presented` /
///     `.dismissed` / `.settingsTapped` emission through
///     `.overlayLifecycleEvent(_:)` (#904). `.presented` / `.dismissed`
///     now drive `SessionTimingClient.sessionStarted` /
///     `sessionEnded` per-type (#901) and the DeviceActivity-on-present
///     hook landed in #903 — `.presented` calls
///     `DeviceActivityMonitorClient.startScheduleForOverlay(_:)` and
///     `.dismissed` calls the existing `cancel(_:)` accessor — so
///     `.settingsTapped` is the only remaining structural no-op pending
///     its own future tracker.
///
/// Launch-readiness analytics: `startEffect` emits
/// `SessionTimingClient.launchReady(.streamsInstalled)` from the tail of
/// the cold-launch installation `.merge` once every long-running stream
/// subscription is in-flight (#902), restoring the legacy
/// `AppCoordinator` `launchReady` signal at the dependency boundary.
///
/// Per-type interval differentiation (#897) is now honoured: `State`
/// caches both the eyes-side and posture-side `ReminderSettings`
/// snapshots vended by `SettingsClient.stream` / `postureStream`, and
/// the reducer reads them via `State.settings(for:)` so
/// `rescheduleType`, `thresholdReached`, `reminderNotification`, and
/// `scheduleReminders` use the correct interval / break duration for
/// each `ReminderType`.
///
/// Watchdog recovery shipped in #892 via `.watchdogRecoveryTriggered`
/// (action + effect) wired on top of `IPCClient.recentEvents` and the
/// existing `@Dependency(\.date)` clock; the reducer composes the
/// staleness verdict with `WatchdogHeartbeat.status(…)` so the behaviour
/// stays in lock-step with the legacy `WatchdogHeartbeat` parity
/// contract (`Tests/.../WatchdogHeartbeatTests.swift`).
@Reducer
struct SchedulingFeature {

    typealias NotificationRoute = AppDelegate.NotificationRoute

    /// Identifier for the silent one-time wake notification scheduled when
    /// a snooze begins. The value is stable across releases so a snooze-wake
    /// notification scheduled by an earlier app version is still cancellable
    /// here.
    static let snoozeWakeCategory = "com.yashasgujjar.kshana.snooze-wake"

    /// Watchdog-recovery staleness threshold (#892). Mirrors the legacy
    /// `AppCoordinator.watchdogHeartbeatGraceInterval` rule of thumb — a
    /// device-activity-lifecycle heartbeat older than this is treated as
    /// stale, and a missing heartbeat past this window classifies as
    /// `.missing`. Kept in seconds for direct use with
    /// `WatchdogHeartbeat.status(staleAfter:)`.
    static let watchdogHeartbeatStaleThreshold: TimeInterval = 130

    @ObservableState
    struct State: Equatable {
        var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
        /// Eyes-side `ReminderSettings` snapshot fed by
        /// `SettingsClient.stream()`. Treated as the canonical eyes-side
        /// schedule input; posture-side reads use `postureSettings` instead
        /// so per-type interval differentiation (#897) stays honoured.
        var settings = ReminderSettings(interval: 0, breakDuration: 0)
        /// Posture-side `ReminderSettings` snapshot fed by
        /// `SettingsClient.postureStream()`. Mirrors `settings` for the
        /// posture reminder type so `rescheduleType(.posture)` /
        /// `thresholdReached(.posture)` / `reminderNotification(.posture)`
        /// use the posture interval + break duration instead of the
        /// eyes-side values (#897).
        var postureSettings = ReminderSettings(interval: 0, breakDuration: 0)
        var isPausedByConditions: Bool = false
        var isUITestModeEnabled: Bool = false
        var snoozedUntil: Date?
        var pendingOverlay: PendingOverlay?

        struct PendingOverlay: Equatable, Sendable {
            let type: ReminderType
            let duration: TimeInterval
        }

        /// Per-type accessor for the cached `ReminderSettings` snapshot
        /// (#897). Callers driving a single-type effect (reschedule,
        /// threshold-reached, reminder-notification) should use this
        /// helper so the posture-side interval / break duration is
        /// respected when `type == .posture`.
        func settings(for type: ReminderType) -> ReminderSettings {
            switch type {
            case .eyes:    return settings
            case .posture: return postureSettings
            }
        }
    }

    enum Action: Equatable {
        case start
        case stop
        case foregroundTransition
        case backgroundTransition
        case scheduleReminders
        case rescheduleType(ReminderType)
        case notificationRouted(NotificationRoute)
        case thresholdReached(ReminderType)
        case pauseConditionChanged(Bool)
        case settingsChanged(ReminderSettings)
        /// Posture-side counterpart of `.settingsChanged`. Mutates
        /// `state.postureSettings` so per-type interval differentiation
        /// (#897) stays honoured for posture reminders.
        case postureSettingsChanged(ReminderSettings)
        case clearExpiredSnoozeIfNeeded
        case snoozeWakeFired
        case overlayDismissed(ReminderType)
        /// Watchdog recovery entry-point (#892). The reducer reads the
        /// recent App Group IPC event log via `IPCClient.recentEvents`
        /// and classifies the latest device-activity-lifecycle heartbeat
        /// using `WatchdogHeartbeat.status(…)` over a 130 s threshold; on
        /// a `.stale` / `.missing` verdict it cancels every pending
        /// reminder, cancels DeviceActivity monitoring, records a
        /// `watchdogRecoveryTriggered` IPC event (timestamped via
        /// `@Dependency(\.date)` so a `TestStore` can drive the clock),
        /// emits the `watchdogRecoveryTriggered` + `watchdogRecoveryCompleted`
        /// analytics pair, and re-enters `.scheduleReminders`. Fresh
        /// heartbeats short-circuit to a no-op so callers can dispatch
        /// the action unconditionally at foreground transitions.
        case watchdogRecoveryTriggered
        /// Forwarded from `OverlayClient.lifecycleEvents()` once
        /// `startEffect` installs the subscription (#904). The reducer
        /// currently treats every variant as a structural no-op — the
        /// per-event side-effects (session-timing analytics emit,
        /// DeviceActivity start hook) belong to sibling trackers
        /// #901 / #903 and will fill the handler as they land.
        case overlayLifecycleEvent(OverlayLifecycleEvent)
        case internalAction(Internal)

        enum Internal: Equatable {
            case scheduleSnoozeWake(Date)
            case cancelSnoozeWake
            case authStatusRefreshed(UNAuthorizationStatus)
            case snoozeStateCleared
        }
    }

    enum CancelID: Hashable {
        case settingsStream
        case postureSettingsStream
        case thresholdStream
        case pauseStream
        case ipcStream
        case overlayLifecycleStream
        case rescheduleDebounce(ReminderType)
        case snoozeWakeTask
    }

    @Dependency(\.settingsClient) var settingsClient: SettingsClient
    @Dependency(\.reminderSchedulerClient) var schedulerClient: ReminderSchedulerClient
    @Dependency(\.notificationClient) var notificationClient: NotificationClient
    @Dependency(\.overlayClient) var overlayClient: OverlayClient
    @Dependency(\.screenTimeTrackerClient) var trackerClient: ScreenTimeTrackerClient
    @Dependency(\.pauseConditionClient) var pauseClient: PauseConditionClient
    @Dependency(\.screenTimeAuthorizationClient) var screenTimeAuth: ScreenTimeAuthorizationClient
    @Dependency(\.deviceActivityMonitorClient) var deviceActivity: DeviceActivityMonitorClient
    @Dependency(\.ipcClient) var ipcClient: IPCClient
    @Dependency(\.analyticsClient) var analyticsClient: AnalyticsClient
    @Dependency(\.sessionTimingClient) var sessionTimingClient: SessionTimingClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date) var now

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .start:
                return startEffect()

            case .stop:
                return stopEffect()

            case .foregroundTransition:
                return foregroundTransitionEffect(state: state)

            case .backgroundTransition:
                return .run { [analyticsClient] _ in
                    analyticsClient.log(.appSessionEnd(sessionDurationS: 0))
                }

            case .scheduleReminders:
                return scheduleRemindersEffect(state: state)

            case let .rescheduleType(type):
                return rescheduleTypeEffect(type: type, state: state)

            case let .notificationRouted(route):
                return notificationRoutedEffect(route: route, state: &state)

            case let .thresholdReached(type):
                return thresholdReachedEffect(type: type, state: state)

            case let .pauseConditionChanged(isPaused):
                state.isPausedByConditions = isPaused
                return pauseConditionChangedEffect(isPaused: isPaused, state: state)

            case let .settingsChanged(newSettings):
                state.settings = newSettings
                return .none

            case let .postureSettingsChanged(newSettings):
                state.postureSettings = newSettings
                return .none

            case .clearExpiredSnoozeIfNeeded:
                return clearExpiredSnoozeEffect(state: &state)

            case .snoozeWakeFired:
                return snoozeWakeFiredEffect(state: &state)

            case .overlayDismissed:
                return .run { [deviceActivity] _ in await deviceActivity.cancel(nil) }

            case .watchdogRecoveryTriggered:
                return watchdogRecoveryTriggeredEffect()

            case let .overlayLifecycleEvent(event):
                return overlayLifecycleEventEffect(event)

            case let .internalAction(internalAction):
                return reduceInternal(internalAction, state: &state)
            }
        }
    }
}

// MARK: - Public effect builders

extension SchedulingFeature {

    func startEffect() -> Effect<Action> {
        .merge(
            settingsStreamEffect(),
            postureSettingsStreamEffect(),
            thresholdStreamEffect(),
            pauseStreamEffect(),
            ipcStreamEffect(),
            overlayLifecycleStreamEffect(),
            .run { [pauseClient] _ in await pauseClient.startMonitoring() },
            .run { [sessionTimingClient] _ in
                await sessionTimingClient.launchReady(.streamsInstalled)
            },
            .send(.scheduleReminders)
        )
    }

    func stopEffect() -> Effect<Action> {
        .merge(
            .cancel(id: CancelID.settingsStream),
            .cancel(id: CancelID.postureSettingsStream),
            .cancel(id: CancelID.thresholdStream),
            .cancel(id: CancelID.pauseStream),
            .cancel(id: CancelID.ipcStream),
            .cancel(id: CancelID.overlayLifecycleStream),
            .cancel(id: CancelID.snoozeWakeTask),
            .run { [pauseClient] _ in await pauseClient.stopMonitoring() }
        )
    }

    func scheduleRemindersEffect(state: State) -> Effect<Action> {
        let snapshot = SchedulingSnapshot(state: state)
        let analyticsClient = self.analyticsClient
        let notificationClient = self.notificationClient
        let schedulerClient = self.schedulerClient
        let settingsClient = self.settingsClient
        let trackerClient = self.trackerClient
        let scheduleSnoozeNotification = makeScheduleSnoozeNotification()

        return .run { send in
            let status = await notificationClient.authorizationStatus()
            await send(.internalAction(.authStatusRefreshed(status)))

            // Snooze guard (`#755` Phase E): if a snooze is still active,
            // pause trackers, drop scheduled reminders, and ensure the
            // wake notification is armed for the snooze-expiry time.
            if let until = snapshot.snoozedUntil {
                if until > Date() {
                    await trackerClient.pauseAll()
                    await schedulerClient.cancelAllReminders()
                    await send(.internalAction(.scheduleSnoozeWake(until)))
                    if status == .authorized {
                        await scheduleSnoozeNotification(until)
                    }
                    return
                }
                await settingsClient.setSnoozedUntil(nil)
                await settingsClient.setSnoozeCount(0)
                await send(.internalAction(.snoozeStateCleared))
                analyticsClient.log(.snoozeExpired)
            }

            await send(.internalAction(.cancelSnoozeWake))

            if status == .authorized {
                await schedulerClient.scheduleReminders(
                    snapshot.eyesSettings,
                    snapshot.postureSettings
                )
            } else {
                await schedulerClient.cancelAllReminders()
            }

            // Skip foreground tracker reconfig in UI-test mode so the
            // deterministic test environment isn't perturbed (`#755` Phase E).
            guard !snapshot.isUITestMode else { return }

            await Self.configureTracker(
                eyesSettings: snapshot.eyesSettings,
                postureSettings: snapshot.postureSettings,
                isPausedByConditions: snapshot.isPausedByConditions,
                tracker: trackerClient
            )
        }
    }

    func rescheduleTypeEffect(type: ReminderType, state: State) -> Effect<Action> {
        let snoozedUntil = state.snoozedUntil
        let currentSettings = state.settings(for: type)
        let clock = self.clock
        let notificationClient = self.notificationClient
        let schedulerClient = self.schedulerClient
        let trackerClient = self.trackerClient

        return .run { send in
            try? await clock.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }

            // Snooze guard (`#755` Phase E): skip the reschedule if a
            // snooze is still active.
            if let until = snoozedUntil, until > Date() { return }

            let status = await notificationClient.authorizationStatus()
            await send(.internalAction(.authStatusRefreshed(status)))

            let interval = currentSettings.interval
            if interval > 0 {
                await trackerClient.setThreshold(interval, type)
                await trackerClient.enableTracking(type)
                if status == .authorized {
                    await schedulerClient.rescheduleReminder(type, currentSettings)
                } else {
                    await schedulerClient.cancelReminder(type)
                }
            } else {
                await trackerClient.disableTracking(type)
                await schedulerClient.cancelReminder(type)
            }
        }
        .cancellable(id: CancelID.rescheduleDebounce(type), cancelInFlight: true)
    }

    func notificationRoutedEffect(
        route: NotificationRoute,
        state: inout State
    ) -> Effect<Action> {
        switch route {
        case let .reminder(type):
            return reminderNotificationEffect(type: type, state: &state)
        case .snoozeWake:
            state.snoozedUntil = nil
            return .merge(
                .cancel(id: CancelID.snoozeWakeTask),
                .send(.scheduleReminders)
            )
        case .ignore:
            return .none
        }
    }

    func reminderNotificationEffect(
        type: ReminderType,
        state: inout State
    ) -> Effect<Action> {
        // Snooze guard (`#755` Phase E): swallow the notification if a
        // snooze is still active.
        if let until = state.snoozedUntil, until > now() { return .none }
        let perTypeSettings = state.settings(for: type)
        let duration = perTypeSettings.breakDuration
        let interval = perTypeSettings.interval
        let hapticsEnabled = perTypeSettings.hapticsEnabled
        let pauseMediaDuringBreaks = perTypeSettings.pauseMediaDuringBreaks
        let analyticsClient = self.analyticsClient
        let ipcClient = self.ipcClient
        let overlayClient = self.overlayClient
        let settingsClient = self.settingsClient
        let trackerClient = self.trackerClient

        return .run { _ in
            await settingsClient.setSnoozeCount(0)
            let priorRoute = await ipcClient.fallbackRoute(type)
            await ipcClient.record(
                AppGroupIPCEvent(
                    kind: .notificationFallbackDelivered,
                    reasonRaw: type.shieldReason.rawValue,
                    detail: priorRoute.map { "prior_route=\($0.reason.rawValue)" }
                ),
                nil
            )
            analyticsClient.log(.reminderTriggered(
                type: type,
                thresholdS: interval,
                deliveryPath: .notificationFallback
            ))
            await overlayClient.show(type, duration, hapticsEnabled, pauseMediaDuringBreaks)
            // Reset the in-app counter so the foreground tracker doesn't fire
            // an additional overlay immediately after this notification.
            await trackerClient.reset(type)
        }
    }

    func thresholdReachedEffect(type: ReminderType, state: State) -> Effect<Action> {
        let currentSettings = state.settings(for: type)
        let interval = currentSettings.interval
        let duration = currentSettings.breakDuration
        let hapticsEnabled = currentSettings.hapticsEnabled
        let pauseMediaDuringBreaks = currentSettings.pauseMediaDuringBreaks
        let authStatus = state.notificationAuthStatus
        let analyticsClient = self.analyticsClient
        let overlayClient = self.overlayClient
        let schedulerClient = self.schedulerClient
        let settingsClient = self.settingsClient

        // Defensive guard mirroring the 300 ms disable-debounce window
        // (`#755` Phase E) — interval is the only signal `SettingsClient`
        // surfaces for the per-type enable check.
        guard interval > 0 else { return .none }

        return .run { _ in
            await settingsClient.setSnoozeCount(0)
            await overlayClient.show(type, duration, hapticsEnabled, pauseMediaDuringBreaks)
            analyticsClient.log(.reminderTriggered(
                type: type,
                thresholdS: interval,
                deliveryPath: .screenTimeThreshold
            ))
            if authStatus == .authorized {
                await schedulerClient.rescheduleReminder(type, currentSettings)
            }
        }
    }

    func pauseConditionChangedEffect(isPaused: Bool, state: State) -> Effect<Action> {
        let snoozedUntil = state.snoozedUntil
        let currentNow = now()
        let overlayClient = self.overlayClient
        let trackerClient = self.trackerClient
        return .run { _ in
            if isPaused {
                await trackerClient.pauseAll()
                await overlayClient.clearQueue()
                await overlayClient.dismiss()
                return
            }
            // Resume only if no active snooze is in effect (`#755` Phase E).
            guard (snoozedUntil ?? .distantPast) <= currentNow else { return }
            await trackerClient.resumeAll()
        }
    }

    func foregroundTransitionEffect(state: State) -> Effect<Action> {
        let snoozedUntil = state.snoozedUntil
        let priorAuthStatus = state.notificationAuthStatus
        let analyticsClient = self.analyticsClient
        let notificationClient = self.notificationClient
        let settingsClient = self.settingsClient
        let scheduleSnoozeNotification = makeScheduleSnoozeNotification()

        return .run { send in
            let status = await notificationClient.authorizationStatus()
            await send(.internalAction(.authStatusRefreshed(status)))

            // Foreground snooze reconciliation (`#755` Phase E): clear
            // expired snoozes and reschedule, or re-arm the wake
            // notification for a still-active snooze.
            if let until = snoozedUntil {
                if until <= Date() {
                    await settingsClient.setSnoozedUntil(nil)
                    await settingsClient.setSnoozeCount(0)
                    analyticsClient.log(.snoozeExpired)
                    await send(.internalAction(.snoozeStateCleared))
                    await send(.scheduleReminders)
                } else {
                    await send(.internalAction(.scheduleSnoozeWake(until)))
                    if status == .authorized {
                        await scheduleSnoozeNotification(until)
                    }
                }
                return
            }

            if status != priorAuthStatus {
                await send(.scheduleReminders)
            }
        }
    }

    func clearExpiredSnoozeEffect(state: inout State) -> Effect<Action> {
        guard let until = state.snoozedUntil, until <= now() else { return .none }
        state.snoozedUntil = nil
        let analyticsClient = self.analyticsClient
        let settingsClient = self.settingsClient
        return .run { _ in
            await settingsClient.setSnoozedUntil(nil)
            await settingsClient.setSnoozeCount(0)
            analyticsClient.log(.snoozeExpired)
        }
    }

    func snoozeWakeFiredEffect(state: inout State) -> Effect<Action> {
        state.snoozedUntil = nil
        let analyticsClient = self.analyticsClient
        let settingsClient = self.settingsClient
        return .merge(
            .cancel(id: CancelID.snoozeWakeTask),
            .run { send in
                await settingsClient.setSnoozedUntil(nil)
                await settingsClient.setSnoozeCount(0)
                analyticsClient.log(.snoozeExpired)
                await send(.scheduleReminders)
            }
        )
    }

    /// Watchdog-recovery side effect (#892). Reads the recent App Group
    /// IPC event log via `IPCClient.recentEvents`, classifies the latest
    /// device-activity-lifecycle heartbeat using `WatchdogHeartbeat.status(…)`
    /// against a 130 s staleness threshold, and on a `.stale` / `.missing`
    /// verdict cancels DeviceActivity monitoring, records a
    /// `watchdogRecoveryTriggered` IPC event, emits the
    /// `watchdogRecoveryTriggered` + `watchdogRecoveryCompleted` analytics
    /// pair, and sends `.scheduleReminders` to re-arm the schedule from a
    /// clean slate (per-type cancel-and-rearm via
    /// `ReminderScheduler.rescheduleReminder`; the `.notDetermined`
    /// fall-through also calls `schedulerClient.cancelAllReminders()`).
    /// Fresh heartbeats short-circuit so callers can dispatch the action
    /// unconditionally on foreground.
    ///
    /// Behavioural parity with the deleted
    /// `AppCoordinator.recoverStaleDeviceActivityWatchdogIfNeeded`
    /// (#680) — the per-reason fallback rescheduling is now subsumed by
    /// `.scheduleReminders`, which restores the notification fallback
    /// whenever authorization permits.
    func watchdogRecoveryTriggeredEffect() -> Effect<Action> {
        let now = self.now()
        let analyticsClient = self.analyticsClient
        let deviceActivity = self.deviceActivity
        let ipcClient = self.ipcClient
        return .run { send in
            let events = await ipcClient.recentEvents()
            let status = WatchdogHeartbeat.status(
                from: events,
                now: now,
                staleAfter: Self.watchdogHeartbeatStaleThreshold,
                matching: WatchdogHeartbeatDetail.deviceActivityLifecycleDetails
            )
            let detail: String
            switch status {
            case .fresh:
                return
            case .missing:
                detail = "missing"
            case let .stale(_, heartbeatDetail):
                detail = heartbeatDetail?.rawValue ?? "unknown"
            }

            await deviceActivity.cancel(nil)
            await ipcClient.record(
                AppGroupIPCEvent(
                    kind: .watchdogRecoveryTriggered,
                    reasonRaw: nil,
                    timestamp: now,
                    detail: detail
                ),
                "watchdog_recovery"
            )
            analyticsClient.log(.watchdogRecoveryTriggered(reason: nil, detail: detail))
            analyticsClient.log(.watchdogRecoveryCompleted(
                sessionCleared: true,
                fallbackScheduled: false
            ))
            await send(.scheduleReminders)
        }
    }
}

// MARK: - Internal action handling and stream effects

extension SchedulingFeature {

    func reduceInternal(
        _ action: Action.Internal,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case let .scheduleSnoozeWake(date):
            let interval = max(0, date.timeIntervalSince(now()))
            let clock = self.clock
            return .run { send in
                try? await clock.sleep(for: .seconds(interval))
                await send(.snoozeWakeFired)
            }
            .cancellable(id: CancelID.snoozeWakeTask, cancelInFlight: true)

        case .cancelSnoozeWake:
            let notificationClient = self.notificationClient
            return .merge(
                .cancel(id: CancelID.snoozeWakeTask),
                .run { _ in
                    await notificationClient.removePending([Self.snoozeWakeCategory])
                }
            )

        case let .authStatusRefreshed(status):
            state.notificationAuthStatus = status
            return .none

        case .snoozeStateCleared:
            state.snoozedUntil = nil
            return .none
        }
    }

    func settingsStreamEffect() -> Effect<Action> {
        let settingsClient = self.settingsClient
        return .run { send in
            for await snapshot in settingsClient.stream() {
                await send(.settingsChanged(snapshot))
            }
        }
        .cancellable(id: CancelID.settingsStream, cancelInFlight: true)
    }

    /// Posture-side counterpart of `settingsStreamEffect()` (#897). Drains
    /// `SettingsClient.postureStream()` and dispatches
    /// `.postureSettingsChanged`, so the cached `state.postureSettings`
    /// snapshot stays in lock-step with posture-side mutations made from
    /// `SettingsFeature` / `OnboardingFeature` / `resetToDefaults()`.
    func postureSettingsStreamEffect() -> Effect<Action> {
        let settingsClient = self.settingsClient
        return .run { send in
            for await snapshot in settingsClient.postureStream() {
                await send(.postureSettingsChanged(snapshot))
            }
        }
        .cancellable(id: CancelID.postureSettingsStream, cancelInFlight: true)
    }

    func thresholdStreamEffect() -> Effect<Action> {
        let trackerClient = self.trackerClient
        return .run { send in
            for await type in trackerClient.thresholdReached() {
                await send(.thresholdReached(type))
            }
        }
        .cancellable(id: CancelID.thresholdStream, cancelInFlight: true)
    }

    func pauseStreamEffect() -> Effect<Action> {
        let pauseClient = self.pauseClient
        return .run { send in
            for await isPaused in pauseClient.pauseChanges() {
                await send(.pauseConditionChanged(isPaused))
            }
        }
        .cancellable(id: CancelID.pauseStream, cancelInFlight: true)
    }

    func ipcStreamEffect() -> Effect<Action> {
        let ipcClient = self.ipcClient
        return .run { send in
            for await _ in ipcClient.trueInterruptChanges() {
                await send(.scheduleReminders)
            }
        }
        .cancellable(id: CancelID.ipcStream, cancelInFlight: true)
    }

    /// Subscribes to `OverlayClient.lifecycleEvents()` and forwards each
    /// emission as `.overlayLifecycleEvent(_:)` (#904). The stream is
    /// installed from `startEffect` and cancelled from `stopEffect`. The
    /// reducer's handler dispatches `SessionTimingClient` calls per #901
    /// and `DeviceActivityMonitorClient.startScheduleForOverlay(_:)` /
    /// `cancel(_:)` per #903; future per-event hooks plug in from the
    /// same handler without re-plumbing the stream wiring.
    func overlayLifecycleStreamEffect() -> Effect<Action> {
        let overlayClient = self.overlayClient
        return .run { send in
            for await event in overlayClient.lifecycleEvents() {
                await send(.overlayLifecycleEvent(event))
            }
        }
        .cancellable(id: CancelID.overlayLifecycleStream, cancelInFlight: true)
    }

    /// Routes a single `OverlayLifecycleEvent` to the per-variant side-
    /// effects owned by sibling trackers. `.presented` / `.dismissed` map
    /// to `SessionTimingClient.sessionStarted` / `sessionEnded` (#901)
    /// and to `DeviceActivityMonitorClient.startScheduleForOverlay(_:)`
    /// (on `.presented`) / `cancel(_:)` (on `.dismissed`) per #903.
    /// `.settingsTapped` is still a structural no-op pending the
    /// analytics surface a future tracker will own.
    func overlayLifecycleEventEffect(_ event: OverlayLifecycleEvent) -> Effect<Action> {
        switch event {
        case let .presented(type):
            return .run { [sessionTimingClient, deviceActivity, now] _ in
                await sessionTimingClient.sessionStarted(type, now())
                await deviceActivity.startScheduleForOverlay(type)
            }
        case let .dismissed(type):
            return .run { [sessionTimingClient, deviceActivity, now] _ in
                await sessionTimingClient.sessionEnded(type, now())
                await deviceActivity.cancel(nil)
            }
        case .settingsTapped:
            return .none
        }
    }
}

// MARK: - Snapshot + side-effect helpers

/// Plain-old-Swift snapshot of the values `scheduleRemindersEffect` reads from
/// `State`. Extracted into a dedicated value to keep the closure capture list
/// short enough for SwiftLint's `closure_parameter_position` rule.
///
/// Carries both the eyes-side and posture-side `ReminderSettings` snapshots
/// (#897) so `scheduleRemindersEffect` can pass per-type values to
/// `ReminderSchedulerClient.scheduleReminders` and `configureTracker`.
private struct SchedulingSnapshot: Sendable {
    let eyesSettings: ReminderSettings
    let postureSettings: ReminderSettings
    let snoozedUntil: Date?
    let isUITestMode: Bool
    let isPausedByConditions: Bool

    init(state: SchedulingFeature.State) {
        self.eyesSettings = state.settings
        self.postureSettings = state.postureSettings
        self.snoozedUntil = state.snoozedUntil
        self.isUITestMode = state.isUITestModeEnabled
        self.isPausedByConditions = state.isPausedByConditions
    }
}

extension SchedulingFeature {

    static func configureTracker(
        eyesSettings: ReminderSettings,
        postureSettings: ReminderSettings,
        isPausedByConditions: Bool,
        tracker: ScreenTimeTrackerClient
    ) async {
        for type in ReminderType.allCases {
            let interval: TimeInterval
            switch type {
            case .eyes:    interval = eyesSettings.interval
            case .posture: interval = postureSettings.interval
            }
            if interval > 0 {
                await tracker.setThreshold(interval, type)
                await tracker.enableTracking(type)
            } else {
                await tracker.disableTracking(type)
            }
        }
        guard !isPausedByConditions else { return }
        await tracker.resumeAll()
    }

    /// Returns a sendable closure that schedules the silent one-time wake
    /// notification for the supplied date (`#755` Phase E) so a killed app
    /// is woken when the snooze period expires.
    func makeScheduleSnoozeNotification() -> @Sendable (Date) async -> Void {
        let notificationClient = self.notificationClient
        return { date in
            let interval = max(1, date.timeIntervalSince(Date()))
            let content = UNMutableNotificationContent()
            content.title = ""
            content.body = ""
            content.sound = nil
            content.badge = nil
            if #available(iOS 15, *) {
                content.interruptionLevel = .passive
            }
            content.categoryIdentifier = SchedulingFeature.snoozeWakeCategory
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: interval,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: SchedulingFeature.snoozeWakeCategory,
                content: content,
                trigger: trigger
            )
            try? await notificationClient.add(request)
        }
    }
}
