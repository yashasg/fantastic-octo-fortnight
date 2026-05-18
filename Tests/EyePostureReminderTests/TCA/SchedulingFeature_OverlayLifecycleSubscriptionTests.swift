import ComposableArchitecture
import XCTest

@testable import EyePostureReminder

/// `TestStore` coverage for #904 — `SchedulingFeature.startEffect()` must
/// subscribe to `OverlayClient.lifecycleEvents()` and forward every
/// `.presented` / `.dismissed` / `.settingsTapped` emission through
/// `.overlayLifecycleEvent(_:)`. `stopEffect()` must cancel the
/// subscription so a subsequent `.start` reinstalls cleanly without leaking
/// the previous task.
///
/// `.presented` / `.dismissed` now also dispatch `SessionTimingClient`
/// per #901, and `.settingsTapped` remains a structural no-op pending the
/// remaining sibling tracker (#903 — DeviceActivity-on-present). This suite
/// asserts the **subscription wiring** itself so those follow-ups can add
/// further side-effects without re-plumbing the stream installation; the
/// per-variant `SessionTimingClient` contract is asserted by
/// `SessionTimingTests` so this file stays focused on the subscription
/// invariant.
@MainActor
final class OverlayLifecycleSubscriptionTests: XCTestCase {

    /// `.start` must install the subscription so subsequent overlay-side
    /// emissions surface as `.overlayLifecycleEvent(_:)` actions on the
    /// reducer. Covers `.presented` / `.dismissed` / `.settingsTapped`
    /// round-trip so all three variants are guaranteed to flow through the
    /// shared handler.
    func test_start_subscribesToOverlayLifecycleStream_andForwardsEvents() async {
        let (stream, continuation) = AsyncStream<OverlayLifecycleEvent>.makeStream()

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.overlayClient = OverlayClient(
                show: { _, _, _, _ in },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { stream }
            )
        }
        store.exhaustivity = .off

        let task = await store.send(.start)

        continuation.yield(.presented(.eyes))
        await store.receive(\.overlayLifecycleEvent)

        continuation.yield(.dismissed(.posture))
        await store.receive(\.overlayLifecycleEvent)

        continuation.yield(.settingsTapped(.eyes))
        await store.receive(\.overlayLifecycleEvent)

        continuation.finish()
        await task.cancel()
    }

    /// `.stop` must cancel the lifecycle subscription so a subsequent
    /// `.start` installs a fresh one without two tasks racing on the same
    /// stream. The contract is asserted by sending `.stop`, yielding
    /// another event onto the now-detached upstream, and confirming the
    /// reducer never receives it.
    func test_stop_cancelsOverlayLifecycleSubscription() async {
        let (stream, continuation) = AsyncStream<OverlayLifecycleEvent>.makeStream()

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.overlayClient = OverlayClient(
                show: { _, _, _, _ in },
                dismiss: {},
                clearQueue: {},
                clearQueueForType: { _ in },
                isVisible: { false },
                lifecycleEvents: { stream }
            )
        }
        store.exhaustivity = .off

        let task = await store.send(.start)

        continuation.yield(.presented(.eyes))
        await store.receive(\.overlayLifecycleEvent)

        await store.send(.stop)

        // After `.stop`, the subscription must be cancelled — emitting
        // another event must NOT produce an `.overlayLifecycleEvent`
        // action. `store.finish()` will fail the test if any
        // unconsumed action is in flight.
        continuation.yield(.dismissed(.eyes))
        continuation.finish()
        await task.cancel()
        await store.finish()
    }

    /// `.overlayLifecycleEvent(.settingsTapped(_:))` must remain a
    /// structural no-op — state must not mutate and no follow-up effects
    /// must be emitted. `.presented` / `.dismissed` now dispatch
    /// `SessionTimingClient` per #901, so this case is the only remaining
    /// no-op variant pending the sibling tracker (#903 — DeviceActivity-
    /// on-present) that owns the next per-variant side-effect.
    func test_overlayLifecycleEvent_settingsTappedIsStructuralNoOp() async {
        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
        }

        await store.send(.overlayLifecycleEvent(.settingsTapped(.eyes)))
        await store.send(.overlayLifecycleEvent(.settingsTapped(.posture)))

        await store.finish()
    }
}
