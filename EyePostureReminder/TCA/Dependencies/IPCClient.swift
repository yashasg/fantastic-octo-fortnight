import ComposableArchitecture
import Foundation
import os
import ScreenTimeExtensionShared

/// TCA dependency client wrapping `AppGroupIPCStore` for reducer consumption.
///
/// Phase 0 of the TCA migration (#665). The `liveValue` adapter
/// installs `NotificationCenter` observers for the
/// `trueInterruptEnabledDidChange` and `selectionDidChange` notifications
/// that multicast to every active stream subscriber via per-subscriber
/// `AsyncStream` continuations. The optional `String` argument carried by
/// `record` is the caller-supplied operation context — it is preserved in
/// the failure log emitted when `recordEvent` throws.
///
/// Phase 2 (`p0-tca-15` / #678) extended the surface with selection
/// read/write + multicast, giving reducers direct access to the App
/// Group store.
@DependencyClient
struct IPCClient: Sendable {
    /// Whether the user has toggled on the True Interrupt (DeviceActivity
    /// shield) feature in Settings. Reads the App Group flag synchronously.
    var isTrueInterruptEnabled: @Sendable () async -> Bool = { false }

    /// Persists the True Interrupt enabled flag. Returns `false` when the
    /// store refuses the write (App Group unavailable, or `enabled = true`
    /// requested with an empty selection on disk).
    var setTrueInterruptEnabled: @Sendable (Bool) async -> Bool = { _ in false }

    /// Reads the current selection snapshot from the shared App Group store.
    /// Returns `.empty` when the store is unavailable or the on-disk payload
    /// is corrupt — failures are logged but never thrown so call sites can
    /// stay synchronous with the UI lifecycle.
    var readSelection: @Sendable () async -> AppGroupSelectionSnapshot = { .empty }

    /// Persists the selection snapshot to the shared App Group store.
    /// Returns `false` when the store rejects the write; callers must treat
    /// a `false` return as "selection not durable" and recover accordingly.
    var writeSelection: @Sendable (AppGroupSelectionSnapshot) async -> Bool = { _ in false }

    /// Records an IPC event to the shared App Group store. The optional
    /// `String` second argument is a free-form caller-supplied operation
    /// context preserved in the failure log if the underlying write fails.
    var record: @Sendable (AppGroupIPCEvent, String?) async -> Void

    /// Multicast stream of `trueInterruptEnabled` flag transitions. A new
    /// subscriber receives every subsequent change until the consumer
    /// terminates.
    var trueInterruptChanges: @Sendable () -> AsyncStream<Bool> = { .finished }

    /// Multicast stream of selection snapshot transitions. A new subscriber
    /// receives every subsequent successful `writeSelection` payload until
    /// the consumer terminates.
    var selectionChanges: @Sendable () -> AsyncStream<AppGroupSelectionSnapshot> = { .finished }
}

extension IPCClient: DependencyKey {
    static let liveValue: IPCClient = {
        Task { @MainActor in LiveIPCBridge.shared.bootstrap() }
        return IPCClient(
            isTrueInterruptEnabled: {
                await MainActor.run { LiveIPCBridge.shared.store.isTrueInterruptEnabled() }
            },
            setTrueInterruptEnabled: { enabled in
                await MainActor.run { LiveIPCBridge.shared.store.setTrueInterruptEnabled(enabled) }
            },
            readSelection: {
                await MainActor.run { LiveIPCBridge.shared.readSelection() }
            },
            writeSelection: { snapshot in
                await MainActor.run { LiveIPCBridge.shared.writeSelection(snapshot) }
            },
            record: { event, context in
                await MainActor.run { LiveIPCBridge.shared.record(event, context: context) }
            },
            trueInterruptChanges: { makeTrueInterruptStream() },
            selectionChanges: { makeSelectionStream() }
        )
    }()
}

extension DependencyValues {
    /// TCA accessor for the shared `IPCClient`.
    var ipcClient: IPCClient {
        get { self[IPCClient.self] }
        set { self[IPCClient.self] = newValue }
    }
}

/// Main-actor-isolated owner of the live `AppGroupIPCStore`. Subscribes to
/// `trueInterruptEnabledDidChange` and `selectionDidChange` notifications
/// and forwards them to the file-scope continuation registries.
@MainActor
private final class LiveIPCBridge {
    nonisolated static let shared = LiveIPCBridge()

    let store = AppGroupIPCStore()
    private var trueInterruptObserver: NSObjectProtocol?
    private var selectionObserver: NSObjectProtocol?
    private var hasBootstrapped = false

    private nonisolated init() {}

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        trueInterruptObserver = NotificationCenter.default.addObserver(
            forName: AppGroupIPCStore.trueInterruptEnabledDidChangeNotification,
            object: nil,
            queue: nil
        ) { notification in
            let value = (notification.userInfo?[
                AppGroupIPCStore.trueInterruptEnabledValueUserInfoKey
            ] as? Bool) ?? false
            broadcastTrueInterruptChange(value)
        }

        selectionObserver = NotificationCenter.default.addObserver(
            forName: AppGroupIPCStore.selectionDidChangeNotification,
            object: nil,
            queue: nil
        ) { notification in
            let value = (notification.userInfo?[
                AppGroupIPCStore.selectionValueUserInfoKey
            ] as? AppGroupSelectionSnapshot) ?? .empty
            broadcastSelectionChange(value)
        }
    }

    deinit {
        if let trueInterruptObserver {
            NotificationCenter.default.removeObserver(trueInterruptObserver)
        }
        if let selectionObserver {
            NotificationCenter.default.removeObserver(selectionObserver)
        }
    }

    func record(_ event: AppGroupIPCEvent, context: String?) {
        do {
            try store.recordEvent(event)
        } catch {
            AnalyticsLogger.log(
                .ipcOperationFailed(operation: .writeEvent, reason: .writeFailed)
            )
            ipcLogger.error("""
                event=ipc_record_failed \
                kind=\(event.kind.rawValue, privacy: .public) \
                context=\(context ?? "nil", privacy: .public)
                """)
        }
    }

    func readSelection() -> AppGroupSelectionSnapshot {
        do {
            return try store.readSelection()
        } catch {
            ipcLogger.error("""
                event=ipc_read_selection_failed \
                error=\(error.localizedDescription, privacy: .public)
                """)
            return .empty
        }
    }

    func writeSelection(_ snapshot: AppGroupSelectionSnapshot) -> Bool {
        do {
            try store.writeSelection(snapshot)
            return true
        } catch {
            ipcLogger.error("""
                event=ipc_write_selection_failed \
                error=\(error.localizedDescription, privacy: .public)
                """)
            return false
        }
    }
}

/// File-scoped multicast continuations for `IPCClient.trueInterruptChanges`.
private let trueInterruptContinuations =
    LockIsolated<[UUID: AsyncStream<Bool>.Continuation]>([:])

/// File-scoped multicast continuations for `IPCClient.selectionChanges`.
private let selectionContinuations =
    LockIsolated<[UUID: AsyncStream<AppGroupSelectionSnapshot>.Continuation]>([:])

private let ipcLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.yashasgujjar.eyeposture",
    category: "IPCClient"
)

private func makeTrueInterruptStream() -> AsyncStream<Bool> {
    let (stream, continuation) = AsyncStream<Bool>.makeStream()
    let id = UUID()
    trueInterruptContinuations.withValue { $0[id] = continuation }
    continuation.onTermination = { _ in
        trueInterruptContinuations.withValue { dict in
            dict[id] = nil
        }
    }
    return stream
}

private func makeSelectionStream() -> AsyncStream<AppGroupSelectionSnapshot> {
    let (stream, continuation) = AsyncStream<AppGroupSelectionSnapshot>.makeStream()
    let id = UUID()
    selectionContinuations.withValue { $0[id] = continuation }
    continuation.onTermination = { _ in
        selectionContinuations.withValue { dict in
            dict[id] = nil
        }
    }
    return stream
}

private func broadcastTrueInterruptChange(_ value: Bool) {
    trueInterruptContinuations.withValue { dict in
        for continuation in dict.values { continuation.yield(value) }
    }
}

private func broadcastSelectionChange(_ value: AppGroupSelectionSnapshot) {
    selectionContinuations.withValue { dict in
        for continuation in dict.values { continuation.yield(value) }
    }
}
