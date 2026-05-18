import ComposableArchitecture
import ScreenTimeExtensionShared
import XCTest

@testable import EyePostureReminder

/// `TestStore` coverage for #899 — `SchedulingFeature` must forward the
/// `hapticsEnabled` and `pauseMediaDuringBreaks` fields carried on
/// `state.settings` into the `OverlayClient.show` call, rather than the
/// hard-coded `false, false` literals the reducer passed before #899.
///
/// Covers both code paths that present an overlay:
///   * `.notificationRouted(.reminder(_))` → `reminderNotificationEffect`
///   * `.thresholdReached(_)` → `thresholdReachedEffect`
@MainActor
final class SchedulingFeatureOverlayFlagsTests: XCTestCase {

    private typealias ShowArgs = (
        type: ReminderType,
        duration: TimeInterval,
        haptics: Bool,
        pauseMedia: Bool
    )

    // MARK: - .notificationRouted(.reminder)

    func test_notificationRouted_forwardsHapticsAndPauseMediaToOverlayShow() async {
        let shownOverlays = LockIsolated<[ShowArgs]>([])

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
            $0.overlayClient = OverlayClient(
                show: { type, duration, haptics, pauseMedia in
                    shownOverlays.withValue {
                        $0.append((type, duration, haptics, pauseMedia))
                    }
                },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { .finished }
            )
        }

        await store.send(.notificationRouted(.reminder(.eyes)))
        await store.finish()

        XCTAssertEqual(shownOverlays.value.count, 1)
        let call = try? XCTUnwrap(shownOverlays.value.first)
        XCTAssertEqual(call?.type, .eyes)
        XCTAssertEqual(call?.duration, 20)
        XCTAssertEqual(
            call?.haptics, true,
            "Reducer must forward state.settings.hapticsEnabled instead of "
            + "the pre-#899 `false` literal"
        )
        XCTAssertEqual(
            call?.pauseMedia, true,
            "Reducer must forward state.settings.pauseMediaDuringBreaks instead "
            + "of the pre-#899 `false` literal"
        )
    }

    func test_notificationRouted_defaultFlagsStillPassFalseFalse() async {
        let shownOverlays = LockIsolated<[ShowArgs]>([])

        var initial = SchedulingFeature.State()
        // No haptics/pauseMedia args ⇒ struct defaults to `false`/`false`,
        // matching the pre-#899 literal the reducer used to pass.
        initial.settings = ReminderSettings(interval: 1200, breakDuration: 20)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.overlayClient = OverlayClient(
                show: { type, duration, haptics, pauseMedia in
                    shownOverlays.withValue {
                        $0.append((type, duration, haptics, pauseMedia))
                    }
                },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { .finished }
            )
        }

        await store.send(.notificationRouted(.reminder(.posture)))
        await store.finish()

        XCTAssertEqual(shownOverlays.value.count, 1)
        XCTAssertEqual(shownOverlays.value.first?.haptics, false)
        XCTAssertEqual(shownOverlays.value.first?.pauseMedia, false)
    }

    // MARK: - .thresholdReached

    func test_thresholdReached_forwardsHapticsAndPauseMediaToOverlayShow() async {
        let shownOverlays = LockIsolated<[ShowArgs]>([])

        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(
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
            $0.overlayClient = OverlayClient(
                show: { type, duration, haptics, pauseMedia in
                    shownOverlays.withValue {
                        $0.append((type, duration, haptics, pauseMedia))
                    }
                },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { .finished }
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _ in },
                rescheduleReminder: { _, _ in },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
        }

        await store.send(.thresholdReached(.posture))
        await store.finish()

        XCTAssertEqual(shownOverlays.value.count, 1)
        XCTAssertEqual(shownOverlays.value.first?.type, .posture)
        XCTAssertEqual(shownOverlays.value.first?.duration, 30)
        XCTAssertEqual(shownOverlays.value.first?.haptics, true)
        XCTAssertEqual(shownOverlays.value.first?.pauseMedia, true)
    }

    func test_thresholdReached_mixedFlagsAreForwardedIndependently() async {
        let shownOverlays = LockIsolated<[ShowArgs]>([])

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
            $0.overlayClient = OverlayClient(
                show: { type, duration, haptics, pauseMedia in
                    shownOverlays.withValue {
                        $0.append((type, duration, haptics, pauseMedia))
                    }
                },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { .finished }
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _ in },
                rescheduleReminder: { _, _ in },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
        }

        await store.send(.thresholdReached(.eyes))
        await store.finish()

        XCTAssertEqual(shownOverlays.value.count, 1)
        XCTAssertEqual(shownOverlays.value.first?.haptics, true)
        XCTAssertEqual(
            shownOverlays.value.first?.pauseMedia, false,
            "Each overlay flag must be forwarded independently — toggling "
            + "haptics on while leaving pauseMedia off must not enable both"
        )
    }
}
