@testable import EyePostureReminder
@testable import ScreenTimeExtensionShared
import XCTest

/// Pre-implementation validation tests for M3.5 "DeviceActivity Monitoring Service" (#205).
///
/// ## Purpose
/// These tests lock down the data contracts and integration seams that Basher's
/// `DeviceActivityMonitorService` must honour before the implementation exists.
/// All tests are compile-safe, simulator-runnable, and entitlement-free.
///
/// ## What is NOT tested here
/// - `DeviceActivityCenter` / `ManagedSettings` / `FamilyControls` — blocked by #201.
/// - Real App Group `UserDefaults` (`group.com.yashasg.kshana`) — requires device + entitlement.
/// - Extension process lifecycle — requires Xcode project migration (M3.3).
///
/// ## Coverage targets
/// 1. App Group UserDefaults serialisation round-trip for `ShieldSession` (single payload key).
/// 2. `ReminderType` → `ShieldTriggerReason` raw-value alignment (implicit bridge contract).
/// 3. `ScreenTimeShieldProviding.isAvailable` guard — only begin monitoring when available.
/// 4. `MockScreenTimeShieldProviding` captures the correct `ShieldSession` payload.
/// 5. Noop conformance to `ServiceLifecycle` — idempotent start/stop for the protocol slot.
@MainActor
final class DeviceActivityMonitoringValidationTests: XCTestCase {

    // MARK: - Infrastructure

    private let suiteName = "com.yashasg.kshana.test.deviceActivityMonitoring"
    private var testDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        testDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - 1. App Group UserDefaults Serialisation Round-Trip

    /// The `DeviceActivityMonitorExtension` reads this single payload key from the shared
    /// App Group in `intervalDidStart(for:)` to populate the shield UI. Basher's
    /// `DeviceActivityMonitorService.beginShield(for:)` must write it atomically; a key
    /// name or payload mismatch causes a silent blank shield.
    func test_shieldSession_appGroupWrite_payloadRoundTrips() throws {
        let session = makeEyesSession()
        try writeShieldSession(session, to: testDefaults)

        let data = try XCTUnwrap(
            testDefaults.data(forKey: ShieldSession.sessionDataKey),
            "sessionDataKey must store the encoded ShieldSessionSnapshot payload"
        )
        let snapshot = try ShieldSessionSnapshot.decode(from: data)
        XCTAssertEqual(snapshot.reasonRaw, ShieldTriggerReason.scheduledEyesBreak.rawValue)
        XCTAssertEqual(snapshot.durationSeconds, session.durationSeconds, accuracy: 0.001)
        let triggeredAtSeconds = try XCTUnwrap(snapshot.triggeredAt?.timeIntervalSince1970)
        XCTAssertEqual(
            triggeredAtSeconds,
            session.triggeredAt.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func test_shieldSession_appGroupWrite_doesNotUseLegacySplitKeys() throws {
        let session = makeSession(reason: .scheduledPostureBreak, duration: 30)
        try writeShieldSession(session, to: testDefaults)

        XCTAssertNil(testDefaults.object(forKey: ShieldSession.reasonKey))
        XCTAssertNil(testDefaults.object(forKey: ShieldSession.durationKey))
        XCTAssertNil(testDefaults.object(forKey: ShieldSession.triggeredAtKey))
    }

    /// Extension reads must fail safe when no session payload has been written.
    func test_shieldSession_appGroupRead_missingPayload_returnsEmptySnapshot() {
        let snapshot = ShieldSessionSnapshot.read(from: testDefaults)
        XCTAssertEqual(snapshot, .empty)
    }

    /// Clearing the shield must remove the payload and legacy keys so a stale extension read
    /// doesn't re-apply an old break session.
    func test_shieldSession_appGroupClear_removesAllKeys() throws {
        try writeShieldSession(makeEyesSession(), to: testDefaults)
        clearShieldSession(from: testDefaults)

        XCTAssertNil(testDefaults.data(forKey: ShieldSession.sessionDataKey))
        XCTAssertNil(testDefaults.string(forKey: ShieldSession.reasonKey))
        XCTAssertEqual(testDefaults.double(forKey: ShieldSession.durationKey), 0,
                       "durationKey should be absent (double returns 0 when missing)")
        XCTAssertEqual(testDefaults.double(forKey: ShieldSession.triggeredAtKey), 0,
                       "triggeredAtKey should be absent (double returns 0 when missing)")
    }

    // MARK: - 2. ReminderType → ShieldTriggerReason Bridge Contract

    /// `ScreenTimeTracker.onThresholdReached` delivers a `ReminderType`.
    /// Basher's service must map this to a `ShieldTriggerReason` to build the session.
    /// This test pins the raw values so the implicit mapping `.eyes → "eyes"` never silently breaks.
    func test_reminderType_eyes_rawValue_matchesShieldTriggerReason() {
        XCTAssertEqual(
            ReminderType.eyes.rawValue,
            ShieldTriggerReason.scheduledEyesBreak.rawValue,
            "ReminderType.eyes.rawValue must equal ShieldTriggerReason.scheduledEyesBreak.rawValue — " +
            "Basher's mapping relies on this alignment"
        )
    }

    func test_reminderType_posture_rawValue_matchesShieldTriggerReason() {
        XCTAssertEqual(
            ReminderType.posture.rawValue,
            ShieldTriggerReason.scheduledPostureBreak.rawValue,
            "ReminderType.posture.rawValue must equal ShieldTriggerReason.scheduledPostureBreak.rawValue"
        )
    }

    /// All `ReminderType` cases must have a corresponding `ShieldTriggerReason`.
    /// If a new reminder type is added without a corresponding shield reason, this fails.
    func test_reminderType_allCases_haveCorrespondingShieldTriggerReason() {
        for type in ReminderType.allCases {
            let reason = ShieldTriggerReason(rawValue: type.rawValue)
            XCTAssertNotNil(
                reason,
                "ReminderType.\(type.rawValue) has no matching ShieldTriggerReason — " +
                "add the case before Basher's threshold→shield bridge can handle it"
            )
        }
    }

    // MARK: - 3. isAvailable Guard — Only Schedule When Available

    /// `DeviceActivityCenter.startMonitoring` must only be called when the provider
    /// reports `isAvailable == true`. The noop (pre-entitlement) must never trigger
    /// a `DeviceActivityCenter` call.
    func test_noopShield_isUnavailable_preventsBeginShieldSideEffects() async throws {
        let noop = ScreenTimeShieldNoop()
        XCTAssertFalse(noop.isAvailable)

        // Calling beginShield on noop must be a no-op (no DeviceActivityCenter call)
        try await noop.beginShield(for: makeEyesSession())
        // If we get here without a crash or side-effect, the guard is correct.
    }

    func test_mockShield_isUnavailable_beginShieldStillRecordsCall() async throws {
        let mock = MockScreenTimeShieldProviding()
        mock.isAvailable = false

        // Even when unavailable, the mock records the call — callers must guard before invoking.
        try await mock.beginShield(for: makeEyesSession())
        XCTAssertEqual(mock.beginShieldCallCount, 1,
                       "Mock always records; real DeviceActivityMonitorService must guard on isAvailable")
    }

    func test_mockShield_isAvailable_beginShield_recordsCorrectSession() async throws {
        let mock = MockScreenTimeShieldProviding()
        mock.isAvailable = true

        let fixedDate = Date(timeIntervalSince1970: 2_000_000)
        let session = ShieldSession(reason: .scheduledEyesBreak, durationSeconds: 20, triggeredAt: fixedDate)
        try await mock.beginShield(for: session)

        let captured = try XCTUnwrap(mock.lastSession)
        XCTAssertEqual(captured.reason, .scheduledEyesBreak)
        XCTAssertEqual(captured.durationSeconds, 20)
        XCTAssertEqual(captured.triggeredAt, fixedDate)
    }

    // MARK: - 4. ServiceLifecycle Slot — Noop Idempotency

    /// Basher's `DeviceActivityMonitorService` must conform to `ServiceLifecycle`.
    /// The noop occupies that slot today; these tests validate the protocol contract
    /// that the real implementation must also satisfy (start/stop must be idempotent).
    func test_noopShield_startMonitoring_isIdempotent() {
        let noop = ScreenTimeShieldNoop()
        noop.startMonitoring()
        noop.startMonitoring()  // second call must not crash
    }

    func test_noopShield_stopMonitoring_withoutStart_doesNotCrash() {
        let noop = ScreenTimeShieldNoop()
        noop.stopMonitoring()
    }

    func test_noopShield_stopAfterStart_isIdempotent() {
        let noop = ScreenTimeShieldNoop()
        noop.startMonitoring()
        noop.stopMonitoring()
        noop.stopMonitoring()  // double-stop must not crash
    }

    /// `ScreenTimeShieldNoop` must be usable as a `ServiceLifecycle` — the same
    /// protocol slot Basher's concrete service will occupy.
    func test_noopShield_conformsToServiceLifecycle_polymorphically() {
        let service: any ServiceLifecycle = ScreenTimeShieldNoop()
        service.startMonitoring()
        service.stopMonitoring()
    }

    // MARK: - 5. endShield Does Not Throw When No Session Active

    /// Calling `endShield` without a prior `beginShield` must be safe.
    /// The real `DeviceActivityMonitorService` must handle this on every break
    /// dismiss path (× button, auto-dismiss, snooze) without crashing.
    func test_noopShield_endShield_withoutBegin_doesNotThrow() async throws {
        let noop = ScreenTimeShieldNoop()
        try await noop.endShield()
    }

    func test_mockShield_endShield_withoutBegin_recordsCall() async throws {
        let mock = MockScreenTimeShieldProviding()
        try await mock.endShield()
        XCTAssertEqual(mock.endShieldCallCount, 1)
    }

    // MARK: - Helpers

    private func makeEyesSession() -> ShieldSession {
        makeSession(reason: .scheduledEyesBreak, duration: 20)
    }

    private func makeSession(reason: ShieldTriggerReason, duration: TimeInterval) -> ShieldSession {
        ShieldSession(reason: reason, durationSeconds: duration, triggeredAt: Date())
    }

    /// Simulates what `DeviceActivityMonitorService.beginShield(for:)` must write
    /// to the shared App Group `UserDefaults` before calling
    /// `DeviceActivityCenter.startMonitoring(...)`.
    private func writeShieldSession(_ session: ShieldSession, to defaults: UserDefaults) throws {
        let data = try ShieldSessionSnapshot.encodedData(
            reasonRaw: session.reason.rawValue,
            durationSeconds: session.durationSeconds,
            triggeredAt: session.triggeredAt
        )
        defaults.set(data, forKey: ShieldSession.sessionDataKey)
    }

    /// Simulates what `DeviceActivityMonitorService.endShield()` must do to prevent
    /// the extension from re-reading a stale session on the next `intervalDidStart`.
    private func clearShieldSession(from defaults: UserDefaults) {
        defaults.removeObject(forKey: ShieldSession.sessionDataKey)
        defaults.removeObject(forKey: ShieldSession.reasonKey)
        defaults.removeObject(forKey: ShieldSession.durationKey)
        defaults.removeObject(forKey: ShieldSession.triggeredAtKey)
    }
}
