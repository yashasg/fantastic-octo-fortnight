import ComposableArchitecture
import Foundation

/// TCA dependency client wrapping `ScreenTimeAuthorizationProviding` for
/// reducer consumption.
///
/// Phase 0 of the MVVM → TCA migration (#665). The pre-entitlement default
/// implementation is `ScreenTimeAuthorizationNoop`, which always returns
/// `.unavailable`; the `liveValue` adapter forwards through that noop until
/// the FamilyControls entitlement is provisioned (#201).
@DependencyClient
struct ScreenTimeAuthorizationClient: Sendable {
    /// Current authorisation status. Defaults to `.unavailable`.
    var status: @Sendable () async -> ScreenTimeAuthorizationStatus = { .unavailable }

    /// Multicast stream of authorisation status changes.
    var statusChanges: @Sendable () -> AsyncStream<ScreenTimeAuthorizationStatus> = { .finished }

    /// Requests authorisation and returns the resulting status.
    var requestAuthorization: @Sendable () async -> ScreenTimeAuthorizationStatus = {
        .unavailable
    }
}

extension ScreenTimeAuthorizationClient: DependencyKey {
    static let liveValue: ScreenTimeAuthorizationClient = {
        Task { @MainActor in _ = LiveScreenTimeAuthorizationBridge.shared }
        return ScreenTimeAuthorizationClient(
            status: {
                await LiveScreenTimeAuthorizationBridge.shared.status()
            },
            statusChanges: {
                makeScreenTimeAuthorizationStream()
            },
            requestAuthorization: {
                await LiveScreenTimeAuthorizationBridge.shared.request()
            }
        )
    }()
}

extension DependencyValues {
    /// TCA accessor for the shared `ScreenTimeAuthorizationClient`.
    var screenTimeAuthorizationClient: ScreenTimeAuthorizationClient {
        get { self[ScreenTimeAuthorizationClient.self] }
        set { self[ScreenTimeAuthorizationClient.self] = newValue }
    }
}

/// Main-actor-isolated owner of the live `ScreenTimeAuthorizationProviding`
/// implementation. Broadcasts every status change observed during a
/// `requestAuthorization()` call to active stream subscribers.
@MainActor
private final class LiveScreenTimeAuthorizationBridge {
    static let shared = LiveScreenTimeAuthorizationBridge()

    let provider: ScreenTimeAuthorizationProviding = ScreenTimeAuthorizationNoop()

    private init() {}

    func status() -> ScreenTimeAuthorizationStatus {
        provider.authorizationStatus
    }

    func request() async -> ScreenTimeAuthorizationStatus {
        let result = await provider.requestAuthorization()
        screenTimeAuthorizationContinuations.withValue { dict in
            for continuation in dict.values { continuation.yield(result) }
        }
        return result
    }
}

/// File-scoped multicast continuations for `ScreenTimeAuthorizationClient`.
/// Held outside the `@MainActor` bridge so the nonisolated stream factory can
/// capture it without crossing actor boundaries — `LockIsolated` already
/// provides thread safety. Defined at file scope (rather than as a static
/// property of the bridge class) to side-step a Swift constraint-solver bug
/// triggered by `Continuation.onTermination` capturing `@MainActor`-isolated
/// static storage.
private let screenTimeAuthorizationContinuations =
    LockIsolated<[UUID: AsyncStream<ScreenTimeAuthorizationStatus>.Continuation]>([:])

/// File-scoped factory used by the live `statusChanges` closure to register a
/// new multicast subscriber. Lives outside the bridge class so it can be
/// invoked from a `@Sendable` non-async context.
private func makeScreenTimeAuthorizationStream()
    -> AsyncStream<ScreenTimeAuthorizationStatus> {
    let (stream, continuation) =
        AsyncStream<ScreenTimeAuthorizationStatus>.makeStream()
    let id = UUID()
    screenTimeAuthorizationContinuations.withValue { $0[id] = continuation }
    continuation.onTermination = { _ in
        screenTimeAuthorizationContinuations.withValue { dict in
            dict[id] = nil
        }
    }
    return stream
}
