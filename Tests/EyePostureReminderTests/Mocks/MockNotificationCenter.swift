import Foundation
import UserNotifications
@testable import EyePostureReminder

/// Mock implementation of `NotificationScheduling` for unit tests.
///
/// - `addedRequests`: full history of every `add()` call (never cleared on remove).
/// - `pendingRequests`: simulates the live notification queue — add adds, remove removes.
/// - `removedIdentifiers`: history of each `removePendingNotificationRequests` call.
/// - `removeAllCallCount`: number of times `removeAllPendingNotificationRequests` was called.
final class MockNotificationCenter: NotificationScheduling {

    // MARK: - Call History

    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var pendingRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [[String]] = []
    private(set) var removeAllCallCount = 0
    private(set) var authorizationRequestCount = 0

    // MARK: - Configuration

    var authorizationGranted = true
    var authorizationError: Error?
    var addError: Error?

    // MARK: - Reset

    func reset() {
        addedRequests = []
        pendingRequests = []
        removedIdentifiers = []
        removeAllCallCount = 0
        authorizationRequestCount = 0
        authorizationError = nil
        addError = nil
    }

    // MARK: - NotificationScheduling

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequestCount += 1
        if let error = authorizationError { throw error }
        return authorizationGranted
    }

    func add(_ request: UNNotificationRequest) async throws {
        if let error = addError { throw error }
        addedRequests.append(request)
        pendingRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func removeAllPendingNotificationRequests() {
        removeAllCallCount += 1
        pendingRequests.removeAll()
    }

    func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        return pendingRequests
    }
}
