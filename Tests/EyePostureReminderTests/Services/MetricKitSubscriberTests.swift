@testable import EyePostureReminder
import MetricKit
import XCTest

/// Unit tests for `MetricKitSubscriber`.
///
/// MetricKit payload objects cannot be instantiated in unit tests — they are
/// vended exclusively by the system via `MXMetricManager`. These tests verify:
/// 1. The singleton is accessible and non-nil.
/// 2. `register()` doesn't crash (even in a headless test process).
/// 3. `didReceive(_:)` with empty arrays doesn't crash.
final class MetricKitSubscriberTests: XCTestCase {

    // MARK: - Singleton

    func test_shared_isNotNil() {
        XCTAssertNotNil(MetricKitSubscriber.shared)
    }

    func test_shared_returnsSameInstance() {
        let first = MetricKitSubscriber.shared
        let second = MetricKitSubscriber.shared
        XCTAssertTrue(first === second, "MetricKitSubscriber.shared must always return the same instance")
    }

    // MARK: - Conformance

    func test_conformsToMXMetricManagerSubscriber() {
        let subscriber: MXMetricManagerSubscriber = MetricKitSubscriber.shared
        XCTAssertNotNil(subscriber)
    }

    // MARK: - register()

    /// `register()` calls `MXMetricManager.shared.add(self)`.
    /// In a test process this is a no-op from MetricKit's perspective
    /// but must not crash.
    func test_register_doesNotCrash() {
        MetricKitSubscriber.shared.register()
    }

    func test_register_calledMultipleTimes_doesNotCrash() {
        MetricKitSubscriber.shared.register()
        MetricKitSubscriber.shared.register()
    }

    // MARK: - didReceive([MXMetricPayload])

    /// Empty payload array must be handled gracefully — the `for` loop
    /// iterates zero times.
    func test_didReceiveMetricPayloads_emptyArray_doesNotCrash() {
        let payloads: [MXMetricPayload] = []
        MetricKitSubscriber.shared.didReceive(payloads)
    }

    // MARK: - didReceive([MXDiagnosticPayload])

    /// Empty diagnostic payload array must be handled gracefully.
    func test_didReceiveDiagnosticPayloads_emptyArray_doesNotCrash() {
        let payloads: [MXDiagnosticPayload] = []
        MetricKitSubscriber.shared.didReceive(payloads)
    }
}
