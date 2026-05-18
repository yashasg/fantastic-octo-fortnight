import ComposableArchitecture
import UserNotifications
import XCTest

@testable import EyePostureReminder

/// Watchdog-recovery TestStore coverage for `SchedulingFeature` —
/// Phase 3 issue `p0-tca-17` (#680).
///
/// Watchdog recovery historically read the App Group IPC log, detected a
/// stale heartbeat, then cancelled every reminder and restarted the
/// schedule. The TCA `SchedulingFeature` reducer (this file's PR is the
/// Phase-3 test rewrite, not the Phase-2 wiring) does not yet expose a
/// watchdog-recovery action because the dependency-client surface required
/// for it (an `IPCClient.recentEvents`-style accessor + a heartbeat clock
/// adapter) has not been added — see the deferral note in the
/// `SchedulingFeature.swift` preamble (watchdog recovery, fallback-routing
/// IPC reads, session-timing analytics, launch-readiness analytics,
/// DeviceActivity scheduling on overlay present, and
/// `OverlayClient.lifecycleEvents`-driven bookkeeping are tracked under
/// `p0-tca-15` follow-ups — history: `#755` Phase E, PR #760).
///
/// The pause-condition + IPC stream effects defined in `startEffect()` are
/// the closest in-scope analogues to "external trigger reschedules" so the
/// covering tests assert those paths here. The watchdog-recovery test
/// itself documents the deferral via `XCTSkip` (tracking issue #892) so
/// the migration ticket can re-enable it once the wider dependency surface
/// lands.
@MainActor
final class SchedulingFeatureWatchdogRecoveryTests: XCTestCase {

    // MARK: - Watchdog-recovery deferral

    /// Records the deferral. Once the Phase-2 dependency surface lands
    /// (`IPCClient.recentEvents` accessor + heartbeat clock adapter +
    /// `SchedulingFeature.watchdogRecoveryTriggered` action — tracking
    /// issue #892), replace this `XCTSkip` with the behavioural-parity
    /// test against the new `.watchdogRecoveryTriggered` action.
    func test_watchdogRecovery_deferredToPhase2() throws {
        try XCTSkipIf(true, """
            SchedulingFeature lacks watchdog-recovery surface in Phase 1
            (see the deferral note in the SchedulingFeature.swift preamble).
            Re-enable once an IPCClient.recentEvents accessor + heartbeat
            clock adapter ship so the legacy watchdog-heartbeat coverage
            can be ported into a behavioural-parity test.
            Tracking: GitLab issue #892 (squad:basher, priority:p2,
            type:feature).
            """)
    }

    // MARK: - IPC stream → reschedule (closest in-scope analogue)

    /// `startEffect()` installs an `ipcStream` subscriber that fires
    /// `.scheduleReminders` on every emitted true-interrupt change. This is
    /// the closest currently-implemented analogue to a watchdog-driven
    /// "external signal forces a reschedule" path. Verifies the contract by
    /// driving the stream from the test body and asserting the resulting
    /// `.scheduleReminders` action.
    func test_ipcStream_trueInterruptChange_triggersScheduleReminders() async {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.ipcClient = IPCClient(
                isTrueInterruptEnabled: { false },
                setTrueInterruptEnabled: { _ in false },
                readSelection: { .empty },
                writeSelection: { _ in false },
                record: { _, _ in },
                trueInterruptChanges: { stream },
                selectionChanges: { .finished }
            )
        }
        store.exhaustivity = .off

        await store.send(.start)

        continuation.yield(true)
        await store.receive(\.scheduleReminders)

        // Tear down the long-lived streams so `store.finish()` doesn't trip.
        continuation.finish()
        await store.send(.stop)
    }

    // MARK: - Pause stream → pauseConditionChanged (closest in-scope analogue)

    /// `startEffect()` also installs a `pauseStream` subscriber that maps
    /// every emitted `Bool` onto `.pauseConditionChanged`. This is the
    /// in-scope analogue to the "external resume / pause condition forces
    /// a state transition" guard rail. Verifies the routing by yielding
    /// from the test body.
    func test_pauseStream_pauseConditionChange_routesToReducer() async {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let pausedAll = LockIsolated(0)

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.pauseConditionClient = PauseConditionClient(
                isPaused: { false },
                pauseChanges: { stream },
                startMonitoring: {},
                stopMonitoring: {}
            )
            $0.screenTimeTrackerClient = ScreenTimeTrackerClient(
                setThreshold: { _, _ in },
                enableTracking: { _ in },
                disableTracking: { _ in },
                pauseAll: { pausedAll.withValue { $0 += 1 } },
                resumeAll: {},
                reset: { _ in },
                thresholdReached: { .finished }
            )
            $0.overlayClient = OverlayClient(
                show: { _, _, _, _ in },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { .finished }
            )
        }
        store.exhaustivity = .off

        await store.send(.start)

        continuation.yield(true)
        await store.receive(\.pauseConditionChanged) {
            $0.isPausedByConditions = true
        }

        continuation.finish()
        await store.send(.stop)

        XCTAssertEqual(pausedAll.value, 1,
                       "pauseConditionChanged(true) must call trackerClient.pauseAll")
    }
}
