import XCTest
@testable import EyePostureReminder

final class ReminderTypeTests: XCTestCase {

    // MARK: - CaseIterable / Exhaustiveness

    func test_allCases_countIsTwo() {
        XCTAssertEqual(
            ReminderType.allCases.count,
            2,
            "Adding a new ReminderType case requires updating this test and all switch statements.")
    }

    func test_allCases_containsEyes() {
        XCTAssertTrue(ReminderType.allCases.contains(.eyes))
    }

    func test_allCases_containsPosture() {
        XCTAssertTrue(ReminderType.allCases.contains(.posture))
    }

    /// Compile-time guard: this switch must be exhaustive — adding a new case
    /// will produce a compiler error, forcing the developer to handle it here.
    func test_switchExhaustiveness() {
        for type in ReminderType.allCases {
            let handled: Bool
            switch type {
            case .eyes:    handled = true
            case .posture: handled = true
            }
            XCTAssertTrue(handled, "\(type.rawValue) is not handled in switch")
        }
    }

    // MARK: - Identifiable

    func test_eyes_id_equalsRawValue() {
        XCTAssertEqual(ReminderType.eyes.id, "eyes")
    }

    func test_posture_id_equalsRawValue() {
        XCTAssertEqual(ReminderType.posture.id, "posture")
    }

    func test_allCases_idsAreUnique() {
        let ids = ReminderType.allCases.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "All ReminderType IDs must be unique")
    }

    // MARK: - RawValue

    func test_eyes_rawValue() {
        XCTAssertEqual(ReminderType.eyes.rawValue, "eyes")
    }

    func test_posture_rawValue() {
        XCTAssertEqual(ReminderType.posture.rawValue, "posture")
    }

    // MARK: - Category Identifiers

    func test_eyes_categoryIdentifier() {
        XCTAssertEqual(ReminderType.eyes.categoryIdentifier, "EYE_REMINDER")
    }

    func test_posture_categoryIdentifier() {
        XCTAssertEqual(ReminderType.posture.categoryIdentifier, "POSTURE_REMINDER")
    }

    func test_categoryIdentifiers_areUnique() {
        let ids = ReminderType.allCases.map { $0.categoryIdentifier }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    // MARK: - Notification Content (spec compliance)

    func test_eyes_notificationTitle_matchesSpec() {
        XCTAssertEqual(ReminderType.eyes.notificationTitle, "👁 Eye Break")
    }

    func test_eyes_notificationBody_matchesSpec() {
        XCTAssertEqual(ReminderType.eyes.notificationBody, "Look 20 ft away for 20 seconds.")
    }

    func test_posture_notificationTitle_matchesSpec() {
        XCTAssertEqual(ReminderType.posture.notificationTitle, "🧍 Posture Check")
    }

    func test_posture_notificationBody_matchesSpec() {
        XCTAssertEqual(ReminderType.posture.notificationBody, "Sit up straight and roll your shoulders.")
    }

    func test_allCases_notificationTitlesAreNonEmpty() {
        for type in ReminderType.allCases {
            XCTAssertFalse(type.notificationTitle.isEmpty, "\(type.rawValue) has an empty notificationTitle")
        }
    }

    func test_allCases_notificationBodiesAreNonEmpty() {
        for type in ReminderType.allCases {
            XCTAssertFalse(type.notificationBody.isEmpty, "\(type.rawValue) has an empty notificationBody")
        }
    }

    // MARK: - Display Properties

    func test_eyes_title() {
        XCTAssertEqual(ReminderType.eyes.title, "Eye Break")
    }

    func test_posture_title() {
        XCTAssertEqual(ReminderType.posture.title, "Posture Check")
    }

    func test_eyes_symbolName() {
        XCTAssertEqual(ReminderType.eyes.symbolName, "eye")
    }

    func test_posture_symbolName() {
        XCTAssertEqual(ReminderType.posture.symbolName, "figure.stand")
    }

    func test_eyes_overlayTitle_isNonEmpty() {
        XCTAssertFalse(ReminderType.eyes.overlayTitle.isEmpty)
    }

    func test_posture_overlayTitle_isNonEmpty() {
        XCTAssertFalse(ReminderType.posture.overlayTitle.isEmpty)
    }

    func test_overlayTitles_areDistinct() {
        XCTAssertNotEqual(ReminderType.eyes.overlayTitle, ReminderType.posture.overlayTitle)
    }

    // MARK: - Init from categoryIdentifier

    func test_initFromCategoryIdentifier_eyeReminder_returnsEyes() {
        XCTAssertEqual(ReminderType(categoryIdentifier: "EYE_REMINDER"), .eyes)
    }

    func test_initFromCategoryIdentifier_postureReminder_returnsPosture() {
        XCTAssertEqual(ReminderType(categoryIdentifier: "POSTURE_REMINDER"), .posture)
    }

    func test_initFromCategoryIdentifier_unknownString_returnsNil() {
        XCTAssertNil(ReminderType(categoryIdentifier: "UNKNOWN_CATEGORY"))
    }

    func test_initFromCategoryIdentifier_emptyString_returnsNil() {
        XCTAssertNil(ReminderType(categoryIdentifier: ""))
    }

    func test_initFromCategoryIdentifier_lowercased_returnsNil() {
        // Category identifiers are case-sensitive; lowercase should fail.
        XCTAssertNil(ReminderType(categoryIdentifier: "eye_reminder"))
    }

    func test_initFromCategoryIdentifier_roundtrip_forAllCases() {
        for type in ReminderType.allCases {
            let roundtripped = ReminderType(categoryIdentifier: type.categoryIdentifier)
            XCTAssertEqual(
                roundtripped,
                type,
                "Round-trip via categoryIdentifier failed for \(type.rawValue)")
        }
    }
}
