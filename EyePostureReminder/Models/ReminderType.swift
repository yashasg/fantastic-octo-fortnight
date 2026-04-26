import SwiftUI

/// Identifies the two reminder types supported by the app.
///
/// Each case carries its own display identity (icon, title, tint) so Views
/// never need to switch on type to render basic UI elements.
enum ReminderType: String, CaseIterable, Identifiable {
    case eyes
    case posture

    var id: String { rawValue }

    // MARK: - Display Properties

    /// SF Symbol name for the reminder type.
    var symbolName: String {
        switch self {
        case .eyes:    return AppSymbol.eyeBreak
        case .posture: return AppSymbol.postureCheck
        }
    }

    /// Human-readable title shown in Settings and on the overlay.
    var title: String {
        switch self {
        case .eyes:    return String(localized: "reminder.eyes.title", bundle: .module)
        case .posture: return String(localized: "reminder.posture.title", bundle: .module)
        }
    }

    /// Tint color used consistently across the app for this type.
    /// Uses Restful Grove semantic tokens: eyes→primaryRest, posture→secondaryCalm.
    var color: Color {
        switch self {
        case .eyes:    return AppColor.primaryRest
        case .posture: return AppColor.secondaryCalm
        }
    }

    // MARK: - Overlay Display

    /// Sentence shown as the headline on the full-screen break overlay.
    var overlayTitle: String {
        switch self {
        case .eyes:    return String(localized: "reminder.eyes.overlayTitle", bundle: .module)
        case .posture: return String(localized: "reminder.posture.overlayTitle", bundle: .module)
        }
    }

    // MARK: - Notification Identity

    /// Category identifier registered with `UNUserNotificationCenter`.
    var categoryIdentifier: String {
        switch self {
        case .eyes:    return "EYE_REMINDER"
        case .posture: return "POSTURE_REMINDER"
        }
    }

    /// Human-readable notification title (shown in banners / lock screen).
    var notificationTitle: String {
        switch self {
        case .eyes:    return String(localized: "reminder.eyes.notificationTitle", bundle: .module)
        case .posture: return String(localized: "reminder.posture.notificationTitle", bundle: .module)
        }
    }

    /// Notification body copy.
    var notificationBody: String {
        switch self {
        case .eyes:    return String(localized: "reminder.eyes.notificationBody", bundle: .module)
        case .posture: return String(localized: "reminder.posture.notificationBody", bundle: .module)
        }
    }

    /// Initialise from a `UNNotification` category identifier. Returns `nil` for unknown values.
    init?(categoryIdentifier: String) {
        switch categoryIdentifier {
        case "EYE_REMINDER":     self = .eyes
        case "POSTURE_REMINDER": self = .posture
        default:                 return nil
        }
    }
}
