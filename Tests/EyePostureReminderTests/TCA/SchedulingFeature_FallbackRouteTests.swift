import ComposableArchitecture
import ScreenTimeExtensionShared
import XCTest

@testable import EyePostureReminder

/// `TestStore` coverage for the `IPCClient.fallbackRoute(for:)` accessor
/// surface (#900). Verifies `SchedulingFeature.reminderNotificationEffect`
/// reads the prior fallback-routing decision through the dependency
/// boundary and encodes the resolved reason into the `detail` field of
/// the recorded `notificationFallbackDelivered` event — exercising both
/// the present and missing-route branches deterministically without
/// touching the live `UserDefaults(suiteName:)` shared by the extension.
@MainActor
final class SchedulingFeatureFallbackRouteTests: XCTestCase {

    /// Present-route branch: the IPC stub returns a persisted
    /// `.fallbackScheduled` decision, so the reducer records the prior
    /// reason in the `detail` field for downstream analytics consumers.
    func test_reminderNotification_withPresentRoute_recordsPriorReasonInDetail() async {
        let recordedEvents = LockIsolated<[AppGroupIPCEvent]>([])
        let fallbackRouteCalls = LockIsolated<[ReminderType]>([])
        let persistedRoute = FallbackRoute(
            reason: .fallbackScheduled,
            recordedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(interval: 1200, breakDuration: 20)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.ipcClient = IPCClient(
                isTrueInterruptEnabled: { false },
                setTrueInterruptEnabled: { _ in false },
                readSelection: { .empty },
                writeSelection: { _ in false },
                record: { event, _ in recordedEvents.withValue { $0.append(event) } },
                trueInterruptChanges: { .finished },
                selectionChanges: { .finished },
                recentEvents: { [] },
                fallbackRoute: { type in
                    fallbackRouteCalls.withValue { $0.append(type) }
                    return persistedRoute
                }
            )
        }

        await store.send(.notificationRouted(.reminder(.eyes)))
        await store.finish()

        XCTAssertEqual(fallbackRouteCalls.value, [.eyes],
                       "Reminder notification must read the fallback route exactly once for the fired type")
        XCTAssertEqual(recordedEvents.value.count, 1)
        XCTAssertEqual(recordedEvents.value.first?.kind, .notificationFallbackDelivered)
        XCTAssertEqual(recordedEvents.value.first?.reasonRaw,
                       ReminderType.eyes.shieldReason.rawValue)
        XCTAssertEqual(recordedEvents.value.first?.detail,
                       "prior_route=fallback_scheduled",
                       "Present route must be encoded into the recorded event's detail field")
    }

    /// Missing-route branch: the IPC stub returns `nil`, so the reducer
    /// records the fallback-delivered event with a `nil` detail — matching
    /// the pre-#900 baseline and confirming the accessor is still called.
    func test_reminderNotification_withMissingRoute_recordsNilDetail() async {
        let recordedEvents = LockIsolated<[AppGroupIPCEvent]>([])
        let fallbackRouteCalls = LockIsolated<[ReminderType]>([])

        var initial = SchedulingFeature.State()
        initial.postureSettings = ReminderSettings(interval: 1200, breakDuration: 20)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.ipcClient = IPCClient(
                isTrueInterruptEnabled: { false },
                setTrueInterruptEnabled: { _ in false },
                readSelection: { .empty },
                writeSelection: { _ in false },
                record: { event, _ in recordedEvents.withValue { $0.append(event) } },
                trueInterruptChanges: { .finished },
                selectionChanges: { .finished },
                recentEvents: { [] },
                fallbackRoute: { type in
                    fallbackRouteCalls.withValue { $0.append(type) }
                    return nil
                }
            )
        }

        await store.send(.notificationRouted(.reminder(.posture)))
        await store.finish()

        XCTAssertEqual(fallbackRouteCalls.value, [.posture],
                       "Reminder notification must read the fallback route exactly once for the fired type")
        XCTAssertEqual(recordedEvents.value.count, 1)
        XCTAssertEqual(recordedEvents.value.first?.kind, .notificationFallbackDelivered)
        XCTAssertEqual(recordedEvents.value.first?.reasonRaw,
                       ReminderType.posture.shieldReason.rawValue)
        XCTAssertNil(recordedEvents.value.first?.detail,
                     "Missing route must leave the recorded event's detail field nil")
    }

    /// Suppressed-route variant of the present-route branch: the IPC stub
    /// returns a `.fallbackSuppressed` decision, confirming the reducer
    /// faithfully encodes every `FallbackRoute.Reason` raw value rather
    /// than collapsing the surface to a single string.
    func test_reminderNotification_withSuppressedRoute_recordsSuppressedReasonInDetail() async {
        let recordedEvents = LockIsolated<[AppGroupIPCEvent]>([])
        let persistedRoute = FallbackRoute(
            reason: .fallbackSuppressed,
            recordedAt: Date(timeIntervalSince1970: 1_700_000_500)
        )

        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(interval: 1200, breakDuration: 20)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.ipcClient = IPCClient(
                isTrueInterruptEnabled: { false },
                setTrueInterruptEnabled: { _ in false },
                readSelection: { .empty },
                writeSelection: { _ in false },
                record: { event, _ in recordedEvents.withValue { $0.append(event) } },
                trueInterruptChanges: { .finished },
                selectionChanges: { .finished },
                recentEvents: { [] },
                fallbackRoute: { _ in persistedRoute }
            )
        }

        await store.send(.notificationRouted(.reminder(.eyes)))
        await store.finish()

        XCTAssertEqual(recordedEvents.value.first?.detail,
                       "prior_route=fallback_suppressed",
                       "Suppressed route must be encoded with its own raw value, not collapsed to fallback_scheduled")
    }
}
