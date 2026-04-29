@testable import ScreenTimeExtensionShared
import XCTest

final class ShieldConfigurationCopyTests: XCTestCase {

    private let suiteName = "ShieldConfigurationCopyTests"
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func test_snapshotRead_missingDefaults_returnsEmptySnapshot() {
        let snapshot = ShieldSessionSnapshot.read(from: defaults)

        XCTAssertNil(snapshot.reasonRaw)
        XCTAssertEqual(snapshot.durationSeconds, 0)
        XCTAssertNil(snapshot.triggeredAt)
    }

    func test_snapshotRead_readsSharedDefaultsContract() {
        let triggeredAt = Date(timeIntervalSince1970: 1_000)
        defaults.set("eyes", forKey: ShieldSessionKeys.breakReason)
        defaults.set(20.0, forKey: ShieldSessionKeys.durationSeconds)
        defaults.set(triggeredAt.timeIntervalSince1970, forKey: ShieldSessionKeys.triggeredAt)

        let snapshot = ShieldSessionSnapshot.read(from: defaults)

        XCTAssertEqual(snapshot.reasonRaw, "eyes")
        XCTAssertEqual(snapshot.durationSeconds, 20)
        XCTAssertEqual(snapshot.triggeredAt, triggeredAt)
    }

    func test_remainingSeconds_roundsUpAndClampsAtZero() {
        let snapshot = ShieldSessionSnapshot(
            reasonRaw: "eyes",
            durationSeconds: 20,
            triggeredAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(
            snapshot.remainingSeconds(at: Date(timeIntervalSince1970: 109.2)),
            11
        )
        XCTAssertEqual(
            snapshot.remainingSeconds(at: Date(timeIntervalSince1970: 125)),
            0
        )
    }

    func test_remainingSeconds_withoutDurationOrTrigger_returnsNil() {
        let noDuration = ShieldSessionSnapshot(reasonRaw: "eyes", durationSeconds: 0, triggeredAt: Date())
        let noTrigger = ShieldSessionSnapshot(reasonRaw: "eyes", durationSeconds: 20, triggeredAt: nil)

        XCTAssertNil(noDuration.remainingSeconds())
        XCTAssertNil(noTrigger.remainingSeconds())
    }

    func test_copy_eyes_includesCountdownWhenMoreThanFiveSecondsRemain() {
        let snapshot = ShieldSessionSnapshot(
            reasonRaw: "eyes",
            durationSeconds: 20,
            triggeredAt: Date(timeIntervalSince1970: 100)
        )

        let copy = ShieldConfigurationCopy.make(
            for: snapshot,
            now: Date(timeIntervalSince1970: 110)
        )

        XCTAssertEqual(copy.title, "Time for an eye break")
        XCTAssertTrue(copy.subtitle.contains("10 seconds remaining"))
        XCTAssertTrue(copy.subtitle.contains("Look 20 feet away"))
    }

    func test_copy_posture_omitsCountdownAtFiveSecondsOrLess() {
        let snapshot = ShieldSessionSnapshot(
            reasonRaw: "posture",
            durationSeconds: 20,
            triggeredAt: Date(timeIntervalSince1970: 100)
        )

        let copy = ShieldConfigurationCopy.make(
            for: snapshot,
            now: Date(timeIntervalSince1970: 115)
        )

        XCTAssertEqual(copy.title, "Time for a posture break")
        XCTAssertFalse(copy.subtitle.contains("remaining"))
        XCTAssertTrue(copy.subtitle.contains("roll your shoulders"))
    }

    func test_copy_unknownReason_usesGenericBreakCopy() {
        let copy = ShieldConfigurationCopy.make(
            for: ShieldSessionSnapshot(reasonRaw: nil, durationSeconds: 0, triggeredAt: nil)
        )

        XCTAssertEqual(copy.title, "Time for a break")
        XCTAssertEqual(copy.subtitle, "Take a moment away from the screen.")
    }
}
