import ComposableArchitecture
import ScreenTimeExtensionShared
import XCTest

@testable import EyePostureReminder

/// Surface-level coverage for the `IPCClient` selection accessors added in
/// `p0-tca-15` (#678) and the watchdog-recovery `recentEvents` accessor
/// added in Phase 2 follow-up #892. These tests assert the dependency
/// contract reducers rely on — they do not exercise the live
/// `AppGroupIPCStore`-backed adapter (covered by `AppGroupIPCStoreTests`),
/// only that the closure-typed surface routes inputs to the configured
/// implementation.
@MainActor
final class IPCClientSurfaceTests: XCTestCase {

    func test_overriddenClient_routesAllAccessors() async {
        let recorded = LockIsolated<[String]>([])
        let snapshot = AppGroupSelectionSnapshot(
            categoryCount: 1,
            appCount: 2,
            lastUpdated: Date(timeIntervalSince1970: 1_000)
        )
        let watchdogEvent = AppGroupIPCEvent(
            kind: .watchdogHeartbeat,
            timestamp: Date(timeIntervalSince1970: 2_000),
            detail: "device_activity_interval_started"
        )
        let (selectionStream, selectionContinuation) =
            AsyncStream<AppGroupSelectionSnapshot>.makeStream()
        let (toggleStream, toggleContinuation) = AsyncStream<Bool>.makeStream()
        let client = IPCClient(
            isTrueInterruptEnabled: {
                recorded.withValue { $0.append("isTrueInterruptEnabled") }
                return true
            },
            setTrueInterruptEnabled: { value in
                recorded.withValue { $0.append("setTrueInterruptEnabled(\(value))") }
                return true
            },
            readSelection: {
                recorded.withValue { $0.append("readSelection") }
                return snapshot
            },
            writeSelection: { value in
                recorded.withValue { $0.append("writeSelection(\(value.appCount))") }
                return true
            },
            record: { event, context in
                recorded.withValue {
                    $0.append("record(\(event.kind.rawValue), \(context ?? "nil"))")
                }
            },
            trueInterruptChanges: { toggleStream },
            selectionChanges: { selectionStream },
            recentEvents: {
                recorded.withValue { $0.append("recentEvents") }
                return [watchdogEvent]
            },
            fallbackRoute: { _ in nil }
        )

        let isEnabled = await client.isTrueInterruptEnabled()
        let didSet = await client.setTrueInterruptEnabled(true)
        let readBack = await client.readSelection()
        let didWrite = await client.writeSelection(snapshot)
        await client.record(AppGroupIPCEvent(kind: .shieldStarted), "ctx")
        let events = await client.recentEvents()

        toggleContinuation.yield(true)
        toggleContinuation.finish()
        var toggleValues: [Bool] = []
        for await value in client.trueInterruptChanges() {
            toggleValues.append(value)
        }

        selectionContinuation.yield(snapshot)
        selectionContinuation.finish()
        var selectionValues: [AppGroupSelectionSnapshot] = []
        for await value in client.selectionChanges() {
            selectionValues.append(value)
        }

        XCTAssertTrue(isEnabled)
        XCTAssertTrue(didSet)
        XCTAssertEqual(readBack, snapshot)
        XCTAssertTrue(didWrite)
        XCTAssertEqual(events, [watchdogEvent])
        XCTAssertEqual(toggleValues, [true])
        XCTAssertEqual(selectionValues, [snapshot])
        XCTAssertEqual(recorded.value, [
            "isTrueInterruptEnabled",
            "setTrueInterruptEnabled(true)",
            "readSelection",
            "writeSelection(2)",
            "record(shieldStarted, ctx)",
            "recentEvents"
        ])
    }

    func test_silentClient_recentEvents_returnsEmptyArray() async {
        let client = TCATestDependencies.silentIPCClient()

        let events = await client.recentEvents()

        XCTAssertTrue(events.isEmpty)
    }

    func test_silentClient_selectionAccessors_returnSafeFallbacks() async {
        let client = TCATestDependencies.silentIPCClient()

        let snapshot = await client.readSelection()
        let didWrite = await client.writeSelection(
            AppGroupSelectionSnapshot(categoryCount: 1, appCount: 1, lastUpdated: Date())
        )
        let didEnable = await client.setTrueInterruptEnabled(true)

        XCTAssertEqual(snapshot, .empty)
        XCTAssertFalse(didWrite)
        XCTAssertFalse(didEnable)
    }

    func test_silentClient_selectionChanges_isFinishedStream() async {
        let client = TCATestDependencies.silentIPCClient()

        var values: [AppGroupSelectionSnapshot] = []
        for await value in client.selectionChanges() {
            values.append(value)
        }

        XCTAssertTrue(values.isEmpty)
    }

    // MARK: - fallbackRoute(for:) surface (#900)

    /// `fallbackRoute(for:)` routes the requested `ReminderType` to the
    /// configured closure and returns the persisted decision verbatim,
    /// preserving both the `reason` raw value and the `recordedAt`
    /// timestamp so reducers can correlate the prior decision with
    /// downstream analytics windows.
    func test_overriddenClient_fallbackRoute_routesToConfiguredClosure() async {
        let recorded = LockIsolated<[ReminderType]>([])
        let persistedRoute = FallbackRoute(
            reason: .fallbackSuppressed,
            recordedAt: Date(timeIntervalSince1970: 3_000)
        )
        let client = IPCClient(
            isTrueInterruptEnabled: { false },
            setTrueInterruptEnabled: { _ in false },
            readSelection: { .empty },
            writeSelection: { _ in false },
            record: { _, _ in },
            trueInterruptChanges: { .finished },
            selectionChanges: { .finished },
            recentEvents: { [] },
            fallbackRoute: { type in
                recorded.withValue { $0.append(type) }
                return persistedRoute
            }
        )

        let resolved = await client.fallbackRoute(.posture)

        XCTAssertEqual(recorded.value, [.posture])
        XCTAssertEqual(resolved, persistedRoute)
    }

    /// The silent client defaults to `nil` so reducer paths that do not
    /// override `fallbackRoute` (the cold-launch baseline) observe the
    /// missing-route branch deterministically.
    func test_silentClient_fallbackRoute_returnsNil() async {
        let client = TCATestDependencies.silentIPCClient()

        let resolved = await client.fallbackRoute(.eyes)

        XCTAssertNil(resolved)
    }
}
