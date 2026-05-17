import ComposableArchitecture
import Foundation
import UserNotifications

/// Reducer powering the Settings screen, introduced by `p0-tca-6` / #669.
///
/// `#755` Phase B extended the surface so `SettingsView` can read every
/// value it needs — debounced eyes-side reschedules, notification
/// authorisation, Screen Time / FamilyControls authorisation, and the
/// snooze-cancel action — directly from this store, without reaching
/// across to a parallel object graph.
///
/// ## Posture-side bindable surface (#805)
///
/// Eyes-side and posture-side reminder pickers now both flow through this
/// reducer's bindable surface. `SettingsClient.snapshot` continues to vend
/// eyes-side values; the parallel `postureSnapshot` / `postureStream` pair
/// added in #805 carry posture-side values without changing the eyes-side
/// payload that `HomeFeature` and `SchedulingFeature` consume.
///
/// ## Why `settings` is computed
///
/// `ReminderSettings.interval` and `ReminderSettings.breakDuration` are
/// declared `let`, which makes `\State.settings.interval` only a read-only
/// `KeyPath`. `BindableAction` requires `WritableKeyPath`, so the bindable
/// surface uses the top-level `eyesInterval` / `eyesBreakDuration` /
/// `postureInterval` / `postureBreakDuration` mirrors and `settings` /
/// `postureSettings` are derived from them. This keeps the spec's
/// `state.settings` accessor intact for downstream callers
/// (`scheduler.rescheduleReminder(_:_:)`).
@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        /// Eyes-side reminder interval, in seconds. Bindable from the View.
        var eyesInterval: TimeInterval = 0

        /// Eyes-side break duration, in seconds. Bindable from the View.
        var eyesBreakDuration: TimeInterval = 0

        /// Posture-side reminder interval, in seconds. Bindable from the View.
        /// Mirrors `eyesInterval` after #805 migrated the posture pickers off
        /// `@AppStorage`.
        var postureInterval: TimeInterval = 0

        /// Posture-side break duration, in seconds. Bindable from the View.
        /// Mirrors `eyesBreakDuration` after #805.
        var postureBreakDuration: TimeInterval = 0

        /// Last-committed eyes interval; used to compute analytics deltas.
        var prevEyesInterval: TimeInterval = .zero

        /// Last-committed eyes break duration; used to compute analytics
        /// deltas.
        var prevEyesBreakDuration: TimeInterval = .zero

        /// Last-committed posture interval; used to compute analytics
        /// deltas. Populated from `SettingsClient.postureSnapshot` on
        /// `.onAppear` and refreshed on every `.postureSettingsChanged`
        /// (#805).
        var prevPostureInterval: TimeInterval = .zero

        /// Last-committed posture break duration; used to compute analytics
        /// deltas. Populated from `SettingsClient.postureSnapshot` on
        /// `.onAppear` and refreshed on every `.postureSettingsChanged`
        /// (#805).
        var prevPostureBreakDuration: TimeInterval = .zero

        /// Drives presentation of the reset-to-defaults confirmation alert.
        var showResetConfirm: Bool = false

        /// Drives presentation of the transient "Saved" banner.
        var showSavedBanner: Bool = false

        /// Current notification authorization status. Populated from the
        /// `NotificationClient` stream and surfaced by `SettingsView` to
        /// render the "Notifications disabled" warning row.
        var notificationAuthStatus: UNAuthorizationStatus = .notDetermined

        /// Current Screen Time / FamilyControls authorisation status.
        /// Populated from the `ScreenTimeAuthorizationClient` stream and
        /// drives the True Interrupt Mode status row + denied-recovery
        /// callout in `SettingsView`.
        var screenTimeAuthStatus: ScreenTimeAuthorizationStatus = .unavailable

        /// Aggregated eyes-side `ReminderSettings` view used by the
        /// scheduler client. Computed because `ReminderSettings` exposes
        /// `let` fields and so cannot be mutated through a bindable key
        /// path.
        var settings: ReminderSettings {
            ReminderSettings(
                interval: eyesInterval,
                breakDuration: eyesBreakDuration
            )
        }

        /// Aggregated posture-side `ReminderSettings` view used by the
        /// scheduler client when posture pickers commit. Computed for the
        /// same `let`-field reason as `settings`.
        var postureSettings: ReminderSettings {
            ReminderSettings(
                interval: postureInterval,
                breakDuration: postureBreakDuration
            )
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case task
        case settingsChanged(ReminderSettings)
        case postureSettingsChanged(ReminderSettings)
        case snoozeTapped(SnoozeOption)
        case cancelSnooze
        case resetConfirmed
        case savedBannerExpired
        case notificationAuthStatusChanged(UNAuthorizationStatus)
        case screenTimeAuthStatusChanged(ScreenTimeAuthorizationStatus)

        /// Emit a `setting_changed` analytics event for settings that are
        /// still persisted via `@AppStorage` rather than the bindable surface
        /// of this reducer. After #805 the seven non-bindable rows
        /// (master/per-type enable, haptics, pause-during-focus, etc.) remain
        /// the only callers — the Settings-screen interval/duration pickers
        /// emit directly from the bindable surface for both eyes and posture.
        ///
        /// `oldValue` / `newValue` are pre-stringified by the caller so the
        /// action stays `Equatable` regardless of the underlying setting's
        /// type (`Bool`, `TimeInterval`, …) and the reducer can forward
        /// straight into `AnalyticsEvent.settingChanged`.
        case settingToggleChanged(setting: AnalyticsEvent.SettingKey, oldValue: String, newValue: String)
    }

    /// Snooze durations exposed to the Settings UI. Analytics codes
    /// stay stable across releases (and survived the MVVM → TCA
    /// migration). Localised labels stay in the View layer per the
    /// Phase 1 "own this file only" constraint.
    enum SnoozeOption: String, CaseIterable, Equatable, Sendable {
        case fiveMinutes
        case oneHour
        case restOfDay

        /// Stable, non-localised analytics code emitted with
        /// `.snoozeActivated`. Never changes between app versions or
        /// locales.
        var analyticsCode: String {
            switch self {
            case .fiveMinutes: return "5m"
            case .oneHour:     return "1h"
            case .restOfDay:   return "rest_of_day"
            }
        }
    }

    @Dependency(\.settingsClient) var settingsClient: SettingsClient
    @Dependency(\.reminderSchedulerClient) var scheduler: ReminderSchedulerClient
    @Dependency(\.analyticsClient) var analytics: AnalyticsClient
    @Dependency(\.notificationClient) var notificationClient: NotificationClient
    @Dependency(\.screenTimeAuthorizationClient)
    var screenTimeAuthorizationClient: ScreenTimeAuthorizationClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date) var now
    @Dependency(\.calendar) var calendar

    private enum CancelID: Hashable {
        case eyesIntervalDebounce
        case eyesBreakDurationDebounce
        case postureIntervalDebounce
        case postureBreakDurationDebounce
        case snoozeBanner
        case settingToggleBanner
        case screenTimeAuthStatusStream
        case notificationAuthStatusPoll
    }

    /// Time the "Settings saved" banner stays on screen after a persisted
    /// change. 4 s keeps the confirmation visible long enough that XCUI's
    /// `Wait for app to idle` window (~2 s on macOS-15 CI runners) still
    /// leaves >1 s for `XCTestCase.waitForExistence` to observe the banner.
    /// Shared by the bindable surface, snooze tap, and the non-bindable
    /// analytics shim so the duration stays consistent across every
    /// banner-triggering action.
    private static let savedBannerVisibilityDuration: Duration = .seconds(4)

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.eyesInterval):
                let oldValue = state.prevEyesInterval
                let newValue = state.eyesInterval
                let nextSettings = state.settings
                state.showSavedBanner = true
                return .run { send in
                    try await clock.sleep(for: .milliseconds(300))
                    await settingsClient.updateEyesInterval(newValue)
                    await scheduler.rescheduleReminder(.eyes, nextSettings)
                    analytics.log(.settingChanged(
                        setting: .eyesInterval,
                        oldValue: String(oldValue),
                        newValue: String(newValue)
                    ))
                    try await clock.sleep(for: Self.savedBannerVisibilityDuration)
                    await send(.savedBannerExpired)
                }
                .cancellable(id: CancelID.eyesIntervalDebounce, cancelInFlight: true)

            case .binding(\.eyesBreakDuration):
                let oldValue = state.prevEyesBreakDuration
                let newValue = state.eyesBreakDuration
                let nextSettings = state.settings
                state.showSavedBanner = true
                return .run { send in
                    try await clock.sleep(for: .milliseconds(300))
                    await settingsClient.updateEyesBreakDuration(newValue)
                    await scheduler.rescheduleReminder(.eyes, nextSettings)
                    analytics.log(.settingChanged(
                        setting: .eyesBreakDuration,
                        oldValue: String(oldValue),
                        newValue: String(newValue)
                    ))
                    try await clock.sleep(for: Self.savedBannerVisibilityDuration)
                    await send(.savedBannerExpired)
                }
                .cancellable(id: CancelID.eyesBreakDurationDebounce, cancelInFlight: true)

            case .binding(\.postureInterval):
                let oldValue = state.prevPostureInterval
                let newValue = state.postureInterval
                let nextSettings = state.postureSettings
                state.showSavedBanner = true
                return .run { send in
                    try await clock.sleep(for: .milliseconds(300))
                    await settingsClient.updatePostureInterval(newValue)
                    await scheduler.rescheduleReminder(.posture, nextSettings)
                    analytics.log(.settingChanged(
                        setting: .postureInterval,
                        oldValue: String(oldValue),
                        newValue: String(newValue)
                    ))
                    try await clock.sleep(for: Self.savedBannerVisibilityDuration)
                    await send(.savedBannerExpired)
                }
                .cancellable(id: CancelID.postureIntervalDebounce, cancelInFlight: true)

            case .binding(\.postureBreakDuration):
                let oldValue = state.prevPostureBreakDuration
                let newValue = state.postureBreakDuration
                let nextSettings = state.postureSettings
                state.showSavedBanner = true
                return .run { send in
                    try await clock.sleep(for: .milliseconds(300))
                    await settingsClient.updatePostureBreakDuration(newValue)
                    await scheduler.rescheduleReminder(.posture, nextSettings)
                    analytics.log(.settingChanged(
                        setting: .postureBreakDuration,
                        oldValue: String(oldValue),
                        newValue: String(newValue)
                    ))
                    try await clock.sleep(for: Self.savedBannerVisibilityDuration)
                    await send(.savedBannerExpired)
                }
                .cancellable(id: CancelID.postureBreakDurationDebounce, cancelInFlight: true)

            case .binding:
                return .none

            case .onAppear:
                let snapshot = settingsClient.snapshot()
                state.eyesInterval = snapshot.interval
                state.eyesBreakDuration = snapshot.breakDuration
                state.prevEyesInterval = snapshot.interval
                state.prevEyesBreakDuration = snapshot.breakDuration
                let posture = settingsClient.postureSnapshot()
                state.postureInterval = posture.interval
                state.postureBreakDuration = posture.breakDuration
                state.prevPostureInterval = posture.interval
                state.prevPostureBreakDuration = posture.breakDuration
                return .run { [notificationClient, screenTimeAuthorizationClient] send in
                    async let notification = notificationClient.authorizationStatus()
                    async let screenTime = screenTimeAuthorizationClient.status()
                    await send(.notificationAuthStatusChanged(notification))
                    await send(.screenTimeAuthStatusChanged(screenTime))
                }

            case .task:
                return .merge(
                    .run { [clock, notificationClient] send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            let status = await notificationClient.authorizationStatus()
                            await send(.notificationAuthStatusChanged(status))
                        }
                    }
                    .cancellable(id: CancelID.notificationAuthStatusPoll, cancelInFlight: true),
                    .run { [screenTimeAuthorizationClient] send in
                        for await status in screenTimeAuthorizationClient.statusChanges() {
                            await send(.screenTimeAuthStatusChanged(status))
                        }
                    }
                    .cancellable(id: CancelID.screenTimeAuthStatusStream, cancelInFlight: true)
                )

            case let .settingsChanged(snapshot):
                state.eyesInterval = snapshot.interval
                state.eyesBreakDuration = snapshot.breakDuration
                state.prevEyesInterval = snapshot.interval
                state.prevEyesBreakDuration = snapshot.breakDuration
                return .none

            case let .postureSettingsChanged(snapshot):
                state.postureInterval = snapshot.interval
                state.postureBreakDuration = snapshot.breakDuration
                state.prevPostureInterval = snapshot.interval
                state.prevPostureBreakDuration = snapshot.breakDuration
                return .none

            case let .snoozeTapped(option):
                let endDate = option.endDate(referenceDate: now(), calendar: calendar)
                state.showSavedBanner = true
                return .run { send in
                    await settingsClient.setSnoozedUntil(endDate)
                    await settingsClient.setSnoozeCount(0)
                    analytics.log(.snoozeActivated(durationOption: option.analyticsCode))
                    try await clock.sleep(for: Self.savedBannerVisibilityDuration)
                    await send(.savedBannerExpired)
                }
                .cancellable(id: CancelID.snoozeBanner, cancelInFlight: true)

            case .cancelSnooze:
                return .run { _ in
                    await settingsClient.setSnoozedUntil(nil)
                    await settingsClient.setSnoozeCount(0)
                    analytics.log(.snoozeCancelled)
                }

            case .resetConfirmed:
                state.showResetConfirm = false
                return .run { _ in
                    await settingsClient.resetToDefaults()
                }

            case .savedBannerExpired:
                state.showSavedBanner = false
                return .none

            case let .notificationAuthStatusChanged(status):
                state.notificationAuthStatus = status
                return .none

            case let .screenTimeAuthStatusChanged(status):
                state.screenTimeAuthStatus = status
                return .none

            case let .settingToggleChanged(setting, oldValue, newValue):
                // #787: the non-bindable rows (master toggle, eyes/posture
                // enable, smart-pause toggles, …) write through `@AppStorage`
                // and reach the reducer only via this analytics shim. Every
                // persisted setting change also flips the saved-banner, so
                // we mirror that here. Without this, the master-toggle
                // XCUITest assertion in
                // `SettingsFlowTests.test_settings_savedBanner_appearsOnToggle`
                // never observes the banner (read as "XCUI flake" until the
                // root cause was identified).
                state.showSavedBanner = true
                return .run { [analytics] send in
                    analytics.log(.settingChanged(
                        setting: setting,
                        oldValue: oldValue,
                        newValue: newValue
                    ))
                    try await clock.sleep(for: Self.savedBannerVisibilityDuration)
                    await send(.savedBannerExpired)
                }
                .cancellable(id: CancelID.settingToggleBanner, cancelInFlight: true)
            }
        }
    }
}

extension SettingsFeature.SnoozeOption {
    /// Computes the absolute snooze expiry date from an injected reference
    /// date and calendar. Behaviour — including the rest-of-day midnight
    /// calculation that honours DST transitions — is locked in by the
    /// `SnoozeOption` unit tests.
    func endDate(referenceDate: Date, calendar: Calendar) -> Date {
        switch self {
        case .fiveMinutes:
            return referenceDate.addingTimeInterval(5 * 60)
        case .oneHour:
            return referenceDate.addingTimeInterval(60 * 60)
        case .restOfDay:
            return calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: referenceDate)
            ) ?? referenceDate.addingTimeInterval(24 * 60 * 60)
        }
    }
}
