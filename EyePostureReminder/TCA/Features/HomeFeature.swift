import ComposableArchitecture
import Foundation
import UserNotifications

/// Phase 1 reducer (`p0-tca-5` / #668) backing the Home screen.
///
/// Mirrors the read-only behaviour of the existing MVVM `HomeView` so a
/// later Phase 2 issue (`p0-tca-14`) can swap the view body to read from
/// this store without altering observable behaviour.
///
/// Inputs come from the shared dependency clients defined by `p0-tca-2`:
/// `SettingsClient` exposes the eyes-side `ReminderSettings` snapshot/stream
/// **and** an `EnabledFlags` snapshot/stream that tracks the master /
/// per-type toggles (#785). `NotificationClient` exposes the system
/// authorisation status.
@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var settings = ReminderSettings(interval: 0, breakDuration: 0)
        var globalEnabled: Bool = true
        var eyesEnabled: Bool = true
        var postureEnabled: Bool = true
        var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
        var trueInterruptBannerDismissed: Bool = false
        /// Mirrors `AppFeature.State.destination?.settingsSheet != nil`, kept in
        /// sync by `AppFeature` whenever it presents/dismisses the canonical
        /// Settings destination (#814). `HomeView` reads this to suppress the
        /// VoiceOver master-toggle announcement (#287) while Settings is open,
        /// replacing the legacy `@State showSettings` guard.
        var settingsSheetActive: Bool = false

        var statusLocalizationKey: String {
            HomeFeature.statusLocalizationKey(
                globalEnabled: globalEnabled,
                eyesEnabled: eyesEnabled,
                postureEnabled: postureEnabled,
                notificationAuthStatus: notificationAuthStatus
            )
        }

        var shouldShowNotificationRecovery: Bool {
            HomeFeature.shouldShowNotificationRecovery(
                globalEnabled: globalEnabled,
                notificationAuthStatus: notificationAuthStatus
            )
        }

        var shouldShowNoRemindersConfigured: Bool {
            HomeFeature.shouldShowNoRemindersConfigured(
                globalEnabled: globalEnabled,
                eyesEnabled: eyesEnabled,
                postureEnabled: postureEnabled
            )
        }
    }

    enum Action: Equatable {
        case onAppear
        case task
        case settingsTapped
        case dismissTrueInterruptBanner
        case settingsChanged(ReminderSettings)
        case enabledFlagsChanged(EnabledFlags)
        case notificationAuthStatusChanged(UNAuthorizationStatus)
    }

    @Dependency(\.settingsClient) var settingsClient: SettingsClient
    @Dependency(\.notificationClient) var notificationClient: NotificationClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID: Hashable {
        case settingsStream
        case enabledFlagsStream
        case authStatusPoll
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.settings = settingsClient.snapshot()
                let flags = settingsClient.enabledFlagsSnapshot()
                state.globalEnabled = flags.global
                state.eyesEnabled = flags.eyes
                state.postureEnabled = flags.posture
                return .run { send in
                    let status = await notificationClient.authorizationStatus()
                    await send(.notificationAuthStatusChanged(status))
                }

            case .task:
                return .merge(
                    .run { send in
                        for await snapshot in settingsClient.stream() {
                            await send(.settingsChanged(snapshot))
                        }
                    }
                    .cancellable(id: CancelID.settingsStream, cancelInFlight: true),
                    .run { send in
                        for await flags in settingsClient.enabledFlagsStream() {
                            await send(.enabledFlagsChanged(flags))
                        }
                    }
                    .cancellable(id: CancelID.enabledFlagsStream, cancelInFlight: true),
                    .run { [clock, notificationClient] send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            let status = await notificationClient.authorizationStatus()
                            await send(.notificationAuthStatusChanged(status))
                        }
                    }
                    .cancellable(id: CancelID.authStatusPoll, cancelInFlight: true)
                )

            case .settingsTapped:
                // Parent (`AppFeature`) intercepts to present the settings sheet
                // (Phase 2, `p0-tca-11`); the reducer itself has no local effect.
                return .none

            case .dismissTrueInterruptBanner:
                state.trueInterruptBannerDismissed = true
                return .none

            case let .settingsChanged(snapshot):
                state.settings = snapshot
                return .none

            case let .enabledFlagsChanged(flags):
                state.globalEnabled = flags.global
                state.eyesEnabled = flags.eyes
                state.postureEnabled = flags.posture
                return .none

            case let .notificationAuthStatusChanged(status):
                state.notificationAuthStatus = status
                return .none
            }
        }
    }

    static func statusLocalizationKey(
        globalEnabled: Bool,
        eyesEnabled: Bool,
        postureEnabled: Bool,
        notificationAuthStatus: UNAuthorizationStatus
    ) -> String {
        if !globalEnabled {
            return "home.status.paused"
        }
        if shouldShowNoRemindersConfigured(
            globalEnabled: globalEnabled,
            eyesEnabled: eyesEnabled,
            postureEnabled: postureEnabled
        ) {
            return "home.status.noReminders"
        }
        if shouldShowNotificationRecovery(
            globalEnabled: globalEnabled,
            notificationAuthStatus: notificationAuthStatus
        ) {
            return "home.status.notificationsOff"
        }
        return "home.status.active"
    }

    static func shouldShowNotificationRecovery(
        globalEnabled: Bool,
        notificationAuthStatus: UNAuthorizationStatus
    ) -> Bool {
        globalEnabled && notificationAuthStatus == .denied
    }

    static func shouldShowNoRemindersConfigured(
        globalEnabled: Bool,
        eyesEnabled: Bool,
        postureEnabled: Bool
    ) -> Bool {
        globalEnabled && !eyesEnabled && !postureEnabled
    }
}
