import os

/// App-wide `Logger` categories.
///
/// Usage:
/// ```swift
/// Logger.scheduling.info("Scheduled eye reminder in \(interval)s")
/// Logger.overlay.error("Failed to acquire window scene")
/// ```
///
/// Categories map to Xcode's Console filter sidebar and appear in
/// TestFlight crash reports when testers enable "Share App Data".
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.yashasg.eyeposture"

    /// UNUserNotificationCenter interactions and reminder lifecycle events.
    static let scheduling = Logger(subsystem: subsystem, category: "Scheduling")

    /// UIWindow overlay creation, presentation, and dismissal.
    static let overlay = Logger(subsystem: subsystem, category: "Overlay")

    /// SettingsStore reads/writes and SettingsViewModel actions.
    static let settings = Logger(subsystem: subsystem, category: "Settings")

    /// App/scene lifecycle events (foreground, background, termination).
    static let lifecycle = Logger(subsystem: subsystem, category: "AppLifecycle")
}
