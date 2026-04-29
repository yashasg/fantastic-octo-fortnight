@testable import EyePostureReminder
import Foundation

/// Mock implementation of `ScreenTimeAuthorizationProviding` for unit tests.
///
/// Allows tests to control `authorizationStatus` directly and verify that
/// `requestAuthorization()` was called the expected number of times.
/// Never imports or instantiates `FamilyControls`.
@MainActor
final class MockScreenTimeAuthorizationProviding: ScreenTimeAuthorizationProviding {

    // MARK: - Stub state

    /// Controllable authorization status returned to callers.
    var stubbedStatus: ScreenTimeAuthorizationStatus = .unavailable

    var authorizationStatus: ScreenTimeAuthorizationStatus { stubbedStatus }

    // MARK: - Call recording

    private(set) var requestAuthorizationCallCount = 0

    /// Stubbed return value for `requestAuthorization()`.
    var stubbedRequestResult: ScreenTimeAuthorizationStatus = .unavailable

    // MARK: - Protocol conformance

    func requestAuthorization() async -> ScreenTimeAuthorizationStatus {
        requestAuthorizationCallCount += 1
        stubbedStatus = stubbedRequestResult
        return stubbedRequestResult
    }

    // MARK: - Helpers

    func reset() {
        stubbedStatus = .unavailable
        stubbedRequestResult = .unavailable
        requestAuthorizationCallCount = 0
    }
}
