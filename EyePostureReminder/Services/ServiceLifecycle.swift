/// A protocol for services that have a monitoring lifecycle.
///
/// Conforming types can be uniformly started and stopped by
/// `AppCoordinator` without knowledge of their concrete type.
///
/// Both methods must be called on the main actor — implementations
/// typically own `@MainActor`-isolated state.
@MainActor
protocol ServiceLifecycle: AnyObject {
    func startMonitoring()
    func stopMonitoring()
}
