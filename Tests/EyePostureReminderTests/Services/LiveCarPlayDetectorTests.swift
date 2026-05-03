@testable import EyePostureReminder
import AVFoundation
import XCTest

@MainActor
final class LiveCarPlayDetectorTests: XCTestCase {

    func test_init_withoutNotificationCenter_usesFactoryFallback() {
        var factoryCallCount = 0
        _ = LiveCarPlayDetector(
            isCarPlayActiveProvider: { false },
            makeNotificationCenter: {
                factoryCallCount += 1
                return NotificationCenter()
            }
        )

        XCTAssertEqual(factoryCallCount, 1)
    }

    func test_init_withNotificationCenter_bypassesFactoryFallback() {
        var factoryCallCount = 0
        let injectedCenter = NotificationCenter()
        _ = LiveCarPlayDetector(
            notificationCenter: injectedCenter,
            isCarPlayActiveProvider: { false },
            makeNotificationCenter: {
                factoryCallCount += 1
                return NotificationCenter()
            }
        )

        XCTAssertEqual(factoryCallCount, 0)
    }

    func test_startMonitoring_seedsInitialStateFromInjectedProvider() {
        let notificationCenter = NotificationCenter()
        let detector = LiveCarPlayDetector(
            notificationCenter: notificationCenter,
            isCarPlayActiveProvider: { true }
        )

        detector.startMonitoring()

        XCTAssertTrue(detector.isCarPlayActive)
        detector.stopMonitoring()
    }

    func test_routeChange_onInjectedNotificationCenter_updatesStateAndFiresCallback() {
        let notificationCenter = NotificationCenter()
        var isCarPlayConnected = false
        let detector = LiveCarPlayDetector(
            notificationCenter: notificationCenter,
            isCarPlayActiveProvider: { isCarPlayConnected }
        )
        let callbackFired = expectation(description: "onCarPlayChanged called")
        var callbackValues: [Bool] = []
        detector.onCarPlayChanged = { active in
            callbackValues.append(active)
            callbackFired.fulfill()
        }

        detector.startMonitoring()
        isCarPlayConnected = true
        notificationCenter.post(name: AVAudioSession.routeChangeNotification, object: nil)

        wait(for: [callbackFired], timeout: 1.0)
        XCTAssertTrue(detector.isCarPlayActive)
        XCTAssertEqual(callbackValues, [true])
        detector.stopMonitoring()
    }

    func test_routeChange_onDefaultNotificationCenter_isIgnoredWhenCustomCenterInjected() {
        let notificationCenter = NotificationCenter()
        var isCarPlayConnected = false
        let detector = LiveCarPlayDetector(
            notificationCenter: notificationCenter,
            isCarPlayActiveProvider: { isCarPlayConnected }
        )

        detector.startMonitoring()
        isCarPlayConnected = true
        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertFalse(detector.isCarPlayActive)
        detector.stopMonitoring()
    }
}
