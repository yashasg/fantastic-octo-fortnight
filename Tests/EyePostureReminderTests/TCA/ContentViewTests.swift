import ComposableArchitecture
import SwiftUI
import UIKit
import XCTest

@testable import EyePostureReminder

/// `ContentView` body coverage — exercises both the onboarding-gated branch
/// and the home branch wired up by Phase 2 issue `p0-tca-11` (#674).
///
/// `ContentView` requires both a TCA `Store` (root state) and the legacy
/// `@EnvironmentObject` graph (`SettingsStore` + `AppCoordinator`) because
/// `HomeView` / `OnboardingView` have not yet been migrated off MVVM
/// (`p0-tca-14` / #677).
@MainActor
final class ContentViewTests: XCTestCase {

    // MARK: - Helpers

    /// Constructs a TCA `Store` for `ContentView` whose dependency graph is
    /// safe in the SwiftPM xctest bundle (no `UNUserNotificationCenter`
    /// access, no overlay window manipulation).
    private func makeStore(hasSeenOnboarding: Bool) -> StoreOf<AppFeature> {
        var initial = AppFeature.State()
        initial.hasSeenOnboarding = hasSeenOnboarding
        return Store(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.settingsClient = SettingsClient(
                snapshot: { ReminderSettings(interval: 0, breakDuration: 0) },
                stream: { .finished },
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
            $0.overlayClient = OverlayClient(
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

    /// Builds an `AppCoordinator` whose collaborators are all mock doubles —
    /// matches `PreviewTests.makeTestCoordinator()`.
    private func makeTestCoordinator() -> AppCoordinator {
        AppCoordinator(
            scheduler: MockReminderScheduler(),
            notificationCenter: MockNotificationCenter(),
            overlayManager: MockOverlayPresenting(),
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider(),
            ipcStore: MockAppGroupIPCRecorder()
        )
    }

    // MARK: - Body description coverage

    /// Verifies that `ContentView`'s body type can be described — exercises
    /// the `WithPerceptionTracking` closure construction and the surrounding
    /// modifier stack without depending on a UIKit host.
    func test_contentView_body_isNonEmptyDescription_whenOnboardingNotSeen() {
        let store = makeStore(hasSeenOnboarding: false)
        let view = ContentView(store: store)

        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
                       "ContentView.body must produce a non-empty description in the onboarding-gated branch")
    }

    func test_contentView_body_isNonEmptyDescription_whenOnboardingSeen() {
        let store = makeStore(hasSeenOnboarding: true)
        let view = ContentView(store: store)

        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
                       "ContentView.body must produce a non-empty description in the home branch")
    }

    // MARK: - Store wiring contract

    /// The store passed in is the only source of truth for the gate — flipping
    /// `hasSeenOnboarding` on the underlying state must be observable through
    /// the store the view holds.
    func test_contentView_store_reflectsHasSeenOnboardingTrue() {
        let store = makeStore(hasSeenOnboarding: true)
        let view = ContentView(store: store)

        XCTAssertTrue(view.store.hasSeenOnboarding,
                      "ContentView must read its gate from the injected store's state")
    }

    func test_contentView_store_reflectsHasSeenOnboardingFalse() {
        let store = makeStore(hasSeenOnboarding: false)
        let view = ContentView(store: store)

        XCTAssertFalse(view.store.hasSeenOnboarding,
                       "ContentView must read the false branch from the injected store's state")
    }

    // MARK: - hasSeenOnboardingChanged dispatch contract

    /// Sending `.hasSeenOnboardingChanged(true)` to the wired store flips
    /// `store.hasSeenOnboarding` — proves the bridge `ContentView`'s
    /// `.onChange` closure relies on actually mutates state.
    func test_contentView_storeDispatch_flipsGateForward() {
        let store = makeStore(hasSeenOnboarding: false)

        store.send(.hasSeenOnboardingChanged(true))

        XCTAssertTrue(store.hasSeenOnboarding,
                      "Sending hasSeenOnboardingChanged(true) must flip the gate in the wired store")
    }

    func test_contentView_storeDispatch_flipsGateBackward() {
        let store = makeStore(hasSeenOnboarding: true)

        store.send(.hasSeenOnboardingChanged(false))

        XCTAssertFalse(store.hasSeenOnboarding,
                       "Sending hasSeenOnboardingChanged(false) must restore the onboarding gate")
    }
}
