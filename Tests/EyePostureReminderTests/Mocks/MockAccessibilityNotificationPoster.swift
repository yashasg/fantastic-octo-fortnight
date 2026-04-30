@testable import EyePostureReminder

/// Test double for `AccessibilityNotificationPosting`.
/// Records every `postScreenChanged(focusElement:)` and `postAnnouncement(message:)` call.
final class MockAccessibilityNotificationPoster: AccessibilityNotificationPosting {

    private(set) var postScreenChangedCallCount = 0
    private(set) var lastFocusElement: Any?

    private(set) var postAnnouncementCallCount = 0
    private(set) var lastAnnouncementMessage: String?

    func postScreenChanged(focusElement: Any?) {
        postScreenChangedCallCount += 1
        lastFocusElement = focusElement
    }

    func postAnnouncement(message: String) {
        postAnnouncementCallCount += 1
        lastAnnouncementMessage = message
    }

    func reset() {
        postScreenChangedCallCount = 0
        lastFocusElement = nil
        postAnnouncementCallCount = 0
        lastAnnouncementMessage = nil
    }
}
