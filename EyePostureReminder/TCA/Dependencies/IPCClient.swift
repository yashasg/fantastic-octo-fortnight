import ComposableArchitecture
import Foundation
import os
import ScreenTimeExtensionShared

/// TCA dependency client wrapping `AppGroupIPCStore` for reducer consumption.
///
/// Phase 0 of the MVVM → TCA migration (#665). The `liveValue` adapter
/// installs a single `NotificationCenter` observer for the
/// `trueInterruptEnabledDidChange` notification that multicasts to every
/// active `trueInterruptChanges` subscriber via per-subscriber `AsyncStream`
/// continuations. The optional `String` argument carried by `record` is the
/// caller-supplied operation context — it is preserved in the failure log
/// emitted when `recordEvent` throws.
@DependencyClient
struct IPCClient: Sendable {
    /// Whether the user has toggled on the True Interrupt (DeviceActivity
    /// shield) feature in Settings. Reads the App Group flag synchronously.
    var isTrueInterruptEnabled: @Sendable () async -> Bool = { false }

    /// Records an IPC event to the shared App Group store. The optional
    /// `String` second argument is a free-form caller-supplied operation
    /// context preserved in the failure log if the underlying write fails.
    var record: @Sendable (AppGroupIPCEvent, String?) async -> Void

    /// Multicast stream of `trueInterruptEnabled` flag transitions. A new
    /// subscriber receives every subsequent change until the consumer
    /// terminates.
    var trueInterruptChanges: @Sendable () -> AsyncStream<Bool> = { .finished }
}

extension IPCClient: DependencyKey {
    static let liveValue: IPCClient = {
        Task { @MainActor in LiveIPCBridge.shared.bootstrap() }
        return IPCClient(
            isTrueInterruptEnabled: {
                await MainActor.run { LiveIPCBridge.shared.store.isTrueInterruptEnabled() }
            },
            record: { event, context in
                await MainActor.run { LiveIPCBridge.shared.record(event, context: context) }
            },
            trueInterruptChanges: { makeTrueInterruptStream() }
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
/// `trueInterruptEnabledDidChange` notifications and forwards them to the
/// file-scope continuation registry.
@MainActor
private final class LiveIPCBridge {
    nonisolated static let shared = LiveIPCBridge()

    let store = AppGroupIPCStore()
    private var observer: NSObjectProtocol?
    private var hasBootstrapped = false

    private nonisolated init() {}

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        observer = NotificationCenter.default.addObserver(
            forName: AppGroupIPCStore.trueInterruptEnabledDidChangeNotification,
            object: nil,
            queue: nil
        ) { notification in
            let value = (notification.userInfo?[
                AppGroupIPCStore.trueInterruptEnabledValueUserInfoKey
            ] as? Bool) ?? false
            broadcastTrueInterruptChange(value)
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
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
}

/// File-scoped multicast continuations for `IPCClient.trueInterruptChanges`.
private let trueInterruptContinuations =
    LockIsolated<[UUID: AsyncStream<Bool>.Continuation]>([:])

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

private func broadcastTrueInterruptChange(_ value: Bool) {
    trueInterruptContinuations.withValue { dict in
        for continuation in dict.values { continuation.yield(value) }
    }
}
