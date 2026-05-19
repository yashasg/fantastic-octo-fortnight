import ComposableArchitecture
import Foundation
import UserNotifications

/// TCA dependency client wrapping `UNUserNotificationCenter` for reducer
/// consumption.
///
/// Phase 0 of the TCA migration (#665). The `liveValue` adapter
/// forwards every call to `UNUserNotificationCenter.current()`, matching the
/// signatures expected by Phase 1 reducers.
@DependencyClient
struct NotificationClient: Sendable {
    /// Requests authorisation with the given options. Returns whether the user
    /// granted at least the requested set.
    var requestAuthorization: @Sendable (UNAuthorizationOptions) async throws -> Bool

    /// Returns the current authorisation status without prompting.
    var authorizationStatus: @Sendable () async -> UNAuthorizationStatus = { .notDetermined }

    /// Adds a new notification request to the system queue.
    var add: @Sendable (UNNotificationRequest) async throws -> Void

    /// Removes pending notifications by identifier.
    var removePending: @Sendable ([String]) async -> Void

    /// Removes every pending notification.
    var removeAllPending: @Sendable () async -> Void

    /// Returns the currently queued (pending) notification requests.
    var pendingRequests: @Sendable () async -> [UNNotificationRequest] = { [] }

    /// Returns the currently delivered notifications still in Notification Center.
    var deliveredNotifications: @Sendable () async -> [UNNotification] = { [] }
}

extension NotificationClient: DependencyKey {
    static let liveValue = NotificationClient(
        requestAuthorization: { options in
            try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        },
        authorizationStatus: {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        },
        add: { request in
            try await UNUserNotificationCenter.current().add(request)
        },
        removePending: { identifiers in
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: identifiers)
        },
        removeAllPending: {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        },
        pendingRequests: {
            await UNUserNotificationCenter.current().pendingNotificationRequests()
        },
        deliveredNotifications: {
            await UNUserNotificationCenter.current().deliveredNotifications()
        }
    )
}

extension DependencyValues {
    /// TCA accessor for the shared `NotificationClient`.
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
