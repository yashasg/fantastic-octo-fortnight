@testable import EyePostureReminder
import XCTest

/// Unit tests for the Screen Time shield abstraction layer.
///
/// These tests validate the compile-safe scaffolding added in #202.
/// They do NOT touch `FamilyControls`, `ManagedSettings`, or `DeviceActivity` —
/// those frameworks require the entitlement from #201 and a real device.
///
/// All tests use `ScreenTimeShieldNoop` (the pre-entitlement stub) and
/// verify the domain types and protocol contract. When the real
/// `ScreenTimeShieldManager` is added in M3.3, a parallel test file with
/// a `MockScreenTimeShieldProviding` will test `AppCoordinator` integration.
@MainActor
final class ScreenTimeShieldTests: XCTestCase {

    // MARK: - ScreenTimeShieldNoop

    func test_noop_isAvailable_returnsFalse() {
        let sut = ScreenTimeShieldNoop()
        XCTAssertFalse(sut.isAvailable, "isAvailable must be false pre-entitlement")
    }

    func test_noop_beginShield_doesNotThrow() async throws {
        let sut = ScreenTimeShieldNoop()
        let session = makeSession()
        // Must not throw — AppCoordinator calls this regardless of availability guard
        // in test builds; the real guard lives in the caller.
        try await sut.beginShield(for: session)
    }

    func test_noop_endShield_doesNotThrow() async throws {
        let sut = ScreenTimeShieldNoop()
        try await sut.endShield()
    }

    func test_noop_startAndStopMonitoring_doNotCrash() {
        let sut = ScreenTimeShieldNoop()
        sut.startMonitoring()
        sut.stopMonitoring()
    }

    // MARK: - ShieldTriggerReason

    func test_shieldTriggerReason_rawValues_areStable() {
        // Raw values are written to shared App Group UserDefaults and read by
        // extension processes — they must never change without a migration.
        XCTAssertEqual(ShieldTriggerReason.scheduledEyesBreak.rawValue, "eyes")
        XCTAssertEqual(ShieldTriggerReason.scheduledPostureBreak.rawValue, "posture")
    }

    func test_shieldTriggerReason_equality() {
        XCTAssertEqual(ShieldTriggerReason.scheduledEyesBreak, ShieldTriggerReason.scheduledEyesBreak)
        XCTAssertNotEqual(ShieldTriggerReason.scheduledEyesBreak, ShieldTriggerReason.scheduledPostureBreak)
    }

    // MARK: - ShieldSession

    func test_shieldSession_storesAllProperties() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let session = ShieldSession(reason: .scheduledEyesBreak, durationSeconds: 20, triggeredAt: now)
        XCTAssertEqual(session.reason, .scheduledEyesBreak)
        XCTAssertEqual(session.durationSeconds, 20)
        XCTAssertEqual(session.triggeredAt, now)
    }

    func test_shieldSession_equality_sameValues() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let a = ShieldSession(reason: .scheduledPostureBreak, durationSeconds: 30, triggeredAt: now)
        let b = ShieldSession(reason: .scheduledPostureBreak, durationSeconds: 30, triggeredAt: now)
        XCTAssertEqual(a, b)
    }

    func test_shieldSession_equality_differentReason() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let eyes = ShieldSession(reason: .scheduledEyesBreak, durationSeconds: 20, triggeredAt: now)
        let posture = ShieldSession(reason: .scheduledPostureBreak, durationSeconds: 20, triggeredAt: now)
        XCTAssertNotEqual(eyes, posture)
    }

    func test_shieldSession_sharedDefaultsKeys_areStable() {
        // Keys are written by main app, read by extension — must not change
        // without a coordinated migration of both targets.
        XCTAssertEqual(ShieldSession.reasonKey, "shield.breakReason")
        XCTAssertEqual(ShieldSession.durationKey, "shield.durationSeconds")
        XCTAssertEqual(ShieldSession.triggeredAtKey, "shield.triggeredAt")
    }

    // MARK: - Helpers

    private func makeSession(
        reason: ShieldTriggerReason = .scheduledEyesBreak,
        duration: TimeInterval = 20
    ) -> ShieldSession {
        ShieldSession(reason: reason, durationSeconds: duration, triggeredAt: Date())
    }
}
