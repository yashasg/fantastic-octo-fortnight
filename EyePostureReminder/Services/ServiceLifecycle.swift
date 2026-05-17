/// A protocol for services that have a monitoring lifecycle.
///
/// Conforming types can be uniformly started and stopped by their
/// owning feature/service composition without knowledge of the concrete
/// type. The lifecycle contract is consumed by the TCA dependency
/// clients that own these services.
///
/// Both methods must be called on the main actor — implementations
/// typically own `@MainActor`-isolated state.
@MainActor
protocol ServiceLifecycle: AnyObject {
    func startMonitoring()
    func stopMonitoring()
}
