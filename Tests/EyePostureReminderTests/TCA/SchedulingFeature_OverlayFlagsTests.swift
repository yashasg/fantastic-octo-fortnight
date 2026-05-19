import ComposableArchitecture
import ScreenTimeExtensionShared
import XCTest

@testable import EyePostureReminder

/// `TestStore` coverage for #899 — `SchedulingFeature` must forward the
/// `hapticsEnabled` and `pauseMediaDuringBreaks` fields carried on
/// `state.settings` into the overlay-presentation request, rather than
/// the hard-coded `false, false` literals the reducer passed before #899.
///
/// `#920` retired the `OverlayClient.show` UIWindow path; the reducer
/// now hands the presentation request to `AppFeature` via
/// `.delegate(.presentOverlay(OverlayPresentationRequest))`. These tests
/// pin both behaviours by asserting on the emitted delegate action with
/// the exact `OverlayPresentationRequest` value.
///
/// Covers both code paths that present an overlay:
///   * `.notificationRouted(.reminder(_))` → `reminderNotificationEffect`
///   * `.thresholdReached(_)` → `thresholdReachedEffect`
@MainActor
final class SchedulingFeatureOverlayFlagsTests: XCTestCase {

    // MARK: - .notificationRouted(.reminder)

    func test_notificationRouted_forwardsHapticsAndPauseMediaToOverlayShow() async {
        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(
            interval: 1200,
            breakDuration: 20,
            hapticsEnabled: true,
            pauseMediaDuringBreaks: true
        )

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
        }

        let expected = OverlayPresentationRequest(
            type: .eyes,
            duration: 20,
            hapticsEnabled: true,
            pauseMediaEnabled: true
        )

        await store.send(.notificationRouted(.reminder(.eyes)))
        await store.receive(.delegate(.presentOverlay(expected)))
        await store.finish()
    }

    func test_notificationRouted_defaultFlagsStillPassFalseFalse() async {
        var initial = SchedulingFeature.State()
        // No haptics/pauseMedia args ⇒ struct defaults to `false`/`false`,
        // matching the pre-#899 literal the reducer used to pass.
        initial.settings = ReminderSettings(interval: 1200, breakDuration: 20)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
        }

        let expected = OverlayPresentationRequest(
            type: .posture,
            duration: 20,
            hapticsEnabled: false,
            pauseMediaEnabled: false
        )

        await store.send(.notificationRouted(.reminder(.posture)))
        await store.receive(.delegate(.presentOverlay(expected)))
        await store.finish()
    }

    // MARK: - .thresholdReached

    func test_thresholdReached_forwardsHapticsAndPauseMediaToOverlayShow() async {
        var initial = SchedulingFeature.State()
        // The test exercises the `.posture` threshold path, so seed the
        // posture-side `ReminderSettings` snapshot (#897) — the reducer
        // now reads `state.settings(for: .posture)` (== `postureSettings`)
        // for break duration, haptics, and pauseMedia.
        initial.postureSettings = ReminderSettings(
            interval: 1200,
            breakDuration: 30,
            hapticsEnabled: true,
            pauseMediaDuringBreaks: true
        )
        initial.notificationAuthStatus = .authorized

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { _, _ in },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
        }

        let expected = OverlayPresentationRequest(
            type: .posture,
            duration: 30,
            hapticsEnabled: true,
            pauseMediaEnabled: true
        )

        await store.send(.thresholdReached(.posture))
        await store.receive(.delegate(.presentOverlay(expected)))
        await store.finish()
    }

    func test_thresholdReached_mixedFlagsAreForwardedIndependently() async {
        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(
            interval: 1200,
            breakDuration: 20,
            hapticsEnabled: true,
            pauseMediaDuringBreaks: false
        )
        initial.notificationAuthStatus = .authorized

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { _, _ in },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
        }

        let expected = OverlayPresentationRequest(
            type: .eyes,
            duration: 20,
            hapticsEnabled: true,
            pauseMediaEnabled: false
        )

        await store.send(.thresholdReached(.eyes))
        await store.receive(.delegate(.presentOverlay(expected)))
        await store.finish()
    }
}
