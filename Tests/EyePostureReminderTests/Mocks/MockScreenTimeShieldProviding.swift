@testable import EyePostureReminder
import Foundation

/// Mock implementation of `ScreenTimeShieldProviding` for use in
/// `AppCoordinator` integration tests (M3.3+).
///
/// Records calls to `beginShield` and `endShield` so tests can assert
/// the coordinator calls the shield provider at the correct times.
@MainActor
final class MockScreenTimeShieldProviding: ScreenTimeShieldProviding {

    var isAvailable: Bool = false

    private(set) var beginShieldCallCount = 0
    private(set) var endShieldCallCount = 0
    private(set) var lastSession: ShieldSession?

    var beginShieldError: Error?
    var endShieldError: Error?

    func beginShield(for session: ShieldSession) async throws {
        beginShieldCallCount += 1
        lastSession = session
        if let error = beginShieldError { throw error }
    }

    func endShield() async throws {
        endShieldCallCount += 1
        if let error = endShieldError { throw error }
    }

    func startMonitoring() {}
    func stopMonitoring() {}
}
