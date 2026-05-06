import AVFoundation
@testable import EyePostureReminder
import XCTest

final class AudioInterruptionManagerTests: XCTestCase {
    private final class MockAudioSession: AudioSessionControlling {
        var setCategoryCalls: [(AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)] = []
        var setActiveCalls: [(Bool, AVAudioSession.SetActiveOptions)] = []

        func setCategory(
            _ category: AVAudioSession.Category,
            mode: AVAudioSession.Mode,
            options: AVAudioSession.CategoryOptions
        ) throws {
            setCategoryCalls.append((category, mode, options))
        }

        func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
            setActiveCalls.append((active, options))
        }
    }

    func test_pauseExternalAudio_setsSoloAmbientAndActivatesSession() {
        let session = MockAudioSession()
        let sut = AudioInterruptionManager(audioSession: session)

        sut.pauseExternalAudio()

        XCTAssertEqual(session.setCategoryCalls.count, 1)
        XCTAssertEqual(session.setCategoryCalls.first?.0, .soloAmbient)
        XCTAssertEqual(session.setCategoryCalls.first?.1, .default)
        XCTAssertEqual(session.setCategoryCalls.first?.2, [])
        XCTAssertEqual(session.setActiveCalls.count, 1)
        XCTAssertEqual(session.setActiveCalls.first?.0, true)
        XCTAssertEqual(session.setActiveCalls.first?.1, [])
    }

    func test_resumeExternalAudio_deactivatesWithNotifyOthersOption() {
        let session = MockAudioSession()
        let sut = AudioInterruptionManager(audioSession: session)

        sut.resumeExternalAudio()

        XCTAssertEqual(session.setActiveCalls.count, 1)
        XCTAssertEqual(session.setActiveCalls.first?.0, false)
        XCTAssertEqual(session.setActiveCalls.first?.1, .notifyOthersOnDeactivation)
    }

    func test_init_usesFactoryWhenSessionNotInjected() {
        let session = MockAudioSession()
        var makeSessionCallCount = 0
        let sut = AudioInterruptionManager(
            makeAudioSession: {
                makeSessionCallCount += 1
                return session
            }
        )

        sut.pauseExternalAudio()

        XCTAssertEqual(makeSessionCallCount, 1)
        XCTAssertEqual(session.setCategoryCalls.count, 1)
    }

    func test_init_bypassesFactoryWhenSessionInjected() {
        let injectedSession = MockAudioSession()
        var makeSessionCallCount = 0
        let sut = AudioInterruptionManager(
            audioSession: injectedSession,
            makeAudioSession: {
                makeSessionCallCount += 1
                return MockAudioSession()
            }
        )

        sut.resumeExternalAudio()

        XCTAssertEqual(makeSessionCallCount, 0)
        XCTAssertEqual(injectedSession.setActiveCalls.count, 1)
    }
}
