import ComposableArchitecture
import Foundation

/// TCA dependency client wrapping `AnalyticsLogger` for reducer consumption.
///
/// Phase 0 of the MVVM → TCA migration (#665). The `liveValue` adapter
/// forwards every emitted event to the existing static `AnalyticsLogger.log`
/// sink so reducers and the legacy MVVM stack share a single os.Logger
/// pipeline during the migration.
@DependencyClient
struct AnalyticsClient: Sendable {
    /// Synchronously emits an analytics event to the shared `os.Logger` sink.
    var log: @Sendable (AnalyticsEvent) -> Void
}

extension AnalyticsClient: DependencyKey {
    static let liveValue = AnalyticsClient(
        log: { event in AnalyticsLogger.log(event) }
    )
}

extension DependencyValues {
    /// TCA accessor for the shared `AnalyticsClient`.
    var analyticsClient: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}
