/// A protocol for services that have a monitoring lifecycle.
///
/// Conforming types can be uniformly started and stopped by their
/// owning feature/service composition without knowledge of the concrete
/// type (originally consumed by `AppCoordinator` before it was deleted
/// in `#755` Phase E; the lifecycle contract still applies to the
/// services injected through the TCA dependency clients).
///
/// Both methods must be called on the main actor — implementations
/// typically own `@MainActor`-isolated state.
@MainActor
protocol ServiceLifecycle: AnyObject {
    func startMonitoring()
    func stopMonitoring()
}
