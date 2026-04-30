@testable import EyePostureReminder
import XCTest

/// Tests for the `hasSeenOnboarding` UserDefaults flag that gates
/// the first-launch vs. returning-user flow in `ContentView`.
///
/// `ContentView` reads the flag via `@AppStorage(AppStorageKey.hasSeenOnboarding)`
/// which defaults to `false`. `OnboardingView.finishOnboarding()` writes `true` to
/// `UserDefaults.standard` when the user completes onboarding.
///
/// Tests use an isolated `UserDefaults` suite to avoid polluting the real
/// user defaults during testing.
final class OnboardingTests: XCTestCase {

    // MARK: - Constants

    /// Key used by `ContentView`'s `@AppStorage` binding and by
    /// `OnboardingView.finishOnboarding()`. Sourced from `AppStorageKey` to
    /// guarantee tests exercise the same key as production code.
    static let hasSeenOnboardingKey = AppStorageKey.hasSeenOnboarding

    // MARK: - Isolated UserDefaults

    let testSuiteName = "com.yashasg.kshana.test.onboarding"
    var testDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDefaults = try XCTUnwrap(UserDefaults(suiteName: testSuiteName))
        testDefaults.removePersistentDomain(forName: testSuiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Key Correctness (contract with ContentView)

    func test_hasSeenOnboardingKey_exactString() {
        XCTAssertEqual(
            Self.hasSeenOnboardingKey,
            "kshana.hasSeenOnboarding",
            "Key must match the @AppStorage key used in ContentView and OnboardingView")
    }

    // MARK: - First Launch (no key set)

    func test_firstLaunch_hasSeenOnboarding_isAbsentInFreshDefaults() {
        let value = testDefaults.object(forKey: Self.hasSeenOnboardingKey)
        XCTAssertNil(
            value,
            "hasSeenOnboarding key must not be pre-set on a fresh install (first launch)")
    }

    func test_firstLaunch_boolQuery_returnsFalse() {
        XCTAssertFalse(
            testDefaults.bool(forKey: Self.hasSeenOnboardingKey),
            "UserDefaults.bool(forKey:) must return false when key is absent (first launch)"
        )
    }

    // MARK: - After Onboarding Completion (returning user)

    func test_finishOnboarding_setsKeyToTrue() {
        // Simulates OnboardingView.finishOnboarding():
        // UserDefaults.standard.set(true, forKey: AppStorageKey.hasSeenOnboarding)
        testDefaults.set(true, forKey: Self.hasSeenOnboardingKey)
        XCTAssertTrue(
            testDefaults.bool(forKey: Self.hasSeenOnboardingKey),
            "After onboarding completes, hasSeenOnboarding must be true (returning user)")
    }

    func test_finishOnboarding_keyBecomesPresent() {
        testDefaults.set(true, forKey: Self.hasSeenOnboardingKey)
        XCTAssertNotNil(
            testDefaults.object(forKey: Self.hasSeenOnboardingKey),
            "Key must be present after onboarding is finished"
        )
    }

    func test_hasSeenOnboarding_persistsAfterSynchronize() throws {
        testDefaults.set(true, forKey: Self.hasSeenOnboardingKey)
        testDefaults.synchronize()

        let freshQuery = try XCTUnwrap(UserDefaults(suiteName: testSuiteName))
        XCTAssertTrue(
            freshQuery.bool(forKey: Self.hasSeenOnboardingKey),
            "hasSeenOnboarding must persist (returning user across launches)")
    }

    // MARK: - Reset Behavior

    func test_hasSeenOnboarding_canBeResetToFalse() {
        testDefaults.set(true, forKey: Self.hasSeenOnboardingKey)
        testDefaults.set(false, forKey: Self.hasSeenOnboardingKey)
        XCTAssertFalse(
            testDefaults.bool(forKey: Self.hasSeenOnboardingKey),
            "hasSeenOnboarding must be resettable to false (e.g. for testing or reset flow)")
    }

    func test_removePersistentDomain_clearsOnboardingFlag() {
        testDefaults.set(true, forKey: Self.hasSeenOnboardingKey)
        testDefaults.removePersistentDomain(forName: testSuiteName)
        XCTAssertFalse(
            testDefaults.bool(forKey: Self.hasSeenOnboardingKey),
            "Removing persistent domain must clear the onboarding flag")
    }

    // MARK: - Analytics: single-event regression tests (#324)
    //
    // `finishOnboarding()` and `finishOnboardingAndCustomize()` are internal
    // (not private) so @testable import can reach them.  Neither method accesses
    // @EnvironmentObject properties, so OnboardingView() is safely instantiable
    // in a plain unit-test process.

    func test_finishOnboarding_emitsExactlyOneOnboardingCompletedEvent_withGetStartedCTA() {
        var logged: [AnalyticsEvent] = []
        AnalyticsLogger.testEventHandler = { logged.append($0) }
        defer {
            AnalyticsLogger.testEventHandler = nil
            UserDefaults.standard.removeObject(forKey: AppStorageKey.hasSeenOnboarding)
        }

        OnboardingView().finishOnboarding()

        let completed = logged.filter { if case .onboardingCompleted = $0 { return true }; return false }
        XCTAssertEqual(completed.count, 1, "finishOnboarding must emit exactly one onboardingCompleted event")
        guard case .onboardingCompleted(let cta) = completed.first else { return XCTFail("No event") }
        XCTAssertEqual(cta, .getStarted, "finishOnboarding must use the .getStarted CTA")
    }

    /// Regression test for #324: pre-fix code called finishOnboarding() from
    /// finishOnboardingAndCustomize(), emitting both .customize and .getStarted.
    /// This test fails against the pre-fix code (count == 2) and passes after the fix.
    func test_finishOnboardingAndCustomize_emitsExactlyOneOnboardingCompletedEvent_withCustomizeCTA() {
        var logged: [AnalyticsEvent] = []
        AnalyticsLogger.testEventHandler = { logged.append($0) }
        defer {
            AnalyticsLogger.testEventHandler = nil
            UserDefaults.standard.removeObject(forKey: AppStorageKey.hasSeenOnboarding)
            UserDefaults.standard.removeObject(forKey: AppStorageKey.openSettingsOnLaunch)
        }

        OnboardingView().finishOnboardingAndCustomize()

        let completed = logged.filter { if case .onboardingCompleted = $0 { return true }; return false }
        XCTAssertEqual(
            completed.count, 1,
            "Customize path must emit exactly one onboardingCompleted event (pre-fix emitted two)")
        guard case .onboardingCompleted(let cta) = completed.first else { return XCTFail("No event") }
        XCTAssertEqual(cta, .customize, "Customize path must use the .customize CTA, not .getStarted")
    }

    func test_finishOnboardingAndCustomize_setsOpenSettingsOnLaunch() {
        defer { UserDefaults.standard.removeObject(forKey: AppStorageKey.openSettingsOnLaunch)
                UserDefaults.standard.removeObject(forKey: AppStorageKey.hasSeenOnboarding) }
        OnboardingView().finishOnboardingAndCustomize()
        XCTAssertTrue(
            UserDefaults.standard.bool(forKey: AppStorageKey.openSettingsOnLaunch),
            "finishOnboardingAndCustomize must set openSettingsOnLaunch")
    }

    func test_finishOnboarding_setsHasSeenOnboarding() {
        defer { UserDefaults.standard.removeObject(forKey: AppStorageKey.hasSeenOnboarding) }
        OnboardingView().finishOnboarding()
        XCTAssertTrue(
            UserDefaults.standard.bool(forKey: AppStorageKey.hasSeenOnboarding),
            "finishOnboarding must set hasSeenOnboarding")
    }
}
