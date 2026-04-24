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
        case .eyes:    return "eye"
        case .posture: return "figure.stand"
        }
    }

    /// Human-readable title shown in Settings and on the overlay.
    var title: String {
        switch self {
        case .eyes:    return "Eye Break"
        case .posture: return "Posture Check"
        }
    }

    /// Tint color used consistently across the app for this type.
    /// Uses DesignSystem semantic tokens for visual consistency.
    var color: Color {
        switch self {
        case .eyes:    return AppColor.reminderBlue
        case .posture: return AppColor.reminderGreen
        }
    }

    // MARK: - Overlay Display

    /// Sentence shown as the headline on the full-screen break overlay.
    var overlayTitle: String {
        switch self {
        case .eyes:    return "Time to rest your eyes"
        case .posture: return "Time to check your posture"
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
        case .eyes:    return "👁 Eye Break"
        case .posture: return "🧍 Posture Check"
        }
    }

    /// Notification body copy.
    var notificationBody: String {
        switch self {
        case .eyes:    return "Look 20 ft away for 20 seconds."
        case .posture: return "Sit up straight and roll your shoulders."
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
