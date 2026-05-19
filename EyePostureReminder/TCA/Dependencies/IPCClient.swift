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
///
/// Watchdog Phase-2 wiring (#892) added `recentEvents`, an App Group
/// event-log snapshot the reducer pairs with `@Dependency(\.date)` (TCA's
/// `DateGenerator`, the `Clock`-shaped adapter that vends "now" for
/// heartbeat-staleness comparisons). Together with the reducer action
/// `SchedulingFeature.watchdogRecoveryTriggered`, they form the dependency
/// surface the deleted `AppCoordinator.recoverStaleDevice…` detector
/// required — see `Tests/.../WatchdogHeartbeatTests.swift` for the parity
/// contract the reducer composes with `WatchdogHeartbeat.status(…)`.
///
/// Fallback-routing accessor (#900): `fallbackRoute(for:)` returns the
/// most recent persisted fallback-routing decision the extension or
/// background pipeline recorded for `type` — derived from the App Group
/// event log (`notificationFallbackScheduled` / `notificationFallbackSuppressed`).
/// Reducer paths (`SchedulingFeature.reminderNotificationEffect`) read it
/// through this dependency boundary so `TestStore` fakes drive the
/// fallback path deterministically instead of the live
/// `UserDefaults(suiteName:)` shared by the extension.
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

    /// Snapshot of the recent App Group IPC event log used by watchdog
    /// recovery detection (#892). Returns an empty array when the store is
    /// unavailable so callers can stay synchronous without try-catch. The
    /// reducer pairs this read with the `@Dependency(\.date)` clock — TCA's
    /// `DateGenerator` is the `Clock`-shaped adapter that vends the "now"
    /// used for heartbeat-staleness comparisons; a `TestStore` can drive
    /// both deterministically inside a single `withDependencies` block.
    var recentEvents: @Sendable () async -> [AppGroupIPCEvent] = { [] }

    /// Most recent persisted fallback-routing decision for `type`, or `nil`
    /// when no decision has been recorded since the event log was last
    /// rotated (#900). The live implementation derives the value from the
    /// shared App Group event log so the reducer never reads
    /// `UserDefaults(suiteName:)` directly; tests substitute the closure
    /// to drive both the present and missing-route branches deterministically.
    var fallbackRoute: @Sendable (ReminderType) async -> FallbackRoute? = { _ in nil }
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
            selectionChanges: { makeSelectionStream() },
            recentEvents: {
                await MainActor.run { LiveIPCBridge.shared.readEvents() }
            },
            fallbackRoute: { type in
                await MainActor.run { LiveIPCBridge.shared.readFallbackRoute(for: type) }
            }
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

/// Persisted fallback-routing decision recorded for a `ReminderType` by
/// the extension / background pipeline. Returned by `IPCClient.fallbackRoute(for:)`
/// so reducer paths can inspect the prior fallback decision through the
/// dependency boundary (#900).
struct FallbackRoute: Equatable, Sendable {
    /// Classification of the persisted decision. Mirrors the
    /// `AppGroupIPCEventKind` cases that participate in fallback routing.
    enum Reason: String, Equatable, Sendable {
        /// Last decision was to schedule a notification-fallback for this type.
        case fallbackScheduled = "fallback_scheduled"
        /// Last decision was to suppress the notification-fallback for this type.
        case fallbackSuppressed = "fallback_suppressed"
    }

    let reason: Reason
    let recordedAt: Date
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

    func readEvents() -> [AppGroupIPCEvent] {
        do {
            return try store.readEvents()
        } catch {
            AnalyticsLogger.log(
                .ipcOperationFailed(operation: .readEvents, reason: .unavailable)
            )
            ipcLogger.error("""
                event=ipc_read_events_failed \
                error=\(error.localizedDescription, privacy: .public)
                """)
            return []
        }
    }

    /// Resolves the most recent persisted fallback-routing decision for
    /// `type` by scanning the App Group event log for the latest
    /// `notificationFallbackScheduled` / `notificationFallbackSuppressed`
    /// entry whose `reasonRaw` matches `type.shieldReason.rawValue`.
    /// Returns `nil` when the log holds no such entry (the common cold-
    /// launch case) so the reducer can stay synchronous with the UI
    /// lifecycle (#900).
    func readFallbackRoute(for type: ReminderType) -> FallbackRoute? {
        let typeReasonRaw = type.shieldReason.rawValue
        let events = readEvents()
        let mostRecent = events
            .filter { event in
                event.reasonRaw == typeReasonRaw &&
                    (event.kind == .notificationFallbackScheduled ||
                     event.kind == .notificationFallbackSuppressed)
            }
            .max { lhs, rhs in lhs.timestamp < rhs.timestamp }
        guard let mostRecent else { return nil }
        let reason: FallbackRoute.Reason
        switch mostRecent.kind {
        case .notificationFallbackScheduled:
            reason = .fallbackScheduled
        case .notificationFallbackSuppressed:
            reason = .fallbackSuppressed
        default:
            return nil
        }
        return FallbackRoute(reason: reason, recordedAt: mostRecent.timestamp)
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
