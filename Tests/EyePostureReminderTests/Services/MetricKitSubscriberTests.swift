@testable import EyePostureReminder
import MetricKit
import XCTest

private final class MockMetricKitManager: MetricKitManaging {
    private(set) var addCallCount = 0
    private(set) var addedSubscribers: [MXMetricManagerSubscriber] = []

    func add(_ subscriber: MXMetricManagerSubscriber) {
        addCallCount += 1
        addedSubscribers.append(subscriber)
    }
}

private final class MockMetricKitLogger: MetricKitLogging {
    private(set) var infoMessages: [String] = []
    private(set) var warningMessages: [String] = []
    private(set) var errorMessages: [String] = []

    func info(_ message: String) {
        infoMessages.append(message)
    }

    func warning(_ message: String) {
        warningMessages.append(message)
    }

    func error(_ message: String) {
        errorMessages.append(message)
    }
}

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

    /// `register()` calls the injected manager's `add(self)`.
    func test_register_addsSubscriberViaInjectedManager() throws {
        let manager = MockMetricKitManager()
        let logger = MockMetricKitLogger()
        let subscriber = MetricKitSubscriber(metricManager: manager, logger: logger)

        subscriber.register()

        XCTAssertEqual(manager.addCallCount, 1)
        let addedSubscriber = try XCTUnwrap(manager.addedSubscribers.first)
        XCTAssertTrue(addedSubscriber === subscriber)
        XCTAssertEqual(logger.infoMessages, ["MetricKit subscriber registered"])
    }

    func test_register_calledMultipleTimes_recordsEachRegistrationCall() {
        let manager = MockMetricKitManager()
        let logger = MockMetricKitLogger()
        let subscriber = MetricKitSubscriber(metricManager: manager, logger: logger)

        subscriber.register()
        subscriber.register()

        XCTAssertEqual(manager.addCallCount, 2)
        XCTAssertTrue(manager.addedSubscribers.allSatisfy { $0 === subscriber })
        XCTAssertEqual(
            logger.infoMessages,
            ["MetricKit subscriber registered", "MetricKit subscriber registered"]
        )
    }

    func test_register_withNilMetricManager_usesFactoryManager() throws {
        let logger = MockMetricKitLogger()
        let fallbackManager = MockMetricKitManager()
        var factoryCallCount = 0
        let subscriber = MetricKitSubscriber(
            metricManager: nil,
            makeMetricManager: {
                factoryCallCount += 1
                return fallbackManager
            },
            logger: logger
        )

        subscriber.register()

        XCTAssertEqual(factoryCallCount, 1)
        XCTAssertEqual(fallbackManager.addCallCount, 1)
        let addedSubscriber = try XCTUnwrap(fallbackManager.addedSubscribers.first)
        XCTAssertTrue(addedSubscriber === subscriber)
    }

    func test_register_withInjectedMetricManager_bypassesFactory() {
        let manager = MockMetricKitManager()
        let fallbackManager = MockMetricKitManager()
        let logger = MockMetricKitLogger()
        var factoryCallCount = 0
        let subscriber = MetricKitSubscriber(
            metricManager: manager,
            makeMetricManager: {
                factoryCallCount += 1
                return fallbackManager
            },
            logger: logger
        )

        subscriber.register()

        XCTAssertEqual(factoryCallCount, 0)
        XCTAssertEqual(manager.addCallCount, 1)
        XCTAssertEqual(fallbackManager.addCallCount, 0)
    }

    func test_register_withNilLogger_usesFactoryLogger() {
        let manager = MockMetricKitManager()
        let fallbackLogger = MockMetricKitLogger()
        var factoryCallCount = 0
        let subscriber = MetricKitSubscriber(
            metricManager: manager,
            logger: nil,
            makeLogger: {
                factoryCallCount += 1
                return fallbackLogger
            }
        )

        subscriber.register()

        XCTAssertEqual(factoryCallCount, 1)
        XCTAssertEqual(
            fallbackLogger.infoMessages,
            ["MetricKit subscriber registered"]
        )
    }

    func test_register_withInjectedLogger_bypassesFactory() {
        let manager = MockMetricKitManager()
        let logger = MockMetricKitLogger()
        let fallbackLogger = MockMetricKitLogger()
        var factoryCallCount = 0
        let subscriber = MetricKitSubscriber(
            metricManager: manager,
            logger: logger,
            makeLogger: {
                factoryCallCount += 1
                return fallbackLogger
            }
        )

        subscriber.register()

        XCTAssertEqual(factoryCallCount, 0)
        XCTAssertEqual(logger.infoMessages, ["MetricKit subscriber registered"])
        XCTAssertTrue(fallbackLogger.infoMessages.isEmpty)
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
