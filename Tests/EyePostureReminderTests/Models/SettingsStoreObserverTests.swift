import XCTest

@testable import EyePostureReminder

@MainActor
final class SettingsStoreObserverTests: XCTestCase {

    private var mockPersistence: MockSettingsPersisting!
    private var sut: SettingsStore!

    override func setUp() {
        super.setUp()
        mockPersistence = MockSettingsPersisting()
        sut = SettingsStore(store: mockPersistence)
    }

    override func tearDown() {
        sut = nil
        mockPersistence = nil
        super.tearDown()
    }

    // MARK: - Registration

    func test_addObserver_returnsUniqueIDsAcrossCalls() {
        let firstID = sut.addObserver { _ in }
        let secondID = sut.addObserver { _ in }
        XCTAssertNotEqual(firstID, secondID,
                          "Each addObserver call should hand out a unique token")
    }

    func test_addObserver_doesNotFireImmediately() {
        var fireCount = 0
        _ = sut.addObserver { _ in fireCount += 1 }
        XCTAssertEqual(fireCount, 0,
                       "Registration alone must not emit; emission only on mutation")
    }

    // MARK: - Broadcast on Mutation

    func test_observer_firesOnGlobalEnabledMutation() {
        var fireCount = 0
        _ = sut.addObserver { _ in fireCount += 1 }
        sut.globalEnabled.toggle()
        XCTAssertEqual(fireCount, 1)
    }

    func test_observer_firesOnEyesIntervalMutation_andCarriesEyesSnapshot() {
        var lastSnapshot: ReminderSettings?
        _ = sut.addObserver { lastSnapshot = $0 }
        sut.eyesInterval = 600
        XCTAssertEqual(lastSnapshot?.interval, 600)
        XCTAssertEqual(lastSnapshot?.breakDuration, sut.eyesBreakDuration)
    }

    func test_observer_firesOnEyesBreakDurationMutation() {
        var lastSnapshot: ReminderSettings?
        _ = sut.addObserver { lastSnapshot = $0 }
        sut.eyesBreakDuration = 25
        XCTAssertEqual(lastSnapshot?.breakDuration, 25)
    }

    func test_observer_firesOnPostureMutations_evenThoughPayloadIsEyes() {
        var fireCount = 0
        _ = sut.addObserver { _ in fireCount += 1 }
        sut.postureEnabled.toggle()
        sut.postureInterval = 1500
        sut.postureBreakDuration = 15
        XCTAssertEqual(fireCount, 3,
                       "Posture mutations must broadcast — they are still settings changes")
    }

    func test_observer_firesOnSnoozeAndPauseMutations() {
        var fireCount = 0
        _ = sut.addObserver { _ in fireCount += 1 }
        sut.snoozedUntil = Date(timeIntervalSince1970: 1)
        sut.snoozeCount = 2
        sut.pauseDuringFocus.toggle()
        sut.pauseWhileDriving.toggle()
        sut.notificationFallbackEnabled.toggle()
        sut.pauseMediaDuringBreaks.toggle()
        sut.hapticsEnabled.toggle()
        XCTAssertEqual(fireCount, 7,
                       "Every settable property must broadcast exactly once per mutation")
    }

    func test_observer_firesOncePerResetToDefaults_perMutatedProperty() {
        // Set non-default values so resetToDefaults visibly mutates each property.
        sut.globalEnabled = false
        sut.eyesEnabled = false
        sut.postureEnabled = false
        sut.eyesInterval = 999
        sut.eyesBreakDuration = 25
        sut.postureInterval = 999
        sut.postureBreakDuration = 25
        sut.hapticsEnabled = false
        sut.pauseMediaDuringBreaks = true
        sut.pauseDuringFocus = false
        sut.pauseWhileDriving = false
        sut.notificationFallbackEnabled = false
        sut.snoozedUntil = Date(timeIntervalSince1970: 1)
        sut.snoozeCount = 5

        var fireCount = 0
        _ = sut.addObserver { _ in fireCount += 1 }

        sut.resetToDefaults(config: .fallback)

        // resetToDefaults touches 14 settable properties; each broadcasts once.
        XCTAssertEqual(fireCount, 14,
                       "resetToDefaults must broadcast for each property it overwrites")
    }

    // MARK: - Multiple Observers

    func test_multipleObservers_allReceiveBroadcasts() {
        var firstFireCount = 0
        var secondFireCount = 0
        _ = sut.addObserver { _ in firstFireCount += 1 }
        _ = sut.addObserver { _ in secondFireCount += 1 }
        sut.globalEnabled.toggle()
        XCTAssertEqual(firstFireCount, 1)
        XCTAssertEqual(secondFireCount, 1)
    }

    // MARK: - Removal

    func test_removeObserver_stopsFurtherCallbacks() {
        var fireCount = 0
        let token = sut.addObserver { _ in fireCount += 1 }
        sut.globalEnabled.toggle()
        XCTAssertEqual(fireCount, 1)

        sut.removeObserver(token)
        sut.globalEnabled.toggle()
        XCTAssertEqual(fireCount, 1, "Mutations after removeObserver must not fire the callback")
    }

    func test_removeObserver_unknownToken_isNoOp() {
        // Should not crash or affect state.
        sut.removeObserver(UUID())
        XCTAssertTrue(sut.globalEnabled, "State must remain untouched by a no-op removeObserver")
    }

    func test_removeObserver_doesNotAffectOtherObservers() {
        var firstFireCount = 0
        var secondFireCount = 0
        let firstToken = sut.addObserver { _ in firstFireCount += 1 }
        _ = sut.addObserver { _ in secondFireCount += 1 }

        sut.removeObserver(firstToken)
        sut.globalEnabled.toggle()

        XCTAssertEqual(firstFireCount, 0)
        XCTAssertEqual(secondFireCount, 1)
    }
}
