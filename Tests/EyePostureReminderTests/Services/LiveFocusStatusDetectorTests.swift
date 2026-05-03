@testable import EyePostureReminder
import XCTest

// MARK: - LiveFocusStatusDetectorTests

/// Unit tests for `LiveFocusStatusDetector`.
///
/// `INFocusStatusCenter.default` is replaced by `MockFocusStatusCenter` so no
/// real Focus mode permissions are required. Authorization and observation paths
/// are exercised via synchronous mock helpers.
@MainActor
final class LiveFocusStatusDetectorTests: XCTestCase {

    // MARK: - Mock

    private final class MockFocusStatusCenter: FocusStatusCenterProviding {
        private(set) var authorizationRequested = false
        private var pendingAuthHandler: ((Bool) -> Void)?
        private var focusChangesHandler: ((Bool) -> Void)?
        var stubbedIsFocused: Bool = false

        var currentIsFocused: Bool { stubbedIsFocused }

        func requestFocusAuthorization(_ handler: @escaping (Bool) -> Void) {
            authorizationRequested = true
            pendingAuthHandler = handler
        }

        func observeFocusChanges(_ handler: @escaping (Bool) -> Void) -> AnyObject {
            focusChangesHandler = handler
            return NSObject()
        }

        func simulateAuthResponse(_ authorized: Bool) {
            pendingAuthHandler?(authorized)
        }

        func simulateFocusChange(_ focused: Bool) {
            stubbedIsFocused = focused
            focusChangesHandler?(focused)
        }
    }

    // MARK: - Factory Seam

    func test_init_withoutFocusCenter_usesFactoryFallback() {
        var factoryCallCount = 0
        _ = LiveFocusStatusDetector(
            makeFocusCenter: {
                factoryCallCount += 1
                return MockFocusStatusCenter()
            }
        )
        XCTAssertEqual(factoryCallCount, 1, "Factory must be called exactly once when no explicit center is injected")
    }

    func test_init_withFocusCenter_bypassesFactoryFallback() {
        var factoryCallCount = 0
        let center = MockFocusStatusCenter()
        _ = LiveFocusStatusDetector(
            focusCenter: center,
            makeFocusCenter: {
                factoryCallCount += 1
                return MockFocusStatusCenter()
            }
        )
        XCTAssertEqual(factoryCallCount, 0, "Factory must not be called when an explicit center is injected")
    }

    // MARK: - Authorization

    func test_startMonitoring_requestsAuthorization() {
        let center = MockFocusStatusCenter()
        let detector = LiveFocusStatusDetector(focusCenter: center)

        detector.startMonitoring()

        XCTAssertTrue(center.authorizationRequested, "startMonitoring must request Focus mode authorization")
        detector.stopMonitoring()
    }

    func test_startMonitoring_whenAuthDenied_isFocusedUnchanged() {
        let center = MockFocusStatusCenter()
        center.stubbedIsFocused = true
        let detector = LiveFocusStatusDetector(focusCenter: center)

        detector.startMonitoring()
        center.simulateAuthResponse(false)
        // Denied path exits early — no main dispatch is enqueued.

        XCTAssertFalse(detector.isFocused, "Denied authorization must leave isFocused unchanged (fail-open)")
        detector.stopMonitoring()
    }

    func test_startMonitoring_whenAuthGranted_seedsCurrentFocusState() {
        let center = MockFocusStatusCenter()
        center.stubbedIsFocused = true
        let detector = LiveFocusStatusDetector(focusCenter: center)
        let exp = expectation(description: "onFocusChanged fired after auth granted")
        detector.onFocusChanged = { _ in exp.fulfill() }

        detector.startMonitoring()
        center.simulateAuthResponse(true)

        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(detector.isFocused, "Authorized path must seed isFocused from injected center.currentIsFocused")
        detector.stopMonitoring()
    }
}
