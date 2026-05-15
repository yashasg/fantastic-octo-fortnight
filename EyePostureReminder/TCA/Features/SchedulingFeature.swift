import ComposableArchitecture
import Foundation
import ScreenTimeExtensionShared
import UserNotifications

/// TCA reducer (`p0-tca-10` / #673) owning the long-running scheduling
/// orchestration that the legacy `AppCoordinator` previously held.
///
/// Built as a behavioural mirror of the (now-deleted) hot paths from
/// `EyePostureReminder/Services/AppCoordinator.swift` — the streams
/// installed at init plus `scheduleReminders`, `reschedule(for:)`,
/// `handleNotification(for:)`, `handleForegroundTransition`, and
/// `appWillResignActive` — using the dependency clients defined by
/// `p0-tca-2`. The legacy `AppCoordinator*.swift` files were removed
/// in `#755` Phase E (commit b9a1c96, PR #760); this reducer is now
/// the canonical runtime for the surface it ports.
///
/// Behavioural fidelity caveats (intentional deferrals, tracked under
/// `p0-tca-15`):
///   * `SettingsClient` only vends a single eyes-side `ReminderSettings`
///     snapshot, so per-type interval differentiation reuses
///     `state.settings.interval` for both reminder types until a richer
///     settings client lands.
///   * Watchdog recovery, fallback-routing IPC reads, session-timing
///     analytics, launch-readiness analytics, DeviceActivity scheduling on
///     overlay present, and the `OverlayClient.lifecycleEvents`-driven
///     bookkeeping all require dependency-client surface that does not yet
///     exist; those side-effects are tracked under `p0-tca-15` follow-ups.
///   * `hapticsEnabled`/`pauseMediaDuringBreaks` are not yet exposed on
///     `ReminderSettings`; the reducer passes `false` for both when calling
///     `OverlayClient.show` (matches the SettingsClient default state).
@Reducer
struct SchedulingFeature {

    typealias NotificationRoute = AppDelegate.NotificationRoute

    /// Identifier for the silent one-time wake notification scheduled when
    /// a snooze begins. Stable across the legacy `AppCoordinator` → TCA
    /// migration so a snooze-wake notification scheduled under the old
    /// runtime is still cancellable here.
    static let snoozeWakeCategory = "com.yashasgujjar.kshana.snooze-wake"

    @ObservableState
    struct State: Equatable {
        var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
        var settings = ReminderSettings(interval: 0, breakDuration: 0)
        var isPausedByConditions: Bool = false
        var isUITestModeEnabled: Bool = false
        var snoozedUntil: Date?
        var pendingOverlay: PendingOverlay?

        struct PendingOverlay: Equatable, Sendable {
            let type: ReminderType
            let duration: TimeInterval
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
        case clearExpiredSnoozeIfNeeded
        case snoozeWakeFired
        case overlayDismissed(ReminderType)
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
        case thresholdStream
        case pauseStream
        case ipcStream
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

            case .clearExpiredSnoozeIfNeeded:
                return clearExpiredSnoozeEffect(state: &state)

            case .snoozeWakeFired:
                return snoozeWakeFiredEffect(state: &state)

            case .overlayDismissed:
                return .run { [deviceActivity] _ in await deviceActivity.cancel(nil) }

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
            thresholdStreamEffect(),
            pauseStreamEffect(),
            ipcStreamEffect(),
            .run { [pauseClient] _ in await pauseClient.startMonitoring() },
            .send(.scheduleReminders)
        )
    }

    func stopEffect() -> Effect<Action> {
        .merge(
            .cancel(id: CancelID.settingsStream),
            .cancel(id: CancelID.thresholdStream),
            .cancel(id: CancelID.pauseStream),
            .cancel(id: CancelID.ipcStream),
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

            // Snooze guard — ported from the deleted `AppCoordinator.scheduleReminders`
            // (#755 Phase E).
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
                await schedulerClient.scheduleReminders(snapshot.settings)
            } else {
                await schedulerClient.cancelAllReminders()
            }

            // Skip foreground tracker reconfig in UI-test mode for parity with
            // the deleted `AppCoordinator.scheduleReminders` (#755 Phase E).
            guard !snapshot.isUITestMode else { return }

            await Self.configureTracker(
                settings: snapshot.settings,
                isPausedByConditions: snapshot.isPausedByConditions,
                tracker: trackerClient
            )
        }
    }

    func rescheduleTypeEffect(type: ReminderType, state: State) -> Effect<Action> {
        let snoozedUntil = state.snoozedUntil
        let currentSettings = state.settings
        let clock = self.clock
        let notificationClient = self.notificationClient
        let schedulerClient = self.schedulerClient
        let trackerClient = self.trackerClient

        return .run { send in
            try? await clock.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }

            // Snooze guard — ported from the deleted `AppCoordinator.performReschedule`
            // (#755 Phase E).
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
        // Snooze guard — ported from the deleted `AppCoordinator.handleNotification`
        // (#755 Phase E).
        if let until = state.snoozedUntil, until > now() { return .none }
        let duration = state.settings.breakDuration
        let interval = state.settings.interval
        let analyticsClient = self.analyticsClient
        let ipcClient = self.ipcClient
        let overlayClient = self.overlayClient
        let settingsClient = self.settingsClient
        let trackerClient = self.trackerClient

        return .run { _ in
            await settingsClient.setSnoozeCount(0)
            await ipcClient.record(
                AppGroupIPCEvent(
                    kind: .notificationFallbackDelivered,
                    reasonRaw: type.shieldReason.rawValue,
                    detail: nil
                ),
                nil
            )
            analyticsClient.log(.reminderTriggered(
                type: type,
                thresholdS: interval,
                deliveryPath: .notificationFallback
            ))
            await overlayClient.show(type, duration, false, false)
            // Reset the in-app counter so the foreground tracker doesn't fire
            // an additional overlay immediately after this notification.
            await trackerClient.reset(type)
        }
    }

    func thresholdReachedEffect(type: ReminderType, state: State) -> Effect<Action> {
        let interval = state.settings.interval
        let duration = state.settings.breakDuration
        let currentSettings = state.settings
        let authStatus = state.notificationAuthStatus
        let analyticsClient = self.analyticsClient
        let overlayClient = self.overlayClient
        let schedulerClient = self.schedulerClient
        let settingsClient = self.settingsClient

        // Defensive guard mirroring the 300 ms disable-debounce window from
        // the deleted `AppCoordinator` init (#755 Phase E) — interval is the
        // only signal the SettingsClient surfaces for the per-type enable check.
        guard interval > 0 else { return .none }

        return .run { _ in
            await settingsClient.setSnoozeCount(0)
            await overlayClient.show(type, duration, false, false)
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
            // Resume only if no active snooze (ported from the deleted
            // `AppCoordinator.pauseConditionChanged`, #755 Phase E).
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

            // Ported from the deleted `AppCoordinator.handleForegroundTransition`
            // (#755 Phase E).
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
}

// MARK: - Snapshot + side-effect helpers

/// Plain-old-Swift snapshot of the values `scheduleRemindersEffect` reads from
/// `State`. Extracted into a dedicated value to keep the closure capture list
/// short enough for SwiftLint's `closure_parameter_position` rule.
private struct SchedulingSnapshot: Sendable {
    let settings: ReminderSettings
    let snoozedUntil: Date?
    let isUITestMode: Bool
    let isPausedByConditions: Bool

    init(state: SchedulingFeature.State) {
        self.settings = state.settings
        self.snoozedUntil = state.snoozedUntil
        self.isUITestMode = state.isUITestModeEnabled
        self.isPausedByConditions = state.isPausedByConditions
    }
}

extension SchedulingFeature {

    static func configureTracker(
        settings: ReminderSettings,
        isPausedByConditions: Bool,
        tracker: ScreenTimeTrackerClient
    ) async {
        let interval = settings.interval
        for type in ReminderType.allCases {
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
    /// notification for the supplied date — ports the behaviour of the
    /// deleted `AppCoordinator.scheduleSnoozeWakeNotification(at:)` (#755
    /// Phase E) so a killed app is woken when the snooze period expires.
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
