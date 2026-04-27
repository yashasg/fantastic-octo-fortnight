@testable import EyePostureReminder
import XCTest

/// Extended tests for `ReminderType` — computed display properties, notification
/// identity, and the failable `init(categoryIdentifier:)`.
final class ReminderTypeExtendedTests: XCTestCase {

    // MARK: - symbolName

    func test_eyes_symbolName_isEyeFill() {
        XCTAssertEqual(ReminderType.eyes.symbolName, AppSymbol.eyeBreak)
    }

    func test_posture_symbolName_isFigureStand() {
        XCTAssertEqual(ReminderType.posture.symbolName, AppSymbol.postureCheck)
    }

    // MARK: - title (non-empty)

    func test_eyes_title_isNotEmpty() {
        XCTAssertFalse(ReminderType.eyes.title.isEmpty)
    }

    func test_posture_title_isNotEmpty() {
        XCTAssertFalse(ReminderType.posture.title.isEmpty)
    }

    // MARK: - overlayTitle (non-empty)

    func test_eyes_overlayTitle_isNotEmpty() {
        XCTAssertFalse(ReminderType.eyes.overlayTitle.isEmpty)
    }

    func test_posture_overlayTitle_isNotEmpty() {
        XCTAssertFalse(ReminderType.posture.overlayTitle.isEmpty)
    }

    // MARK: - overlaySupportiveText (non-empty)

    func test_eyes_overlaySupportiveText_isNotEmpty() {
        XCTAssertFalse(ReminderType.eyes.overlaySupportiveText.isEmpty)
    }

    func test_posture_overlaySupportiveText_isNotEmpty() {
        XCTAssertFalse(ReminderType.posture.overlaySupportiveText.isEmpty)
    }

    // MARK: - categoryIdentifier

    func test_eyes_categoryIdentifier_isEYE_REMINDER() {
        XCTAssertEqual(ReminderType.eyes.categoryIdentifier, "EYE_REMINDER")
    }

    func test_posture_categoryIdentifier_isPOSTURE_REMINDER() {
        XCTAssertEqual(ReminderType.posture.categoryIdentifier, "POSTURE_REMINDER")
    }

    func test_categoryIdentifiers_areUnique() {
        let ids = ReminderType.allCases.map(\.categoryIdentifier)
        XCTAssertEqual(ids.count, Set(ids).count, "Category identifiers must be unique")
    }

    // MARK: - notificationTitle (non-empty)

    func test_eyes_notificationTitle_isNotEmpty() {
        XCTAssertFalse(ReminderType.eyes.notificationTitle.isEmpty)
    }

    func test_posture_notificationTitle_isNotEmpty() {
        XCTAssertFalse(ReminderType.posture.notificationTitle.isEmpty)
    }

    // MARK: - notificationBody (non-empty)

    func test_eyes_notificationBody_isNotEmpty() {
        XCTAssertFalse(ReminderType.eyes.notificationBody.isEmpty)
    }

    func test_posture_notificationBody_isNotEmpty() {
        XCTAssertFalse(ReminderType.posture.notificationBody.isEmpty)
    }

    // MARK: - init(categoryIdentifier:)

    func test_initCategoryIdentifier_EYE_REMINDER_returnsEyes() {
        XCTAssertEqual(ReminderType(categoryIdentifier: "EYE_REMINDER"), .eyes)
    }

    func test_initCategoryIdentifier_POSTURE_REMINDER_returnsPosture() {
        XCTAssertEqual(ReminderType(categoryIdentifier: "POSTURE_REMINDER"), .posture)
    }

    func test_initCategoryIdentifier_unknownString_returnsNil() {
        XCTAssertNil(ReminderType(categoryIdentifier: "UNKNOWN"))
    }

    func test_initCategoryIdentifier_emptyString_returnsNil() {
        XCTAssertNil(ReminderType(categoryIdentifier: ""))
    }

    func test_initCategoryIdentifier_lowercased_returnsNil() {
        XCTAssertNil(ReminderType(categoryIdentifier: "eye_reminder"))
    }

    func test_initCategoryIdentifier_roundTrip_eyes() {
        let type = ReminderType.eyes
        XCTAssertEqual(ReminderType(categoryIdentifier: type.categoryIdentifier), type)
    }

    func test_initCategoryIdentifier_roundTrip_posture() {
        let type = ReminderType.posture
        XCTAssertEqual(ReminderType(categoryIdentifier: type.categoryIdentifier), type)
    }

    // MARK: - rawValue

    func test_eyes_rawValue_isEyes() {
        XCTAssertEqual(ReminderType.eyes.rawValue, "eyes")
    }

    func test_posture_rawValue_isPosture() {
        XCTAssertEqual(ReminderType.posture.rawValue, "posture")
    }

    func test_rawValues_areUnique() {
        let raw = ReminderType.allCases.map(\.rawValue)
        XCTAssertEqual(raw.count, Set(raw).count)
    }

    // MARK: - color (non-nil, compile check)

    func test_eyes_color_compiles() {
        _ = ReminderType.eyes.color
    }

    func test_posture_color_compiles() {
        _ = ReminderType.posture.color
    }

    // MARK: - Identifiable

    func test_allCases_idsAreUnique() {
        let ids = ReminderType.allCases.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
