@testable import EyePostureReminder
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
/// - Real App Group `UserDefaults` (`group.com.yashasgujjar.kshana`) — requires device + entitlement.
/// - Extension process lifecycle — requires Xcode project migration (M3.3).
///
/// ## Coverage targets
/// 1. App Group UserDefaults serialisation round-trip for `ShieldSession` (three keys).
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

    /// The `DeviceActivityMonitorExtension` reads these three keys from the shared
    /// App Group in `intervalDidStart(for:)` to populate the shield UI.
    /// Basher's `DeviceActivityMonitorService.beginShield(for:)` must write them
    /// in this exact format; a key name or type mismatch causes a silent blank shield.
    func test_shieldSession_appGroupWrite_reasonKey_roundTrips() {
        let session = makeEyesSession()
        writeShieldSession(session, to: testDefaults)

        let rawValue = testDefaults.string(forKey: ShieldSession.reasonKey)
        XCTAssertEqual(rawValue, ShieldTriggerReason.scheduledEyesBreak.rawValue,
                       "reasonKey must store the ShieldTriggerReason raw value as a String")
    }

    func test_shieldSession_appGroupWrite_durationKey_roundTrips() {
        let session = makeSession(reason: .scheduledPostureBreak, duration: 30)
        writeShieldSession(session, to: testDefaults)

        let stored = testDefaults.double(forKey: ShieldSession.durationKey)
        XCTAssertEqual(stored, 30, accuracy: 0.001,
                       "durationKey must persist durationSeconds as a Double")
    }

    func test_shieldSession_appGroupWrite_triggeredAtKey_roundTrips() {
        let fixedDate = Date(timeIntervalSince1970: 1_000_000)
        let session = ShieldSession(reason: .scheduledEyesBreak, durationSeconds: 20, triggeredAt: fixedDate)
        writeShieldSession(session, to: testDefaults)

        let stored = testDefaults.double(forKey: ShieldSession.triggeredAtKey)
        XCTAssertEqual(stored, fixedDate.timeIntervalSince1970, accuracy: 0.001,
                       "triggeredAtKey must persist the date as a timeIntervalSince1970 Double")
    }

    /// Extension reads reason key first; a missing key must not crash the extension.
    func test_shieldSession_appGroupRead_missingReasonKey_returnsNil() {
        let rawValue = testDefaults.string(forKey: ShieldSession.reasonKey)
        XCTAssertNil(rawValue, "No session written — reasonKey must be absent")
    }

    /// Clearing the shield must remove all three keys so a stale extension read
    /// doesn't re-apply an old break session.
    func test_shieldSession_appGroupClear_removesAllKeys() {
        writeShieldSession(makeEyesSession(), to: testDefaults)
        clearShieldSession(from: testDefaults)

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
    private func writeShieldSession(_ session: ShieldSession, to defaults: UserDefaults) {
        defaults.set(session.reason.rawValue, forKey: ShieldSession.reasonKey)
        defaults.set(session.durationSeconds, forKey: ShieldSession.durationKey)
        defaults.set(session.triggeredAt.timeIntervalSince1970, forKey: ShieldSession.triggeredAtKey)
    }

    /// Simulates what `DeviceActivityMonitorService.endShield()` must do to prevent
    /// the extension from re-reading a stale session on the next `intervalDidStart`.
    private func clearShieldSession(from defaults: UserDefaults) {
        defaults.removeObject(forKey: ShieldSession.reasonKey)
        defaults.removeObject(forKey: ShieldSession.durationKey)
        defaults.removeObject(forKey: ShieldSession.triggeredAtKey)
    }
}
