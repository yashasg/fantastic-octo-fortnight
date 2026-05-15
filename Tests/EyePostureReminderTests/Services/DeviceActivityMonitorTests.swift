import XCTest

@testable import EyePostureReminder

/// Unit tests for the DeviceActivity monitoring service layer added in #205.
///
/// Tests validate:
/// - `DeviceActivityMonitorNoop` compile-safe behaviour (no FamilyControls required)
/// - `DeviceActivityMonitorProviding` protocol contract via `MockDeviceActivityMonitorProviding`
/// - `ShieldSession(type:durationSeconds:triggeredAt:)` convenience initialiser
/// - `AppCoordinator` integration: `deviceActivityMonitor` is called on threshold
///   (when `isAvailable` is true) and on `cancelAllReminders()`
///
/// No test imports or instantiates `DeviceActivity`, `ManagedSettings`, or `FamilyControls`.
/// All tests are safe to run in the iOS Simulator and SPM test host.
@MainActor
final class DeviceActivityMonitorTests: XCTestCase {

    // MARK: - DeviceActivityMonitorNoop

    func test_noop_isAvailable_returnsFalse() {
        let sut = DeviceActivityMonitorNoop()
        XCTAssertFalse(sut.isAvailable)
    }

    func test_noop_activeSession_isNilInitially() {
        let sut = DeviceActivityMonitorNoop()
        XCTAssertNil(sut.activeSession)
    }

    func test_noop_scheduleBreakMonitoring_doesNotThrow() async throws {
        let sut = DeviceActivityMonitorNoop()
        let session = makeSession()
        try await sut.scheduleBreakMonitoring(for: session)
    }

    func test_noop_scheduleBreakMonitoring_doesNotUpdateActiveSession() async throws {
        let sut = DeviceActivityMonitorNoop()
        let session = makeSession()
        try await sut.scheduleBreakMonitoring(for: session)
        // Noop never sets activeSession — it has no state to manage.
        XCTAssertNil(sut.activeSession)
    }

    func test_noop_cancelBreakMonitoring_doesNotThrow() async throws {
        let sut = DeviceActivityMonitorNoop()
        try await sut.cancelBreakMonitoring()
    }

    func test_noop_cancelBreakMonitoring_whenNoSessionActive_doesNotThrow() async throws {
        let sut = DeviceActivityMonitorNoop()
        // Idempotent cancel — no session was ever scheduled.
        try await sut.cancelBreakMonitoring()
        XCTAssertNil(sut.activeSession)
    }

    func test_noop_startAndStopMonitoring_doNotCrash() {
        let sut = DeviceActivityMonitorNoop()
        sut.startMonitoring()
        sut.stopMonitoring()
    }

    // MARK: - ShieldSession convenience init from ReminderType

    func test_shieldSession_fromEyesType_setsEyesReason() {
        let session = ShieldSession(type: .eyes, durationSeconds: 20)
        XCTAssertEqual(session.reason, .scheduledEyesBreak)
    }

    func test_shieldSession_fromPostureType_setsPostureReason() {
        let session = ShieldSession(type: .posture, durationSeconds: 30)
        XCTAssertEqual(session.reason, .scheduledPostureBreak)
    }

    func test_shieldSession_fromType_preservesDurationSeconds() {
        let session = ShieldSession(type: .eyes, durationSeconds: 42)
        XCTAssertEqual(session.durationSeconds, 42)
    }

    func test_shieldSession_fromType_usesProvidedTriggeredAt() {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let session = ShieldSession(type: .posture, durationSeconds: 20, triggeredAt: fixedDate)
        XCTAssertEqual(session.triggeredAt, fixedDate)
    }

    func test_shieldSession_fromType_whenTriggeredAtMissing_usesFactory() {
        var factoryCallCount = 0
        let expectedDate = Date(timeIntervalSince1970: 1_234_567)
        let session = ShieldSession(
            type: .eyes,
            durationSeconds: 20,
            makeTriggeredAt: {
                factoryCallCount += 1
                return expectedDate
            }
        )
        XCTAssertEqual(session.triggeredAt, expectedDate)
        XCTAssertEqual(factoryCallCount, 1)
    }

    func test_shieldSession_fromType_whenTriggeredAtProvided_bypassesFactory() {
        var factoryCallCount = 0
        let providedDate = Date(timeIntervalSince1970: 2_468_000)
        let session = ShieldSession(
            type: .posture,
            durationSeconds: 20,
            triggeredAt: providedDate,
            makeTriggeredAt: {
                factoryCallCount += 1
                return Date(timeIntervalSince1970: 0)
            }
        )
        XCTAssertEqual(session.triggeredAt, providedDate)
        XCTAssertEqual(factoryCallCount, 0)
    }

    func test_shieldSession_fromType_defaultsTriggeredAtToNow() {
        let before = Date()
        let session = ShieldSession(type: .eyes, durationSeconds: 20)
        let after = Date()
        XCTAssertGreaterThanOrEqual(session.triggeredAt, before)
        XCTAssertLessThanOrEqual(session.triggeredAt, after)
    }

    func test_shieldSession_fromType_equality_sameValues() {
        let date = Date(timeIntervalSince1970: 5_000)
        let first = ShieldSession(type: .eyes, durationSeconds: 20, triggeredAt: date)
        let second = ShieldSession(type: .eyes, durationSeconds: 20, triggeredAt: date)
        XCTAssertEqual(first, second)
    }

    // MARK: - MockDeviceActivityMonitorProviding

    func test_mock_defaultIsAvailable_isFalse() {
        let mock = MockDeviceActivityMonitorProviding()
        XCTAssertFalse(mock.isAvailable)
    }

    func test_mock_stubbedIsAvailable_returnsTrue() {
        let mock = MockDeviceActivityMonitorProviding()
        mock.stubbedIsAvailable = true
        XCTAssertTrue(mock.isAvailable)
    }

    func test_mock_activeSession_nilInitially() {
        let mock = MockDeviceActivityMonitorProviding()
        XCTAssertNil(mock.activeSession)
    }

    func test_mock_scheduleBreakMonitoring_incrementsCallCount() async throws {
        let mock = MockDeviceActivityMonitorProviding()
        XCTAssertEqual(mock.scheduleCallCount, 0)
        try await mock.scheduleBreakMonitoring(for: makeSession())
        XCTAssertEqual(mock.scheduleCallCount, 1)
        try await mock.scheduleBreakMonitoring(for: makeSession())
        XCTAssertEqual(mock.scheduleCallCount, 2)
    }

    func test_mock_scheduleBreakMonitoring_recordsSession() async throws {
        let mock = MockDeviceActivityMonitorProviding()
        let session = makeSession(type: .eyes, duration: 20)
        try await mock.scheduleBreakMonitoring(for: session)
        XCTAssertEqual(mock.scheduledSessions.count, 1)
        XCTAssertEqual(mock.scheduledSessions.first, session)
    }

    func test_mock_scheduleBreakMonitoring_setsActiveSession() async throws {
        let mock = MockDeviceActivityMonitorProviding()
        let session = makeSession(type: .posture, duration: 30)
        try await mock.scheduleBreakMonitoring(for: session)
        XCTAssertEqual(mock.activeSession, session)
    }

    func test_mock_scheduleBreakMonitoring_throwsWhenStubbed() async {
        let mock = MockDeviceActivityMonitorProviding()
        struct TestError: Error {}
        mock.stubbedScheduleError = TestError()
        do {
            try await mock.scheduleBreakMonitoring(for: makeSession())
            XCTFail("Expected throw")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func test_mock_cancelBreakMonitoring_incrementsCallCount() async throws {
        let mock = MockDeviceActivityMonitorProviding()
        XCTAssertEqual(mock.cancelCallCount, 0)
        try await mock.cancelBreakMonitoring()
        XCTAssertEqual(mock.cancelCallCount, 1)
    }

    func test_mock_cancelBreakMonitoring_clearsActiveSession() async throws {
        let mock = MockDeviceActivityMonitorProviding()
        try await mock.scheduleBreakMonitoring(for: makeSession())
        XCTAssertNotNil(mock.activeSession)
        try await mock.cancelBreakMonitoring()
        XCTAssertNil(mock.activeSession)
    }

    func test_mock_cancelBreakMonitoring_throwsWhenStubbed() async {
        let mock = MockDeviceActivityMonitorProviding()
        struct TestError: Error {}
        mock.stubbedCancelError = TestError()
        do {
            try await mock.cancelBreakMonitoring()
            XCTFail("Expected throw")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func test_mock_reset_restoresDefaults() async throws {
        let mock = MockDeviceActivityMonitorProviding()
        mock.stubbedIsAvailable = true
        try await mock.scheduleBreakMonitoring(for: makeSession())
        try await mock.cancelBreakMonitoring()
        mock.reset()
        XCTAssertFalse(mock.isAvailable)
        XCTAssertNil(mock.activeSession)
        XCTAssertEqual(mock.scheduleCallCount, 0)
        XCTAssertEqual(mock.cancelCallCount, 0)
        XCTAssertTrue(mock.scheduledSessions.isEmpty)
    }

    // MARK: - AppCoordinator integration
    //
    // Follow-up #680: rewrite the deleted coverage as `SchedulingFeature`
    // TestStore assertions. The previous tests in this section constructed
    // an `AppCoordinator` directly to verify that `cancelAllReminders()` /
    // threshold scheduling correctly delegated to `DeviceActivityMonitor`.
    // After `#755` Phase E removed the coordinator stack, the same wiring
    // now lives in `SchedulingFeature` (see `cancelRemindersEffect` and
    // `notificationRoutedEffect`) and should be covered with TCA-native
    // assertions instead of resurrected here.

    // MARK: - Helpers

    private func makeSession(
        type: ReminderType = .eyes,
        duration: TimeInterval = 20
    ) -> ShieldSession {
        ShieldSession(type: type, durationSeconds: duration)
    }

    private func makeSettings() -> SettingsStore {
        SettingsStore(store: MockSettingsPersisting())
    }
}
