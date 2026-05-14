import ComposableArchitecture
import Foundation

/// Phase 1 reducer (`p0-tca-6` / #669) replacing the legacy
/// `SettingsViewModel` for the Settings screen.
///
/// Mirrors the observable behaviour of `SettingsViewModel` so a later
/// Phase 2 issue (`p0-tca-14` / #677) can swap `SettingsView` to read from
/// this store and the legacy view-model can be deleted.
///
/// ## Phase 0 dependency surface
///
/// `SettingsClient.snapshot` (defined in `p0-tca-2` / #663) only returns
/// the eyes-side `ReminderSettings`. The posture-side `prev*` capture
/// fields live on `State` per the issue spec but are populated only once
/// Phase 2 extends the snapshot surface (`p0-tca-15` / #678). They default
/// to `.zero` and are not exercised by this reducer.
///
/// ## Why `settings` is computed
///
/// `ReminderSettings.interval` and `ReminderSettings.breakDuration` are
/// declared `let`, which makes `\State.settings.interval` only a read-only
/// `KeyPath`. `BindableAction` requires `WritableKeyPath`, so the bindable
/// surface uses the top-level `eyesInterval` / `eyesBreakDuration` mirrors
/// and `settings` is derived from them. This keeps the spec's
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

        /// Last-committed eyes interval; used to compute analytics deltas.
        var prevEyesInterval: TimeInterval = .zero

        /// Last-committed eyes break duration; used to compute analytics
        /// deltas.
        var prevEyesBreakDuration: TimeInterval = .zero

        /// Last-committed posture interval. Populated once Phase 2 extends
        /// `SettingsClient` to vend posture-side snapshots (`p0-tca-15`).
        var prevPostureInterval: TimeInterval = .zero

        /// Last-committed posture break duration. Populated once Phase 2
        /// extends `SettingsClient` to vend posture-side snapshots
        /// (`p0-tca-15`).
        var prevPostureBreakDuration: TimeInterval = .zero

        /// Drives presentation of the reset-to-defaults confirmation alert.
        var showResetConfirm: Bool = false

        /// Drives presentation of the transient "Saved" banner.
        var showSavedBanner: Bool = false

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
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case settingsChanged(ReminderSettings)
        case snoozeTapped(SnoozeOption)
        case resetConfirmed
        case savedBannerExpired
    }

    /// Snooze durations exposed to the Settings UI. Mirrors
    /// `SettingsViewModel.SnoozeOption` so analytics codes are stable
    /// across the MVVM → TCA migration. Localised labels stay in the View
    /// layer per the Phase 1 "own this file only" constraint.
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
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date) var now
    @Dependency(\.calendar) var calendar

    private enum CancelID: Hashable {
        case eyesIntervalDebounce
        case eyesBreakDurationDebounce
        case snoozeBanner
    }

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
                    try await clock.sleep(for: .seconds(2))
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
                    try await clock.sleep(for: .seconds(2))
                    await send(.savedBannerExpired)
                }
                .cancellable(id: CancelID.eyesBreakDurationDebounce, cancelInFlight: true)

            case .binding:
                return .none

            case .onAppear:
                let snapshot = settingsClient.snapshot()
                state.eyesInterval = snapshot.interval
                state.eyesBreakDuration = snapshot.breakDuration
                state.prevEyesInterval = snapshot.interval
                state.prevEyesBreakDuration = snapshot.breakDuration
                return .none

            case let .settingsChanged(snapshot):
                state.eyesInterval = snapshot.interval
                state.eyesBreakDuration = snapshot.breakDuration
                state.prevEyesInterval = snapshot.interval
                state.prevEyesBreakDuration = snapshot.breakDuration
                return .none

            case let .snoozeTapped(option):
                let endDate = option.endDate(referenceDate: now(), calendar: calendar)
                state.showSavedBanner = true
                return .run { send in
                    await settingsClient.setSnoozedUntil(endDate)
                    await settingsClient.setSnoozeCount(0)
                    analytics.log(.snoozeActivated(durationOption: option.analyticsCode))
                    try await clock.sleep(for: .seconds(2))
                    await send(.savedBannerExpired)
                }
                .cancellable(id: CancelID.snoozeBanner, cancelInFlight: true)

            case .resetConfirmed:
                state.showResetConfirm = false
                return .run { _ in
                    await settingsClient.resetToDefaults()
                }

            case .savedBannerExpired:
                state.showSavedBanner = false
                return .none
            }
        }
    }
}

extension SettingsFeature.SnoozeOption {
    /// Computes the absolute snooze expiry date from an injected reference
    /// date and calendar. Copied verbatim from
    /// `SettingsViewModel.SnoozeOption.endDate(referenceDate:calendar:)`
    /// so behaviour — including the rest-of-day midnight calculation that
    /// honours DST transitions — matches the legacy implementation
    /// exactly.
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
