// AccessibilityNotificationPosting.swift
// kshana
//
// Injectable wrapper for UIAccessibility.post so onboarding page transitions
// can announce screen changes to VoiceOver without coupling views to UIKit globals.

import UIKit

/// Abstraction over `UIAccessibility.post` to allow test injection.
protocol AccessibilityNotificationPosting {
    /// Post a `.screenChanged` notification, optionally focusing `element`.
    func postScreenChanged(focusElement: Any?)

    /// Post an `.announcement` notification with the given `message` string.
    func postAnnouncement(message: String)
}

extension AccessibilityNotificationPosting {
    func postScreenChanged() { postScreenChanged(focusElement: nil) }
}

/// Production implementation — delegates directly to `UIAccessibility.post`.
struct LiveAccessibilityNotificationPoster: AccessibilityNotificationPosting {
    func postScreenChanged(focusElement: Any?) {
        UIAccessibility.post(notification: .screenChanged, argument: focusElement)
    }

    func postAnnouncement(message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
