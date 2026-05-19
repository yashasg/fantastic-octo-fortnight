import ComposableArchitecture
import Foundation
import XCTest

@testable import EyePostureReminder

/// `TestStore` coverage for #902 — `SchedulingFeature.startEffect` must
/// emit exactly one `SessionTimingClient.launchReady(.streamsInstalled)`
/// per cold-launch invocation, once every long-running stream subscription
/// (settings, posture-settings, threshold, pause, IPC, overlay lifecycle)
/// is in-flight.
///
/// The reducer threads the `launchReady` accessor onto the same
/// `SessionTimingClient` that owns `sessionStarted` / `sessionEnded`
/// (#901) so consumers hold a single `@Dependency` for session-timing
/// analytics. These tests install a recording client so the assertion
/// remains deterministic across runs and isolated from `AnalyticsLogger`'s
/// global `os.Logger` sink.
@MainActor
final class SchedulingFeatureLaunchReadinessTests: XCTestCase {

    /// `.start` must dispatch exactly one
    /// `launchReady(.streamsInstalled)` call. Asserts the call appears,
    /// is keyed by `.streamsInstalled`, and is emitted exactly once.
    func test_start_emitsStreamsInstalledLaunchReadyExactlyOnce() async {
        let recorder = LaunchReadinessRecorder()

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.sessionTimingClient = recorder.client()
        }
        store.exhaustivity = .off

        let task = await store.send(.start)
        await task.cancel()
        await store.finish()

        let calls = await recorder.launchReadyCalls
        XCTAssertEqual(
            calls,
            [.streamsInstalled],
            "startEffect must emit exactly one launchReady(.streamsInstalled) per cold launch"
        )
    }

    /// `.stop` followed by a second `.start` must emit a fresh
    /// `launchReady(.streamsInstalled)` — the readiness signal is per
    /// cold-launch installation, not per process lifetime, so a restart
    /// cycle (`stop → start`) must re-emit so downstream consumers
    /// observe the new subscription generation.
    func test_stopThenRestart_reEmitsLaunchReady() async {
        let recorder = LaunchReadinessRecorder()

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.sessionTimingClient = recorder.client()
        }
        store.exhaustivity = .off

        let firstStart = await store.send(.start)
        await firstStart.cancel()
        await store.send(.stop)

        let secondStart = await store.send(.start)
        await secondStart.cancel()
        await store.finish()

        let calls = await recorder.launchReadyCalls
        XCTAssertEqual(
            calls,
            [.streamsInstalled, .streamsInstalled],
            "Each cold-launch installation must re-emit launchReady(.streamsInstalled)"
        )
    }

    /// `.stop` on its own must NOT emit `launchReady` — the signal is
    /// owned by the installation path, not the cancellation path.
    func test_stop_doesNotEmitLaunchReady() async {
        let recorder = LaunchReadinessRecorder()

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.sessionTimingClient = recorder.client()
        }
        store.exhaustivity = .off

        await store.send(.stop)
        await store.finish()

        let calls = await recorder.launchReadyCalls
        XCTAssertTrue(
            calls.isEmpty,
            "stopEffect must not emit launchReady — the signal belongs to startEffect"
        )
    }
}

/// Actor-isolated call recorder for `SessionTimingClient.launchReady` so
/// async closures can append concurrently without data races. Returns a
/// client whose `launchReady` closure forwards every call into the actor
/// for later assertion; `sessionStarted` / `sessionEnded` stay no-op so
/// the recorder stays focused on the readiness contract.
private actor LaunchReadinessRecorder {
    private(set) var launchReadyCalls: [SessionTimingClient.LaunchReadinessReason] = []

    func appendLaunchReady(_ reason: SessionTimingClient.LaunchReadinessReason) {
        launchReadyCalls.append(reason)
    }

    nonisolated func client() -> SessionTimingClient {
        SessionTimingClient(
            sessionStarted: { _, _ in },
            sessionEnded: { _, _ in },
            launchReady: { reason in
                await self.appendLaunchReady(reason)
            }
        )
    }
}
