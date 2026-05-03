@testable import EyePostureReminder
import CoreMotion
import XCTest

// MARK: - LiveDrivingActivityDetectorTests
//
// Verifies the `MotionManagerFactory` DI seam on `LiveDrivingActivityDetector`.
// Tests confirm that:
//   1. The factory is called exactly once when no manager is injected.
//   2. The factory is bypassed when a concrete manager is injected directly.
//   3. `stopMonitoring()` delegates to `manager.stopActivityUpdates()`.
//
// `startMonitoring()` early-exits on simulators (`CMMotionActivityManager.isActivityAvailable()
// == false`), so `startActivityUpdates(to:withHandler:)` is not testable in this target.
// That guard path is covered by the existing `PauseConditionManagerTests`.

@MainActor
final class LiveDrivingActivityDetectorTests: XCTestCase {

    // MARK: - Stub

    private final class StubMotionManager: MotionActivityManaging {
        private(set) var startActivityUpdatesCallCount = 0
        private(set) var stopActivityUpdatesCallCount  = 0

        func startActivityUpdates(
            to queue: OperationQueue,
            withHandler handler: @escaping CMMotionActivityHandler
        ) {
            startActivityUpdatesCallCount += 1
        }

        func stopActivityUpdates() {
            stopActivityUpdatesCallCount += 1
        }
    }

    // MARK: - Factory seam

    func test_init_withoutMotionManager_usesFactoryFallback() {
        var factoryCallCount = 0
        _ = LiveDrivingActivityDetector(
            makeMotionManager: {
                factoryCallCount += 1
                return StubMotionManager()
            }
        )

        XCTAssertEqual(factoryCallCount, 1, "Factory must be called exactly once when no manager is injected")
    }

    func test_init_withMotionManager_bypassesFactory() {
        var factoryCallCount = 0
        let injected = StubMotionManager()
        _ = LiveDrivingActivityDetector(
            motionManager: injected,
            makeMotionManager: {
                factoryCallCount += 1
                return StubMotionManager()
            }
        )

        XCTAssertEqual(factoryCallCount, 0, "Factory must NOT be called when a manager is injected directly")
    }

    // MARK: - stopMonitoring delegates to manager

    func test_stopMonitoring_callsStopActivityUpdates() {
        let stub = StubMotionManager()
        let detector = LiveDrivingActivityDetector(motionManager: stub)

        detector.stopMonitoring()

        XCTAssertEqual(
            stub.stopActivityUpdatesCallCount,
            1,
            "stopMonitoring() must call manager.stopActivityUpdates() exactly once")
    }

    func test_stopMonitoring_calledTwice_delegatesBothCalls() {
        let stub = StubMotionManager()
        let detector = LiveDrivingActivityDetector(motionManager: stub)

        detector.stopMonitoring()
        detector.stopMonitoring()

        XCTAssertEqual(
            stub.stopActivityUpdatesCallCount,
            2,
            "Each stopMonitoring() call must forward to manager.stopActivityUpdates()")
    }

    // MARK: - Default isDriving state

    func test_init_isDrivingDefaultsFalse() {
        let detector = LiveDrivingActivityDetector(motionManager: StubMotionManager())
        XCTAssertFalse(detector.isDriving, "isDriving must default to false")
    }
}
