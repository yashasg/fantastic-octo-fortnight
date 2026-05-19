import XCTest

@testable import ScreenTimeExtensionShared

/// Direct unit coverage for `ShieldIntervalEndCleanupPolicy` (#928).
///
/// The policy decides whether a `DeviceActivityMonitorExtension` interval-end
/// callback should clear shield restrictions, and reports whether the snapshot
/// that drove the decision was structurally valid or missing/corrupt. A
/// regression here surfaces as a user-visible "stuck shield" (the device
/// stays restricted after the break interval ends), which is hard to spot in
/// the higher-level `DeviceActivityMonitoringValidationTests` integration
/// scenarios. These tests pin the contract on the pure-Swift snapshot type
/// — no FamilyControls / DeviceActivity entitlements are required.
///
/// Coverage matrix (see #928 acceptance criteria):
/// 1. Empty snapshot (`.empty`) → cleanup with `.missingOrCorrupt`.
/// 2. `read(from:)` on empty defaults → cleanup with `.missingOrCorrupt`.
/// 3. `read(from:)` on a defaults blob with garbage at `sessionData` →
///    cleanup with `.missingOrCorrupt`.
/// 4. Valid snapshot via `read(from:)` after `encodedData(...)` round-trip →
///    cleanup with `.valid`.
/// 5. Hand-constructed snapshot with `triggeredAt == nil` but a reason and
///    duration → cleanup with `.missingOrCorrupt` (timestamp is the
///    discriminator).
/// 6. Hand-constructed snapshot with `triggeredAt == nil` and *no* reason
///    (the legacy "blank" payload) → cleanup with `.missingOrCorrupt`.
/// 7. Snapshot whose `triggeredAt` is decades in the past (shield long
///    expired) → cleanup with `.valid` (policy is identity-only, does not
///    look at elapsed time).
/// 8. Snapshot whose `triggeredAt` is in the future (clock-skew / mismatched
///    session id) → cleanup with `.valid` (same: identity-only).
/// 9. `ShieldIntervalEndCleanupDecision` value semantics: `Equatable` and
///    initialiser preserve both fields exactly.
///
/// Out of scope (covered elsewhere or blocked by #201):
/// - End-to-end `DeviceActivityMonitorExtension.intervalDidEnd(for:)` flow —
///   covered by `DeviceActivityMonitoringValidationTests`.
/// - Real `ManagedSettingsStore.clearAllSettings()` invocation — requires
///   FamilyControls entitlement (#201).
final class ShieldIntervalEndCleanupPolicyTests: XCTestCase {

    // MARK: - Infrastructure

    private let suiteName = "com.yashasg.kshana.test.shieldIntervalEndCleanupPolicy"
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Decision (snapshot inputs)

    /// `ShieldSessionSnapshot.empty` is the canonical "no session" sentinel.
    /// The policy must still authorise cleanup (safer to clear than to leave a
    /// stale shield) and tag the state as `.missingOrCorrupt` so the extension
    /// can log diagnostically.
    func test_decision_emptySnapshot_authorisesCleanupAndReportsMissingOrCorrupt() {
        let decision = ShieldIntervalEndCleanupPolicy.decision(for: .empty)

        XCTAssertTrue(decision.shouldClearRestrictions)
        XCTAssertEqual(decision.sessionState, .missingOrCorrupt)
    }

    /// Reading from empty `UserDefaults` returns `.empty`; the policy must
    /// still authorise cleanup with `.missingOrCorrupt`.
    func test_decision_readFromEmptyDefaults_authorisesCleanupAndReportsMissingOrCorrupt() {
        let snapshot = ShieldSessionSnapshot.read(from: defaults)

        let decision = ShieldIntervalEndCleanupPolicy.decision(for: snapshot)

        XCTAssertEqual(snapshot, .empty)
        XCTAssertTrue(decision.shouldClearRestrictions)
        XCTAssertEqual(decision.sessionState, .missingOrCorrupt)
    }

    /// A garbage payload at the canonical `sessionData` key must decode to
    /// `.empty` and therefore drive a `.missingOrCorrupt` cleanup decision.
    func test_decision_corruptSessionDataPayload_authorisesCleanupAndReportsMissingOrCorrupt() {
        defaults.set(Data("not-json".utf8), forKey: ShieldSessionKeys.sessionData)

        let snapshot = ShieldSessionSnapshot.read(from: defaults)
        let decision = ShieldIntervalEndCleanupPolicy.decision(for: snapshot)

        XCTAssertEqual(snapshot, .empty)
        XCTAssertTrue(decision.shouldClearRestrictions)
        XCTAssertEqual(decision.sessionState, .missingOrCorrupt)
    }

    /// A round-tripped valid payload must drive a `.valid` cleanup decision.
    /// This is the canonical "happy path" interval-end callback.
    func test_decision_validRoundTrippedPayload_authorisesCleanupAndReportsValid() throws {
        let triggeredAt = Date(timeIntervalSince1970: 1_700_000_000)
        let data = try ShieldSessionSnapshot.encodedData(
            reasonRaw: ShieldTriggerReason.scheduledEyesBreak.rawValue,
            durationSeconds: 20,
            triggeredAt: triggeredAt
        )
        defaults.set(data, forKey: ShieldSessionKeys.sessionData)

        let snapshot = ShieldSessionSnapshot.read(from: defaults)
        let decision = ShieldIntervalEndCleanupPolicy.decision(for: snapshot)

        XCTAssertEqual(snapshot.reasonRaw, ShieldTriggerReason.scheduledEyesBreak.rawValue)
        XCTAssertEqual(snapshot.triggeredAt, triggeredAt)
        XCTAssertTrue(decision.shouldClearRestrictions)
        XCTAssertEqual(decision.sessionState, .valid)
    }

    /// Boundary: snapshot with a reason and duration but `triggeredAt == nil`.
    /// The policy's discriminator is purely the timestamp, so this must be
    /// classified as `.missingOrCorrupt`.
    func test_decision_snapshotWithReasonButNoTimestamp_reportsMissingOrCorrupt() {
        let snapshot = ShieldSessionSnapshot(
            reasonRaw: ShieldTriggerReason.scheduledPostureBreak.rawValue,
            durationSeconds: 30,
            triggeredAt: nil
        )

        let decision = ShieldIntervalEndCleanupPolicy.decision(for: snapshot)

        XCTAssertTrue(decision.shouldClearRestrictions)
        XCTAssertEqual(decision.sessionState, .missingOrCorrupt)
    }

    /// Boundary: snapshot with neither a reason nor a timestamp (the legacy
    /// "idle" payload that pre-#600 code emitted before sessions were
    /// scheduled). Same fall-through: `.missingOrCorrupt`.
    func test_decision_snapshotWithNoReasonAndNoTimestamp_reportsMissingOrCorrupt() {
        let snapshot = ShieldSessionSnapshot(
            reasonRaw: nil,
            durationSeconds: 0,
            triggeredAt: nil
        )

        let decision = ShieldIntervalEndCleanupPolicy.decision(for: snapshot)

        XCTAssertTrue(decision.shouldClearRestrictions)
        XCTAssertEqual(decision.sessionState, .missingOrCorrupt)
    }

    /// Boundary: snapshot whose `triggeredAt` is decades in the past — the
    /// shield should have expired naturally. The policy is identity-only and
    /// must still report `.valid` (the timestamp is non-nil); decisions about
    /// "expired" sessions are owned by other layers.
    func test_decision_snapshotWithFarPastTimestamp_reportsValid() {
        let snapshot = ShieldSessionSnapshot(
            reasonRaw: ShieldTriggerReason.scheduledEyesBreak.rawValue,
            durationSeconds: 20,
            triggeredAt: Date(timeIntervalSince1970: 0)  // 1970-01-01
        )

        let decision = ShieldIntervalEndCleanupPolicy.decision(for: snapshot)

        XCTAssertTrue(decision.shouldClearRestrictions)
        XCTAssertEqual(decision.sessionState, .valid)
    }

    /// Boundary: snapshot whose `triggeredAt` is in the future (e.g. wall-
    /// clock skew between the main app and the extension). Same as above —
    /// the policy is identity-only.
    func test_decision_snapshotWithFutureTimestamp_reportsValid() {
        let snapshot = ShieldSessionSnapshot(
            reasonRaw: ShieldTriggerReason.scheduledPostureBreak.rawValue,
            durationSeconds: 30,
            triggeredAt: Date(timeIntervalSinceNow: 60 * 60 * 24 * 365)  // +1 year
        )

        let decision = ShieldIntervalEndCleanupPolicy.decision(for: snapshot)

        XCTAssertTrue(decision.shouldClearRestrictions)
        XCTAssertEqual(decision.sessionState, .valid)
    }

    // MARK: - Decision value semantics

    /// The policy result is a small value type used as a diagnostic carrier
    /// across the extension/main-app seam. Lock down `Equatable` and the
    /// memberwise initialiser so a refactor that drops `Equatable` or
    /// reorders fields fails loudly.
    func test_decisionValueSemantics_equalityAndInitialiserPreserveBothFields() {
        let valid = ShieldIntervalEndCleanupDecision(
            shouldClearRestrictions: true,
            sessionState: .valid
        )
        let validCopy = ShieldIntervalEndCleanupDecision(
            shouldClearRestrictions: true,
            sessionState: .valid
        )
        let missing = ShieldIntervalEndCleanupDecision(
            shouldClearRestrictions: true,
            sessionState: .missingOrCorrupt
        )
        let suppressed = ShieldIntervalEndCleanupDecision(
            shouldClearRestrictions: false,
            sessionState: .valid
        )

        XCTAssertEqual(valid, validCopy)
        XCTAssertNotEqual(valid, missing)
        XCTAssertNotEqual(valid, suppressed)
        XCTAssertTrue(valid.shouldClearRestrictions)
        XCTAssertEqual(valid.sessionState, .valid)
        XCTAssertFalse(suppressed.shouldClearRestrictions)
        XCTAssertEqual(missing.sessionState, .missingOrCorrupt)
    }
}
