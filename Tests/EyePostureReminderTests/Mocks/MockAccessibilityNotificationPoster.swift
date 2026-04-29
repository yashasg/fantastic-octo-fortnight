@testable import EyePostureReminder

/// Test double for `AccessibilityNotificationPosting`.
/// Records every `postScreenChanged(focusElement:)` call for assertion.
final class MockAccessibilityNotificationPoster: AccessibilityNotificationPosting {

    private(set) var postScreenChangedCallCount = 0
    private(set) var lastFocusElement: Any?

    func postScreenChanged(focusElement: Any?) {
        postScreenChangedCallCount += 1
        lastFocusElement = focusElement
    }

    func reset() {
        postScreenChangedCallCount = 0
        lastFocusElement = nil
    }
}
