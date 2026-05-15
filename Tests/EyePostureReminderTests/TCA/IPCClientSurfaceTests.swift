import ComposableArchitecture
import ScreenTimeExtensionShared
import XCTest

@testable import EyePostureReminder

/// Surface-level coverage for the `IPCClient` selection accessors added in
/// `p0-tca-15` (#678). These tests assert the dependency contract that
/// reducers will rely on once `SelectedAppsState` is retired — they do not
/// exercise the live `AppGroupIPCStore`-backed adapter (covered by
/// `AppGroupIPCStoreTests`), only the closure-typed surface routes inputs
/// to the configured implementation.
@MainActor
final class IPCClientSurfaceTests: XCTestCase {

    func test_overriddenClient_routesAllAccessors() async {
        let recorded = LockIsolated<[String]>([])
        let snapshot = AppGroupSelectionSnapshot(
            categoryCount: 1,
            appCount: 2,
            lastUpdated: Date(timeIntervalSince1970: 1_000)
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
            selectionChanges: { selectionStream }
        )

        let isEnabled = await client.isTrueInterruptEnabled()
        let didSet = await client.setTrueInterruptEnabled(true)
        let readBack = await client.readSelection()
        let didWrite = await client.writeSelection(snapshot)
        await client.record(AppGroupIPCEvent(kind: .shieldStarted), "ctx")

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
        XCTAssertEqual(toggleValues, [true])
        XCTAssertEqual(selectionValues, [snapshot])
        XCTAssertEqual(recorded.value, [
            "isTrueInterruptEnabled",
            "setTrueInterruptEnabled(true)",
            "readSelection",
            "writeSelection(2)",
            "record(shieldStarted, ctx)"
        ])
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
}
