@testable import EyePostureReminder
import Foundation

/// Mock implementation of `DeviceActivityMonitorProviding` for unit tests.
///
/// Allows tests to control `isAvailable` and `activeSession` directly and verify
/// that `scheduleBreakMonitoring(for:)` and `cancelBreakMonitoring()` are called
/// the expected number of times with the expected arguments.
///
/// Never imports or instantiates `DeviceActivity`, `ManagedSettings`, or `FamilyControls`.
@MainActor
final class MockDeviceActivityMonitorProviding: DeviceActivityMonitorProviding {

    // MARK: - Stub state

    /// Controllable availability returned to callers. Default `false` to match
    /// the pre-entitlement production default.
    var stubbedIsAvailable: Bool = false
    var isAvailable: Bool { stubbedIsAvailable }

    /// The last session passed to `scheduleBreakMonitoring(for:)`, or `nil`.
    private(set) var activeSession: ShieldSession?

    // MARK: - Error stubs

    /// When non-nil, `scheduleBreakMonitoring(for:)` throws this error.
    var stubbedScheduleError: Error?
    var scheduleDelayNanoseconds: UInt64 = 0
    /// When non-nil, `cancelBreakMonitoring()` throws this error.
    var stubbedCancelError: Error?

    // MARK: - Call recording

    private(set) var scheduleCallCount = 0
    private(set) var scheduledSessions: [ShieldSession] = []

    private(set) var cancelCallCount = 0
    private(set) var operationLog: [String] = []

    private(set) var startMonitoringCallCount = 0
    private(set) var stopMonitoringCallCount = 0

    // MARK: - Protocol conformance

    func scheduleBreakMonitoring(for session: ShieldSession) async throws {
        scheduleCallCount += 1
        operationLog.append("schedule")
        scheduledSessions.append(session)
        if scheduleDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: scheduleDelayNanoseconds)
        }
        if let error = stubbedScheduleError { throw error }
        activeSession = session
    }

    func cancelBreakMonitoring() async throws {
        cancelCallCount += 1
        operationLog.append("cancel")
        if let error = stubbedCancelError { throw error }
        activeSession = nil
    }

    // MARK: - ServiceLifecycle

    func startMonitoring() {
        startMonitoringCallCount += 1
    }

    func stopMonitoring() {
        stopMonitoringCallCount += 1
    }

    // MARK: - Helpers

    func reset() {
        stubbedIsAvailable = false
        stubbedScheduleError = nil
        scheduleDelayNanoseconds = 0
        stubbedCancelError = nil
        activeSession = nil
        scheduleCallCount = 0
        scheduledSessions = []
        cancelCallCount = 0
        operationLog = []
        startMonitoringCallCount = 0
        stopMonitoringCallCount = 0
    }
}
