@testable import EyePostureReminder
import XCTest

/// Tests for `PauseConditionSource` and `LegalDocument` enums.
final class PauseConditionSourceTests: XCTestCase {

    // MARK: - PauseConditionSource: Raw Values

    func test_pauseConditionSource_focusMode_rawValue() {
        XCTAssertEqual(PauseConditionSource.focusMode.rawValue, "focus_mode")
    }

    func test_pauseConditionSource_carPlay_rawValue() {
        XCTAssertEqual(PauseConditionSource.carPlay.rawValue, "car_play")
    }

    func test_pauseConditionSource_driving_rawValue() {
        XCTAssertEqual(PauseConditionSource.driving.rawValue, "driving")
    }

    func test_pauseConditionSource_rawValues_areStableSnakeCase() {
        // Pin all raw values to guard against accidental renames breaking analytics.
        let expected: [(PauseConditionSource, String)] = [
            (.focusMode, "focus_mode"),
            (.carPlay,   "car_play"),
            (.driving,   "driving")
        ]
        for (source, expectedRaw) in expected {
            XCTAssertEqual(source.rawValue, expectedRaw,
                           "PauseConditionSource.\(source) raw value must be stable for analytics")
        }
    }

    // MARK: - PauseConditionSource

    func test_pauseConditionSource_focusMode_isHashable() {
        var set = Set<PauseConditionSource>()
        set.insert(.focusMode)
        XCTAssertTrue(set.contains(.focusMode))
    }

    func test_pauseConditionSource_carPlay_isHashable() {
        var set = Set<PauseConditionSource>()
        set.insert(.carPlay)
        XCTAssertTrue(set.contains(.carPlay))
    }

    func test_pauseConditionSource_driving_isHashable() {
        var set = Set<PauseConditionSource>()
        set.insert(.driving)
        XCTAssertTrue(set.contains(.driving))
    }

    func test_pauseConditionSource_allCases_areDistinct() {
        let all: [PauseConditionSource] = [.focusMode, .carPlay, .driving]
        XCTAssertEqual(Set(all).count, 3, "All PauseConditionSource cases must be distinct")
    }

    func test_pauseConditionSource_setOperations_workCorrectly() {
        var active = Set<PauseConditionSource>()
        active.insert(.focusMode)
        active.insert(.driving)
        XCTAssertTrue(active.contains(.focusMode))
        XCTAssertTrue(active.contains(.driving))
        XCTAssertFalse(active.contains(.carPlay))

        active.remove(.focusMode)
        XCTAssertFalse(active.contains(.focusMode))
        XCTAssertEqual(active.count, 1)
    }

    // MARK: - LegalDocument

    func test_legalDocument_terms_exists() {
        let doc = LegalDocument.terms
        _ = doc
    }

    func test_legalDocument_privacy_exists() {
        let doc = LegalDocument.privacy
        _ = doc
    }

    func test_legalDocument_disclaimer_exists() {
        let doc = LegalDocument.disclaimer
        _ = doc
    }

    func test_legalDocument_switchExhaustiveness() {
        let docs: [LegalDocument] = [.terms, .privacy, .disclaimer]
        for doc in docs {
            switch doc {
            case .terms:   XCTAssertTrue(true)
            case .privacy:    XCTAssertTrue(true)
            case .disclaimer: XCTAssertTrue(true)
            }
        }
    }
}
