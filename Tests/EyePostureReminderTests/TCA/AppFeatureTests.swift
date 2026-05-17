import ComposableArchitecture
import SwiftUI
import XCTest

@testable import EyePostureReminder

/// `TestStore` coverage for `AppFeature` introduced by Phase 2 issue
/// `p0-tca-11` (#674) — the wiring step that gives `EyePostureReminderApp`
/// a real root `Store`.
///
/// Phase-1 child reducers (`HomeFeature`, `SettingsFeature`,
/// `OnboardingFeature`, `SchedulingFeature`) are scoped into the body but
/// none of their actions are exercised here — those reducers are covered by
/// the dedicated `*FeatureTests` rewrites tracked under `p0-tca-17` … `-20`.
/// Every dependency client used by Phase-1 reducers is still overridden so
/// `liveValue` factories that touch `UNUserNotificationCenter.current()` /
/// `UIApplication` are never evaluated when the test bundle constructs the
/// store.
@MainActor
final class AppFeatureTests: XCTestCase {

    // MARK: - Test helpers

    /// Builds a `TestStore` with every dependency client stubbed to a no-op
    /// so child-reducer effects (when accidentally triggered) cannot reach
    /// production singletons or fail with a `liveValue` crash inside the
    /// SwiftPM xctest bundle.
    private func makeStore(
        initialState: AppFeature.State = AppFeature.State(),
        overlayClient overlayClientOverride: OverlayClient? = nil
    ) -> TestStoreOf<AppFeature> {
        TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.settingsClient = SettingsClient(
                snapshot: { ReminderSettings(interval: 0, breakDuration: 0) },
                stream: { .finished },
                postureSnapshot: { ReminderSettings(interval: 0, breakDuration: 0) },
                postureStream: { .finished },
                enabledFlagsSnapshot: { .allEnabled },
                enabledFlagsStream: { .finished },
                updateGlobalEnabled: { _ in },
                updateEyesEnabled: { _ in },
                updatePostureEnabled: { _ in },
                updateEyesInterval: { _ in },
                updatePostureInterval: { _ in },
                updateEyesBreakDuration: { _ in },
                updatePostureBreakDuration: { _ in },
                updatePauseMediaDuringBreaks: { _ in },
                updateHapticsEnabled: { _ in },
                updatePauseDuringFocus: { _ in },
                updatePauseWhileDriving: { _ in },
                updateNotificationFallbackEnabled: { _ in },
                setSnoozedUntil: { _ in },
                setSnoozeCount: { _ in },
                resetToDefaults: {}
            )
            $0.notificationClient = NotificationClient(
                requestAuthorization: { _ in false },
                authorizationStatus: { .notDetermined },
                add: { _ in },
                removePending: { _ in },
                removeAllPending: {},
                pendingRequests: { [] },
                deliveredNotifications: { [] }
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _ in },
                rescheduleReminder: { _, _ in },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
            $0.overlayClient = overlayClientOverride ?? OverlayClient(
                show: { _, _, _, _ in },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { .finished }
            )
            $0.screenTimeTrackerClient = ScreenTimeTrackerClient(
                setThreshold: { _, _ in },
                enableTracking: { _ in },
                disableTracking: { _ in },
                pauseAll: {},
                resumeAll: {},
                reset: { _ in },
                thresholdReached: { .finished }
            )
            $0.pauseConditionClient = PauseConditionClient(
                isPaused: { false },
                pauseChanges: { .finished },
                startMonitoring: {},
                stopMonitoring: {}
            )
            $0.ipcClient = IPCClient(
                isTrueInterruptEnabled: { false },
                setTrueInterruptEnabled: { _ in false },
                readSelection: { .empty },
                writeSelection: { _ in false },
                record: { _, _ in },
                trueInterruptChanges: { .finished },
                selectionChanges: { .finished }
            )
            $0.deviceActivityMonitorClient = DeviceActivityMonitorClient(
                schedule: { _, _ in },
                cancel: { _ in }
            )
            $0.screenTimeAuthorizationClient = ScreenTimeAuthorizationClient()
            $0.analyticsClient = AnalyticsClient(log: { _ in })
        }
    }

    // MARK: - Default state

    /// `AppFeature.State()` must match the persistence-free defaults
    /// `EyePostureReminderApp.init` overlays its `UserDefaults` bridge on.
    func test_initialState_matchesDocumentedDefaults() {
        let state = AppFeature.State()

        XCTAssertFalse(state.hasSeenOnboarding,
                       "hasSeenOnboarding must default to false so first launch shows onboarding")
        XCTAssertNil(state.overlay,
                     "overlay presentation must default to nil")
        XCTAssertNil(state.destination,
                     "destination presentation must default to nil")
    }

    // MARK: - hasSeenOnboardingChanged (introduced by #674)

    /// Sending `.hasSeenOnboardingChanged(true)` toggles `state.hasSeenOnboarding`
    /// without producing a follow-up effect — the bridge from
    /// `@AppStorage(AppStorageKey.hasSeenOnboarding)` written by
    /// `OnboardingView.markOnboardingComplete` relies on this exact pure write
    /// so `RootView` flips from `OnboardingView` → `HomeView`.
    func test_hasSeenOnboardingChanged_true_setsStateAndProducesNoEffect() async {
        let store = makeStore()

        await store.send(.hasSeenOnboardingChanged(true)) {
            $0.hasSeenOnboarding = true
        }
    }

    /// Sending `.hasSeenOnboardingChanged(false)` reverses the gate so a UI
    /// test reset / "factory reset" path can drop the user back into onboarding
    /// without a launch.
    func test_hasSeenOnboardingChanged_false_clearsState() async {
        var initial = AppFeature.State()
        initial.hasSeenOnboarding = true
        let store = makeStore(initialState: initial)

        await store.send(.hasSeenOnboardingChanged(false)) {
            $0.hasSeenOnboarding = false
        }
    }

    /// Sending the same value as the current state is still applied (the
    /// reducer does not early-return) — `RootView` guards against a
    /// redundant dispatch but the reducer itself stays idempotent.
    func test_hasSeenOnboardingChanged_idempotent_keepsValueStable() async {
        var initial = AppFeature.State()
        initial.hasSeenOnboarding = true
        let store = makeStore(initialState: initial)

        // Same value: no state delta; no effect.
        await store.send(.hasSeenOnboardingChanged(true))
    }

    // MARK: - scenePhaseChanged (Phase-2 #676 wiring)

    /// `.scenePhaseChanged(.active)` forwards to `SchedulingFeature` as a
    /// merged `.foregroundTransition` + `.clearExpiredSnoozeIfNeeded` so the
    /// reducer owns the legacy `coordinator.handleForegroundTransition()` /
    /// snooze-clearing path that previously lived in `EyePostureReminderApp`.
    /// Use non-exhaustive matching because deep `SchedulingFeature` parity
    /// is owned by `p0-tca-17` (#680).
    func test_scenePhaseChanged_active_forwardsForegroundAndSnoozeClear() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.scenePhaseChanged(.active))

        await store.receive(\.scheduling.foregroundTransition)
        await store.receive(\.scheduling.clearExpiredSnoozeIfNeeded)
    }

    /// `.scenePhaseChanged(.background)` forwards to
    /// `SchedulingFeature.backgroundTransition` so analytics + cleanup happen
    /// inside the reducer, replacing `coordinator.appWillResignActive()`.
    func test_scenePhaseChanged_background_forwardsBackgroundTransition() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.scenePhaseChanged(.background))

        await store.receive(\.scheduling.backgroundTransition)
    }

    /// `.scenePhaseChanged(.inactive)` (and any non-active/background phase)
    /// must remain a pure no-op: SwiftUI fires `.inactive` on every brief
    /// interruption (control center, task switcher) and the reducer must not
    /// run foreground/background side-effects on those.
    func test_scenePhaseChanged_inactive_isNoOp() async {
        let store = makeStore()
        await store.send(.scenePhaseChanged(.inactive))
    }

    // MARK: - notificationRouted (Phase-2 bridge in #675)

    /// `.notificationRouted` is forwarded to `.scheduling(.notificationRouted)`
    /// so `SchedulingFeature.notificationRoutedEffect` runs the reminder /
    /// snoozeWake / ignore paths. Behavioural parity for the inner reducer
    /// effects is owned by `p0-tca-17` (#680) — these tests only assert the
    /// AppFeature → SchedulingFeature wiring contract using non-exhaustive
    /// matching so deep effect chains in `SchedulingFeature` don't have to be
    /// duplicated here.
    func test_notificationRouted_reminder_forwardsToScheduling() async {
        let store = makeStore()
        store.exhaustivity = .off
        await store.send(.notificationRouted(.reminder(.eyes)))
        await store.receive(\.scheduling.notificationRouted)
    }

    func test_notificationRouted_snoozeWake_forwardsToScheduling() async {
        let store = makeStore()
        store.exhaustivity = .off
        await store.send(.notificationRouted(.snoozeWake))
        await store.receive(\.scheduling.notificationRouted)
    }

    func test_notificationRouted_ignore_forwardsToScheduling() async {
        let store = makeStore()
        store.exhaustivity = .off
        await store.send(.notificationRouted(.ignore))
        await store.receive(\.scheduling.notificationRouted)
    }

    /// #737: When `state.scheduling.settings` is seeded with a non-zero
    /// `breakDuration` (mirroring `EyePostureReminderApp.init()`'s synchronous
    /// `SettingsStore.eyesSnapshotFromUserDefaults` read), the seeded value
    /// must survive `.notificationRouted(.reminder(.eyes))` reduction so
    /// `SchedulingFeature.reminderNotificationEffect` calls
    /// `overlayClient.show` with the correct duration. Pre-#737 the seed was
    /// always `(interval: 0, breakDuration: 0)` regardless of UserDefaults,
    /// so the UI-test backdoor would intermittently fire `overlayClient.show(
    /// type, 0, …)` and the overlay would auto-dismiss before any UITest
    /// could interact with it.
    func test_notificationRouted_preservesSeededSchedulingSettings() async {
        var initial = AppFeature.State()
        initial.scheduling.settings = ReminderSettings(interval: 1200, breakDuration: 600)
        let store = makeStore(initialState: initial)
        store.exhaustivity = .off

        XCTAssertEqual(store.state.scheduling.settings.breakDuration, 600,
                       "Seed must be observable on the initial state before any action runs")

        await store.send(.notificationRouted(.reminder(.eyes)))
        await store.receive(\.scheduling.notificationRouted)

        XCTAssertEqual(store.state.scheduling.settings.breakDuration, 600,
                       "Seeded breakDuration must survive the action chain — this is the "
                       + "value SchedulingFeature.reminderNotificationEffect feeds into "
                       + "overlayClient.show(type, duration, _, _).")
        XCTAssertEqual(store.state.scheduling.settings.interval, 1200,
                       "Seeded interval must also survive — thresholdReachedEffect guards "
                       + "on `interval > 0` and would silently no-op otherwise.")
    }

    // MARK: - Overlay presentation cleanup (#738 — two-phase dismiss completion)

    /// AppFeature owns the `@Presents var overlay` slot. When the child
    /// `OverlayFeature` finishes its two-phase dismiss chain (issue #738) by
    /// emitting `.dismissed`, the parent reducer must clear
    /// `state.overlay = nil` so `RootView`'s
    /// `.fullScreenCover(item: $store.scope(state: \.$overlay, …))` tears
    /// down the cover. Without this nil write the cover would stay on screen
    /// until something else clobbers the slot.
    func test_overlayPresentedDismissed_clearsOverlayState() async {
        var initial = AppFeature.State()
        initial.overlay = OverlayFeature.State(type: .eyes, duration: 10)
        let store = makeStore(initialState: initial)
        store.exhaustivity = .off

        await store.send(.overlay(.presented(.dismissed))) {
            $0.overlay = nil
        }
    }

    /// Defence-in-depth: a child action that is *not* `.dismissed` must
    /// leave the overlay slot intact so the cover stays on screen while the
    /// reducer handles intermediate phases (`.dismissTapped`,
    /// `.dismissAnimationCompleted`).
    func test_overlayPresentedDismissTapped_doesNotClearOverlayState() async {
        var initial = AppFeature.State()
        initial.overlay = OverlayFeature.State(type: .eyes, duration: 10)
        let store = makeStore(initialState: initial)
        store.exhaustivity = .off

        // The child reducer flips `isDismissing`; the parent leaves the
        // slot untouched so the overlay window stays alive while the view
        // animates the exit transition.
        await store.send(.overlay(.presented(.dismissTapped))) {
            $0.overlay?.isDismissing = true
        }
        XCTAssertNotNil(
            store.state.overlay,
            "AppFeature must not clear overlay state until .dismissed arrives"
        )
    }

    // MARK: - Destination state Equatable conformance

    /// `AppFeature.Destination.State` synthesised `Equatable` is required by
    /// `@Presents` / `ifLet(\.$destination, action: \.destination)` to detect
    /// presentation changes. Verifies both cases compare correctly.
    func test_destinationState_equatable_settingsSheetCases_areEqual() {
        let lhs: AppFeature.Destination.State = .settingsSheet(SettingsFeature.State())
        let rhs: AppFeature.Destination.State = .settingsSheet(SettingsFeature.State())

        XCTAssertEqual(lhs, rhs,
                       "Two .settingsSheet destinations with equal payloads must compare equal")
    }

    func test_destinationState_equatable_appCategoryPickerCases_areEqual() {
        let lhs: AppFeature.Destination.State = .appCategoryPicker(AppCategoryPickerFeature.State())
        let rhs: AppFeature.Destination.State = .appCategoryPicker(AppCategoryPickerFeature.State())

        XCTAssertEqual(lhs, rhs,
                       "Two .appCategoryPicker destinations with equal payloads must compare equal")
    }

    func test_destinationState_equatable_differentCases_areUnequal() {
        let lhs: AppFeature.Destination.State = .settingsSheet(SettingsFeature.State())
        let rhs: AppFeature.Destination.State = .appCategoryPicker(AppCategoryPickerFeature.State())

        XCTAssertNotEqual(lhs, rhs,
                          ".settingsSheet and .appCategoryPicker must compare unequal")
    }

    // MARK: - NotificationRoute typealias re-export

    /// `AppFeature.NotificationRoute` is re-exported from
    /// `AppDelegate.NotificationRoute` — verify the typealias resolves
    /// transparently so callers can refer to it without the `AppDelegate.`
    /// qualifier.
    func test_notificationRouteTypealias_resolvesToAppDelegateRoute() {
        let route: AppFeature.NotificationRoute = .reminder(.eyes)
        let delegateRoute: AppDelegate.NotificationRoute = route

        XCTAssertEqual(route, delegateRoute,
                       "AppFeature.NotificationRoute must be an alias of AppDelegate.NotificationRoute")
    }

    // MARK: - Overlay → Settings handoff (#786)

    /// `.overlaySettingsRequested` is the reducer-side replacement for the
    /// legacy `AppCoordinator` handoff: when the user taps the "Settings"
    /// affordance inside the in-break overlay, the reducer must write
    /// `openSettingsOnLaunch = true` to the shared `UserDefaults` so
    /// `HomeView`'s `.onChangeCompat(of: openSettingsOnLaunch)` presents
    /// the Settings sheet on the next layout pass. Regression coverage for
    /// #786 — pre-fix the tap was a no-op because no reducer consumed
    /// `OverlayClient.lifecycleEvents()`'s `.settingsTapped` emissions.
    func test_overlaySettingsRequested_writesOpenSettingsOnLaunchFlag() async {
        UserDefaults.standard.removeObject(forKey: AppStorageKey.openSettingsOnLaunch)
        defer {
            UserDefaults.standard.removeObject(forKey: AppStorageKey.openSettingsOnLaunch)
        }
        XCTAssertFalse(
            UserDefaults.standard.bool(forKey: AppStorageKey.openSettingsOnLaunch),
            "Precondition: the AppStorage flag must start cleared so we can "
            + "observe the reducer's write."
        )

        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.overlaySettingsRequested(.eyes))
        await store.finish(timeout: NSEC_PER_SEC)

        XCTAssertTrue(
            UserDefaults.standard.bool(forKey: AppStorageKey.openSettingsOnLaunch),
            ".overlaySettingsRequested must flip openSettingsOnLaunch to true "
            + "so HomeView presents the Settings sheet (#786)."
        )
    }

    /// `.onAppear` subscribes to `OverlayClient.lifecycleEvents()` and
    /// forwards every `.settingsTapped` emission as
    /// `.overlaySettingsRequested(type)`. Without this wiring the in-overlay
    /// "Settings" link is a dead-end after the MVVM → TCA migration removed
    /// `AppCoordinator` (#755). Regression coverage for #786.
    func test_onAppear_forwardsOverlaySettingsTappedEventsToReducer() async {
        let (lifecycleStream, lifecycleContinuation) =
            AsyncStream<OverlayLifecycleEvent>.makeStream()
        let store = makeStore(
            overlayClient: OverlayClient(
                show: { _, _, _, _ in },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { lifecycleStream }
            )
        )
        store.exhaustivity = .off

        // Clean the AppStorage write side-effect that fires when the reducer
        // handles `.overlaySettingsRequested`.
        UserDefaults.standard.removeObject(forKey: AppStorageKey.openSettingsOnLaunch)
        defer {
            UserDefaults.standard.removeObject(forKey: AppStorageKey.openSettingsOnLaunch)
        }

        let task = await store.send(.onAppear)
        await store.receive(\.scheduling.start)

        // Unrelated lifecycle events must NOT be forwarded.
        lifecycleContinuation.yield(.presented(.eyes))
        lifecycleContinuation.yield(.dismissed(.eyes))

        // The settings-tap is the one event the reducer must convert.
        lifecycleContinuation.yield(.settingsTapped(.posture))
        await store.receive(\.overlaySettingsRequested) { _ in }

        lifecycleContinuation.finish()
        await task.cancel()
    }

    // MARK: - Settings destination handoff (#814)

    /// `.home(.settingsTapped)` is the canonical user-driven action for
    /// opening the Settings sheet from `HomeView` (gear toolbar button,
    /// `TrueInterruptSkippedBanner`/`Pill` setup CTAs, "no reminders"
    /// banner). Pre-#814 `HomeView` owned a local `@State showSettings`
    /// bridge plus a private `SettingsSheet` wrapper; the parent reducer
    /// must now write `state.destination = .settingsSheet(...)` itself so
    /// presentation flows through the canonical `RootView` graph and the
    /// store lifetime tracks the destination slot.
    func test_homeSettingsTapped_presentsSettingsSheetDestination() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.home(.settingsTapped)) {
            $0.destination = .settingsSheet(SettingsFeature.State())
            $0.home.settingsSheetActive = true
        }
    }

    /// `.openSettingsSheetRequested` is the non-`HomeView` entry point used
    /// by `RootView`'s `@AppStorage(openSettingsOnLaunch)` observer. It
    /// routes both the `.overlaySettingsRequested` UserDefaults handoff
    /// (#786) and `OnboardingView.finishOnboardingAndCustomize()` through
    /// the reducer so the destination write never depends on a SwiftUI
    /// `@State` bridge inside `HomeView` (#814 acceptance).
    func test_openSettingsSheetRequested_presentsSettingsSheetDestination() async {
        let store = makeStore()
        store.exhaustivity = .off

        await store.send(.openSettingsSheetRequested) {
            $0.destination = .settingsSheet(SettingsFeature.State())
            $0.home.settingsSheetActive = true
        }
    }

    /// `state.home.settingsSheetActive` mirrors the canonical destination
    /// presence so `HomeView`'s `.onChangeCompat(of: store.globalEnabled)`
    /// guard (#287 — VoiceOver master-toggle announcement) can suppress
    /// while Settings is open without keeping a `@State showSettings`
    /// bridge. `.destination(.dismiss)` must clear the mirror so the
    /// announcement re-arms after the sheet tears down.
    func test_destinationDismiss_clearsHomeSettingsSheetActive() async {
        var initial = AppFeature.State()
        initial.destination = .settingsSheet(SettingsFeature.State())
        initial.home.settingsSheetActive = true
        let store = makeStore(initialState: initial)
        store.exhaustivity = .off

        await store.send(.destination(.dismiss)) {
            $0.destination = nil
            $0.home.settingsSheetActive = false
        }
    }
}
