@testable import EyePostureReminder
import XCTest

// Tests for AccessibilityNotificationPosting announcement support (#287).
//
// These tests exercise the mock poster directly (no view host required) and
// verify that the announcement API contract holds without coupling to SwiftUI.
final class AccessibilityAnnouncementTests: XCTestCase {

    // MARK: - MockAccessibilityNotificationPoster: baseline (screenChanged)

    func test_mockPoster_initialState_announcementCountIsZero() {
        let mock = MockAccessibilityNotificationPoster()
        XCTAssertEqual(mock.postAnnouncementCallCount, 0)
    }

    func test_mockPoster_initialState_lastAnnouncementMessageIsNil() {
        let mock = MockAccessibilityNotificationPoster()
        XCTAssertNil(mock.lastAnnouncementMessage)
    }

    // MARK: - MockAccessibilityNotificationPoster: announcement recording

    func test_mockPoster_postAnnouncement_incrementsCallCount() {
        let mock = MockAccessibilityNotificationPoster()
        mock.postAnnouncement(message: "Test message")
        XCTAssertEqual(mock.postAnnouncementCallCount, 1)
    }

    func test_mockPoster_postAnnouncement_recordsMessage() {
        let mock = MockAccessibilityNotificationPoster()
        mock.postAnnouncement(message: "Reminders are active")
        XCTAssertEqual(mock.lastAnnouncementMessage, "Reminders are active")
    }

    func test_mockPoster_postAnnouncement_multipleInvocations_countAccumulates() {
        let mock = MockAccessibilityNotificationPoster()
        mock.postAnnouncement(message: "first")
        mock.postAnnouncement(message: "second")
        XCTAssertEqual(mock.postAnnouncementCallCount, 2)
    }

    func test_mockPoster_postAnnouncement_multipleInvocations_lastMessageUpdates() {
        let mock = MockAccessibilityNotificationPoster()
        mock.postAnnouncement(message: "first")
        mock.postAnnouncement(message: "second")
        XCTAssertEqual(mock.lastAnnouncementMessage, "second")
    }

    // MARK: - MockAccessibilityNotificationPoster: reset clears announcement state

    func test_mockPoster_reset_clearsAnnouncementCount() {
        let mock = MockAccessibilityNotificationPoster()
        mock.postAnnouncement(message: "something")
        mock.reset()
        XCTAssertEqual(mock.postAnnouncementCallCount, 0)
    }

    func test_mockPoster_reset_clearsLastAnnouncementMessage() {
        let mock = MockAccessibilityNotificationPoster()
        mock.postAnnouncement(message: "something")
        mock.reset()
        XCTAssertNil(mock.lastAnnouncementMessage)
    }

    func test_mockPoster_reset_preservesIsolation_fromScreenChanged() {
        let mock = MockAccessibilityNotificationPoster()
        mock.postScreenChanged(focusElement: nil)
        mock.postAnnouncement(message: "msg")
        mock.reset()
        XCTAssertEqual(mock.postScreenChangedCallCount, 0)
        XCTAssertEqual(mock.postAnnouncementCallCount, 0)
    }

    // MARK: - LiveAccessibilityNotificationPoster: protocol conformance

    func test_livePoster_conformsToProtocol() {
        let poster: AccessibilityNotificationPosting = LiveAccessibilityNotificationPoster()
        // Compile-time check: calling both methods must type-check.
        // We cannot assert side-effects of UIAccessibility.post in unit tests.
        poster.postAnnouncement(message: "test")
        poster.postScreenChanged(focusElement: nil)
    }

    // MARK: - TrueInterruptSetupPill: callbacks

    func test_trueInterruptSetupPill_onTapIsInvocable() {
        var tapped = false
        let pill = TrueInterruptSetupPill(onTap: { tapped = true })
        pill.onTap()
        XCTAssertTrue(tapped)
    }

    func test_trueInterruptSetupPill_bodyEvaluation() {
        let pill = TrueInterruptSetupPill(onTap: {})
        let described = String(describing: pill.body)
        XCTAssertFalse(described.isEmpty)
    }
}
