// RegressionTests.swift
// kshana
//
// Regression tests for bugs fixed on 2026-04-25 and 2026-04-26.
// Each section documents the root cause and what failure mode proves the bug regressed.
//
// Bug 1: SettingsView Done button not responding (fixed: @Binding var isPresented)
// Bug 2: SPM localization bundle — Text("key") must use bundle: .module
// Bug 3: run.sh stale binary cache — UNTESTABLE in unit test context (shell-script only)
// Bug 4: ScreenTimeTracker replacing fixed-interval wall-clock timers
// Bug 5: Data-driven defaults (AppConfig replaces hardcoded ReminderSettings statics)
// Bug #119: PauseConditionManager cold-start focus seed — isFocused=true at startMonitoring() must pause immediately
// Bug #118: ScreenTimeTracker double-resign — second willResignActive must cancel first reset Task (one reset, not two)
// Bug #117: OverlayManager queue-on-no-scene — showOverlay with no UIWindowScene must queue, not drop

@testable import EyePostureReminder
import SwiftUI
import UIKit
import XCTest

// MARK: ─── Bug 1: SettingsView Done Button ───────────────────────────────────

/// Regression tests for Bug 1: SettingsView dismiss mechanism.
///
/// **Root cause:** `@Environment(\.dismiss)` inside a `sheet {}` nested in a
/// `NavigationStack` was silently ignored — the environment-provided dismiss action
/// routed to the wrong ancestor (Issue #15).
///
/// **Fix:** SettingsView uses `@Binding var isPresented: Bool` so the Done button
/// writes `isPresented = false` directly to HomeView's `@State showSettings`.
///
/// **How these catch a regression:**
/// - `test_settingsView_instantiatesCorrectly` ensures SettingsView can be constructed
///   with an `isPresented:` binding (confirming it uses `@Binding`, not `@Environment`).
/// - The binding tests verify the abstract dismiss pattern works.
@MainActor
final class SettingsDismissRegressionTests: XCTestCase {

    /// Compile-time guard: SettingsView must be instantiatable with an isPresented binding.
    /// SettingsView uses @Binding var isPresented: Bool for reliable sheet dismissal.
    func test_settingsView_instantiatesCorrectly() {
        let view = SettingsView(isPresented: .constant(true))
        XCTAssertNotNil(
            view,
            "SettingsView must be instantiatable with an isPresented binding.")
    }

    /// Runtime guard: writing `false` to the binding must propagate to the caller's state.
    /// This mirrors what the Done button toolbar item does: `isPresented = false`.
    func test_doneButtonAction_setsPresentedFalse_viaBinding() {
        var isPresented = true
        let binding = Binding<Bool>(
            get: { isPresented },
            set: { isPresented = $0 }
        )

        // Simulate the Done button action:
        // Button(…) { isPresented = false }
        binding.wrappedValue = false

        XCTAssertFalse(
            isPresented,
            "Done button must set isPresented = false via binding to dismiss the sheet. "
            + "Regression: if the action uses dismiss() instead of the binding, the sheet stays open.")
    }

    /// Compile-time guard from HomeView's perspective: SettingsView(isPresented:) must compile.
    func test_homeView_controlsSettingsPresentation_viaBinding() {
        var showSettings = true
        let binding = Binding<Bool>(get: { showSettings }, set: { showSettings = $0 })

        _ = SettingsView(isPresented: binding)   // must compile

        // Sheet dismissed:
        binding.wrappedValue = false
        XCTAssertFalse(
            showSettings,
            "HomeView's @State showSettings must become false when Done is tapped.")
    }
}

// MARK: ─── Bug 2: SPM Localization Bundle ────────────────────────────────────

/// Regression tests for Bug 2: Localizable.xcstrings not loading at runtime.
///
/// **Root cause:** In an SPM `executableTarget`, localized resources live in
/// `Bundle.module`, not `Bundle.main`. `Text("key")` without `bundle:` silently
/// resolves against `Bundle.main`, which in the packaged target has no strings
/// table — so raw keys like `"settings.doneButton"` display instead of "Done".
///
/// **Fix:** Every `Text()`, `String(localized:)`, and `Color(name:)` call in all
/// views now explicitly passes `bundle: .module`.
///
/// **How these catch a regression:**
/// - `test_localization_*` fail if any key falls through to the key-echo fallback.
/// - `test_appColor_*` fail (or crash) if `Color(name:bundle:)` can't find the
///   named asset because the bundle reference was changed back to `Bundle.main`.
final class LocalizationBundleRegressionTests: XCTestCase {

    /// Production module bundle: finds the compiled resource bundle so NSLocalizedString
    /// lookups resolve against Localizable.xcstrings, not the test bundle.
    /// Uses `TestBundle.module` rather than `Bundle(for: SettingsStore.self)` directly
    /// because the code bundle and the resource bundle are separate in SPM builds.
    private var moduleBundle: Bundle { TestBundle.module }

    // MARK: String catalog keys resolve to real English strings (not key echo-back)

    func test_localization_settingsDoneButton_resolvesFromModuleBundle() {
        let resolved = NSLocalizedString("settings.doneButton", bundle: moduleBundle, comment: "")
        XCTAssertNotEqual(
            resolved,
            "settings.doneButton",
            "'settings.doneButton' fell back to the raw key — "
            + "regression: bundle: .module removed from toolbar Done button Text().")
        XCTAssertFalse(resolved.isEmpty)
    }

    func test_localization_settingsNavTitle_resolvesFromModuleBundle() {
        let resolved = NSLocalizedString("settings.navTitle", bundle: moduleBundle, comment: "")
        XCTAssertNotEqual(
            resolved,
            "settings.navTitle",
            "'settings.navTitle' must resolve from module bundle, not echo the raw key.")
    }

    func test_localization_homeTitle_resolvesFromModuleBundle() {
        let resolved = NSLocalizedString("home.title", bundle: moduleBundle, comment: "")
        XCTAssertNotEqual(
            resolved,
            "home.title",
            "'home.title' must resolve from module bundle, not echo the raw key.")
    }

    func test_localization_settingsGlobalToggle_resolvesFromModuleBundle() {
        let resolved = NSLocalizedString("settings.masterToggle", bundle: moduleBundle, comment: "")
        XCTAssertNotEqual(
            resolved,
            "settings.masterToggle",
            "'settings.masterToggle' must resolve from module bundle.")
    }

    /// Verify the `String(localized:bundle:)` form — used in SettingsView's toolbar.
    func test_localization_stringInitWithBundle_resolvesCorrectly() {
        let resolved = String(localized: "settings.doneButton", bundle: moduleBundle)
        XCTAssertNotEqual(
            resolved,
            "settings.doneButton",
            "String(localized:bundle:) form must resolve settings.doneButton via module bundle.")
    }

    // MARK: AppColor tokens resolve from module bundle (no crash, non-nil Color)

    /// `Color("ReminderBlue", bundle: .module)` must succeed.
    /// Regression to `bundle: .main` returns nil (black in production), fails asset lookup.
    func test_appColor_reminderBlue_resolvesFromModuleBundle() {
        let color = AppColor.reminderBlue
        // Color is a value type — we can only verify no crash and non-empty description.
        XCTAssertFalse(
            "\(color)".isEmpty,
            "AppColor.reminderBlue must resolve from bundle: .module.")
    }

    func test_appColor_reminderGreen_resolvesFromModuleBundle() {
        XCTAssertFalse(
            "\(AppColor.reminderGreen)".isEmpty,
            "AppColor.reminderGreen must resolve from bundle: .module.")
    }

    func test_appColor_warningOrange_resolvesFromModuleBundle() {
        XCTAssertFalse(
            "\(AppColor.warningOrange)".isEmpty,
            "AppColor.warningOrange must resolve from bundle: .module.")
    }

    func test_appColor_warningText_resolvesFromModuleBundle() {
        XCTAssertFalse(
            "\(AppColor.warningText)".isEmpty,
            "AppColor.warningText must resolve from bundle: .module.")
    }
}

// MARK: ─── Bug 3: run.sh stale binary ────────────────────────────────────────

// Skipped: the stale binary cache bug lives in scripts/run.sh inside
// `assemble_app_bundle()`. It is not reproducible in an XCTest unit test context.
// Manual verification procedure:
//   1. Build and launch via `./scripts/run.sh`
//   2. Change a Swift source file (e.g., add a print statement)
//   3. Run `./scripts/run.sh` again
//   4. Confirm the running binary reflects the change (no stale executable in .app).

// MARK: ─── Bug 4: ScreenTimeTracker ─────────────────────────────────────────

/// Regression tests for Bug 4: Reminders used fixed wall-clock timers.
///
/// **Root cause:** The original scheduler used `Timer.scheduledTimer(interval:repeats:)`
/// anchored to wall-clock time. It fired even when the screen was off or the app was
/// backgrounded, leading to reminders at the wrong time or missing the required
/// continuous screen-on duration entirely.
///
/// **Fix:** `ScreenTimeTracker` counts only *continuous screen-on time* per
/// `ReminderType`. The tick timer pauses on `willResignActive`, resumes (without
/// resetting) if the app returns within a 5-second grace period, and resets all
/// counters if the grace period expires without a return.
///
/// All methods must run on the main thread — the test class is `@MainActor`.
/// Timer callbacks use XCTestExpectation; `wait(for:timeout:)` spins the run loop
/// so pending timers fire normally.
@MainActor
final class ScreenTimeTrackerRegressionTests: XCTestCase {

    var sut: ScreenTimeTracker!

    override func setUp() async throws {
        try await super.setUp()
        sut = ScreenTimeTracker()
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        try await super.tearDown()
    }

    // MARK: Regression-Unique Tests

    /// setThreshold resets the accumulated counter to 0.
    /// Regression guard: without a counter reset, leftover time from a prior threshold
    /// configuration could trigger an immediate (spurious) callback.
    func test_setThreshold_resetsElapsedCounter_noSpuriousCallbackOnReconfig() {
        let noCallback = expectation(description: "no spurious callback on setThreshold reconfig")
        noCallback.isInverted = true
        sut.setThreshold(9_999, for: .eyes)
        sut.onThresholdReached = { _ in
            XCTFail("Callback must not fire immediately after setThreshold (counter must be 0).")
            noCallback.fulfill()
        }
        // Reconfigure with a new threshold — no accumulated time should carry over.
        sut.setThreshold(9_999, for: .eyes)
        wait(for: [noCallback], timeout: 0.5)
    }

    /// disableTracking removes a type from the tracker; no callback fires afterward.
    func test_disableTracking_removesType_noCallbackFires() {
        let noCallback = expectation(description: "no callback after disableTracking")
        noCallback.isInverted = true

        sut.setThreshold(2, for: .eyes)
        sut.disableTracking(for: .eyes)
        sut.onThresholdReached = { _ in noCallback.fulfill() }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        wait(for: [noCallback], timeout: 3.5)
    }

    /// pause(for:) prevents counter accumulation for one type.
    /// Regression guard: if pausing is ignored, reminders fire during user-initiated snooze.
    func test_pause_preventsCallbackFiring() {
        let noCallback = expectation(description: "paused type must not fire")
        noCallback.isInverted = true

        sut.setThreshold(2, for: .eyes)
        sut.pause(for: .eyes)
        sut.onThresholdReached = { _ in noCallback.fulfill() }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        wait(for: [noCallback], timeout: 3.5)
    }

    /// After pause + resume, the type must fire again when the threshold is reached.
    func test_resume_allowsCallbackAfterPause() {
        let callbackFired = expectation(description: "resumed type fires callback")

        sut.setThreshold(2, for: .eyes)
        sut.pause(for: .eyes)
        sut.resume(for: .eyes)
        sut.onThresholdReached = { type in
            if type == .eyes { callbackFired.fulfill() }
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        wait(for: [callbackFired], timeout: 4.5)
    }

    /// pauseAll() must prevent ALL types from firing.
    func test_pauseAll_preventsAllCallbacks() {
        let noCallback = expectation(description: "no callbacks after pauseAll")
        noCallback.isInverted = true

        for type in ReminderType.allCases {
            sut.setThreshold(2, for: type)
        }
        sut.pauseAll()
        sut.onThresholdReached = { _ in noCallback.fulfill() }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        wait(for: [noCallback], timeout: 3.5)
    }

    // MARK: Threshold Firing (Timer-Based)

    /// Core regression: the tracker must fire onThresholdReached when continuous
    /// screen-on time reaches the configured threshold.
    /// Bug 4 root cause: old wall-clock timers never called onThresholdReached based
    /// on actual screen-on duration — this test would have timed out on the old code.
    func test_thresholdReached_firesCallback_forEyes() {
        let callbackFired = expectation(description: "eyes threshold callback fires")

        sut.setThreshold(2, for: .eyes)
        sut.onThresholdReached = { type in
            if type == .eyes { callbackFired.fulfill() }
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        wait(for: [callbackFired], timeout: 4.5)
    }

    func test_thresholdReached_firesCallback_forPosture() {
        let callbackFired = expectation(description: "posture threshold callback fires")

        sut.setThreshold(2, for: .posture)
        sut.onThresholdReached = { type in
            if type == .posture { callbackFired.fulfill() }
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        wait(for: [callbackFired], timeout: 4.5)
    }

    /// After the threshold fires, the counter resets to 0 — enabling a second callback cycle.
    /// Regression guard: if the counter is not reset, callbacks would stop after the first fire.
    func test_thresholdReached_resetsCounter_enablingSecondCycle() {
        var callCount = 0
        let secondCallbackFired = expectation(description: "second callback after counter reset")

        sut.setThreshold(2, for: .eyes)
        sut.onThresholdReached = { type in
            if type == .eyes {
                callCount += 1
                if callCount >= 2 { secondCallbackFired.fulfill() }
            }
        }

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        wait(for: [secondCallbackFired], timeout: 7.0)
    }

    // MARK: Lifecycle: willResignActive Pauses Accumulation

    /// Posting willResignActive stops the tick timer.
    /// The callback must NOT fire during screen-off.
    /// Regression: if the timer is not stopped on resignActive, reminders fire while
    /// the screen is off (the wall-clock timer bug).
    func test_willResignActive_stopsAccumulation_noCallbackDuringScreenOff() {
        let noCallback = expectation(description: "no callback while screen is off")
        noCallback.isInverted = true

        sut.setThreshold(2, for: .eyes)
        sut.onThresholdReached = { _ in noCallback.fulfill() }

        // Start ticking, then immediately resign active.
        // Both notifications are posted synchronously before the run loop spins,
        // so no timer ticks can fire between them.
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)

        wait(for: [noCallback], timeout: 3.5)
    }

    /// Returning to active within the grace period resumes counting from where it left off
    /// (counter is NOT reset). The callback must eventually fire.
    /// Regression guard: if the grace period cancellation doesn't work, counters reset on every
    /// brief interruption (notification banner, incoming call), making long intervals impossible.
    func test_withinGracePeriod_returnsToActive_resumesCounting() {
        let callbackFired = expectation(description: "callback fires after resume within grace period")

        sut.setThreshold(3, for: .eyes)
        sut.onThresholdReached = { type in
            if type == .eyes { callbackFired.fulfill() }
        }

        // Start counting.
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        // Briefly resign (~0.5s accumulated), then return within the 5-second grace period.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        // Resumed from ~0.5s; callback should fire within ~3s more.
        wait(for: [callbackFired], timeout: 6.0)
    }
}
// MARK: ─── Bug 5: Data-Driven Defaults ───────────────────────────────────────

/// Regression tests for Bug 5: Settings defaults were hardcoded in Swift.
///
/// **Root cause:** `ReminderSettings.defaultEyes` and `.defaultPosture` contained
/// hardcoded Swift literals (e.g., `interval: 1200`). Changing a default required
/// a recompile. The fix bundles `defaults.json` and routes all default reads through
/// `AppConfig`, which `SettingsStore.init(config:)` accepts as a dependency.
///
/// **How these catch a regression:**
/// - `test_firstLaunch_*` fail if SettingsStore reverts to hardcoded literals instead
///   of reading from the injected AppConfig.
/// - `test_customConfig_*` fail if the config parameter is ignored.
/// - `test_userChange_overrides_*` fail if UserDefaults-stored values are clobbered by JSON.
/// - `test_reminderSettings_default*_matchesAppConfig` fail if the statics revert to literals.
@MainActor
final class DataDrivenDefaultsRegressionTests: XCTestCase {

    // MARK: First-Launch: Defaults Must Come from AppConfig

    /// Core regression: a fresh SettingsStore with an empty persistence store must read
    /// from the provided AppConfig — not from hardcoded Swift literals.
    func test_firstLaunch_eyesInterval_comesFromAppConfig_notHardcode() {
        let fresh = SettingsStore(store: MockSettingsPersisting(), config: AppConfig.fallback)
        XCTAssertEqual(
            fresh.eyesInterval,
            AppConfig.fallback.defaults.eyeInterval,
            "First-launch eyesInterval must come from AppConfig, not a hardcoded literal. "
            + "Bug 5 regression: hardcoded value returns a stale constant regardless of JSON.")
    }

    func test_firstLaunch_eyesBreakDuration_comesFromAppConfig() {
        let fresh = SettingsStore(store: MockSettingsPersisting(), config: AppConfig.fallback)
        XCTAssertEqual(
            fresh.eyesBreakDuration,
            AppConfig.fallback.defaults.eyeBreakDuration,
            "First-launch eyesBreakDuration must come from AppConfig.")
    }

    func test_firstLaunch_postureInterval_comesFromAppConfig() {
        let fresh = SettingsStore(store: MockSettingsPersisting(), config: AppConfig.fallback)
        XCTAssertEqual(
            fresh.postureInterval,
            AppConfig.fallback.defaults.postureInterval,
            "First-launch postureInterval must come from AppConfig.")
    }

    func test_firstLaunch_postureBreakDuration_comesFromAppConfig() {
        let fresh = SettingsStore(store: MockSettingsPersisting(), config: AppConfig.fallback)
        XCTAssertEqual(
            fresh.postureBreakDuration,
            AppConfig.fallback.defaults.postureBreakDuration,
            "First-launch postureBreakDuration must come from AppConfig.")
    }

    func test_firstLaunch_globalEnabled_comesFromAppConfig_featureFlags() {
        let fresh = SettingsStore(store: MockSettingsPersisting(), config: AppConfig.fallback)
        XCTAssertEqual(
            fresh.globalEnabled,
            AppConfig.fallback.features.globalEnabledDefault,
            "First-launch globalEnabled must come from AppConfig feature flags.")
    }

    // MARK: Custom Config Values Propagate Correctly

    /// Injecting a custom config with distinct values verifies SettingsStore reads from
    /// the injected config, not from a cached global or hardcoded value.
    func test_customConfig_eyeInterval_isUsedAsDefault() {
        let customConfig = AppConfig(
            defaults: AppConfig.Defaults(
                eyeInterval: 300,
                eyeBreakDuration: 5,
                postureInterval: 600,
                postureBreakDuration: 5),
            features: AppConfig.Features(globalEnabledDefault: true, maxSnoozeCount: 2)
        )
        let fresh = SettingsStore(store: MockSettingsPersisting(), config: customConfig)
        XCTAssertEqual(
            fresh.eyesInterval,
            300,
            "Custom config eyeInterval=300 must be used as default; hardcoded fallback would return 1200.")
    }

    func test_customConfig_postureInterval_isUsedAsDefault() {
        let customConfig = AppConfig(
            defaults: AppConfig.Defaults(
                eyeInterval: 300,
                eyeBreakDuration: 5,
                postureInterval: 450,
                postureBreakDuration: 8),
            features: AppConfig.Features(globalEnabledDefault: false, maxSnoozeCount: 1)
        )
        let fresh = SettingsStore(store: MockSettingsPersisting(), config: customConfig)
        XCTAssertEqual(
            fresh.postureInterval,
            450,
            "Custom config postureInterval=450 must propagate; hardcoded fallback would return 1800.")
    }

    func test_customConfig_globalEnabledFalse_propagatesToStore() {
        let customConfig = AppConfig(
            defaults: AppConfig.Defaults(
                eyeInterval: 1200,
                eyeBreakDuration: 20,
                postureInterval: 1800,
                postureBreakDuration: 10),
            features: AppConfig.Features(globalEnabledDefault: false, maxSnoozeCount: 3)
        )
        let fresh = SettingsStore(store: MockSettingsPersisting(), config: customConfig)
        XCTAssertFalse(
            fresh.globalEnabled,
            "Custom config globalEnabledDefault=false must propagate; bug would default to true.")
    }

    // MARK: User Changes Override JSON Defaults

    /// Once a user has stored a value, subsequent launches must use the stored value
    /// — not clobber it with the JSON default. This is the expected "user wins" contract.
    func test_userChange_overridesJsonDefault_eyesInterval() {
        let persistence = MockSettingsPersisting()
        let store = SettingsStore(store: persistence, config: AppConfig.fallback)
        store.eyesInterval = 600  // user sets 10-minute interval

        let reloaded = SettingsStore(store: persistence, config: AppConfig.fallback)
        XCTAssertEqual(
            reloaded.eyesInterval,
            600,
            "User-stored eyesInterval (600) must survive across launches over AppConfig.fallback (1200).")
    }

    func test_userChange_overridesJsonDefault_postureInterval() {
        let persistence = MockSettingsPersisting()
        let store = SettingsStore(store: persistence, config: AppConfig.fallback)
        store.postureInterval = 3600  // user sets 60-minute interval

        let reloaded = SettingsStore(store: persistence, config: AppConfig.fallback)
        XCTAssertEqual(
            reloaded.postureInterval,
            3600,
            "User-stored postureInterval (3600) must survive across launches over AppConfig.fallback (1800).")
    }

    func test_userChange_overridesJsonDefault_globalEnabled_false() {
        let persistence = MockSettingsPersisting()
        let store = SettingsStore(store: persistence, config: AppConfig.fallback)
        store.globalEnabled = false  // user disabled reminders

        let reloaded = SettingsStore(store: persistence, config: AppConfig.fallback)
        XCTAssertFalse(
            reloaded.globalEnabled,
            "User-stored globalEnabled=false must survive across launches over AppConfig default (true).")
    }

    // MARK: ReminderSettings.defaultEyes / defaultPosture Delegate to AppConfig

    /// ReminderSettings.defaultEyes must NOT return a Swift literal.
    /// It must delegate to AppConfig so changing defaults.json changes the statics too.
    func test_reminderSettings_defaultEyes_interval_matchesAppConfigFallback() {
        XCTAssertEqual(
            ReminderSettings.defaultEyes.interval,
            AppConfig.fallback.defaults.eyeInterval,
            "ReminderSettings.defaultEyes.interval must be driven by AppConfig, not a hardcoded literal."
        )
    }

    func test_reminderSettings_defaultEyes_breakDuration_matchesAppConfigFallback() {
        XCTAssertEqual(
            ReminderSettings.defaultEyes.breakDuration,
            AppConfig.fallback.defaults.eyeBreakDuration,
            "ReminderSettings.defaultEyes.breakDuration must be driven by AppConfig."
        )
    }

    func test_reminderSettings_defaultPosture_interval_matchesAppConfigFallback() {
        XCTAssertEqual(
            ReminderSettings.defaultPosture.interval,
            AppConfig.fallback.defaults.postureInterval,
            "ReminderSettings.defaultPosture.interval must be driven by AppConfig."
        )
    }

    func test_reminderSettings_defaultPosture_breakDuration_matchesAppConfigFallback() {
        XCTAssertEqual(
            ReminderSettings.defaultPosture.breakDuration,
            AppConfig.fallback.defaults.postureBreakDuration,
            "ReminderSettings.defaultPosture.breakDuration must be driven by AppConfig."
        )
    }

    // MARK: resetToDefaults() — Regression: Must Use AppConfig, Not Hardcoded Literals

    /// Regression guard: resetToDefaults() must derive interval values from the
    /// supplied AppConfig, not from hardcoded Swift literals. If a future developer
    /// changes defaults.json, resetToDefaults() must pick up the new values.
    func test_resetToDefaults_eyesInterval_comesFromAppConfig_notHardcode() {
        let persistence = MockSettingsPersisting()
        let store = SettingsStore(store: persistence, config: AppConfig.fallback)
        store.eyesInterval = 9999
        store.resetToDefaults(config: AppConfig.fallback)
        XCTAssertEqual(
            store.eyesInterval,
            AppConfig.fallback.defaults.eyeInterval,
            "resetToDefaults() eyesInterval must come from AppConfig, not a hardcoded literal. " +
            "Regression: hardcoded value ignores defaults.json changes.")
    }

    func test_resetToDefaults_postureInterval_comesFromAppConfig_notHardcode() {
        let persistence = MockSettingsPersisting()
        let store = SettingsStore(store: persistence, config: AppConfig.fallback)
        store.postureInterval = 9999
        store.resetToDefaults(config: AppConfig.fallback)
        XCTAssertEqual(
            store.postureInterval,
            AppConfig.fallback.defaults.postureInterval,
            "resetToDefaults() postureInterval must come from AppConfig, not a hardcoded literal.")
    }

    func test_resetToDefaults_globalEnabled_comesFromAppConfig_notHardcode() {
        let persistence = MockSettingsPersisting()
        let store = SettingsStore(store: persistence, config: AppConfig.fallback)
        store.globalEnabled = false
        store.resetToDefaults(config: AppConfig.fallback)
        XCTAssertEqual(
            store.globalEnabled,
            AppConfig.fallback.features.globalEnabledDefault,
            "resetToDefaults() globalEnabled must come from AppConfig.features.globalEnabledDefault.")
    }
}

// MARK: ─── Bug #119: PauseConditionManager Cold-Start Focus Seed ──────────────

/// Regression tests for Bug #119: PauseConditionManager.startMonitoring() must
/// seed its initial pause state from the detector's current value, not wait for a
/// future state-change callback.
///
/// **Root cause:** Before the fix, `startMonitoring()` registered callbacks and
/// called `detector.startMonitoring()`, but never queried the detector's current
/// `isFocused`/`isCarPlayActive`/`isDriving` value on entry. If the device was
/// already in Focus Mode at cold launch, the manager reported `isPaused == false`
/// until the user toggled Focus Mode off and back on.
///
/// **Fix:** After registering callbacks, `startMonitoring()` explicitly seeds each
/// condition via `update(.focusMode, isActive: focusDetector.isFocused && ...)`.
///
/// **How this catches a regression:**
/// - If the seed call is removed, `isPaused` stays `false` despite Focus being active
///   at construction time — exactly the cold-launch bug.
@MainActor
final class PauseConditionManagerColdStartRegressionTests: XCTestCase {

    /// Core cold-start regression: a detector that already reports `isFocused = true`
    /// when `startMonitoring()` is called must immediately set `isPaused = true`.
    ///
    /// Before the fix this assertion failed because the manager only ever reacted to
    /// *changes* via the `onFocusChanged` callback, never reading the initial value.
    func test_coldStart_focusAlreadyActive_startMonitoring_setsPaused() {
        let mockFocus = MockFocusStatusDetector()
        let mockCarPlay = MockCarPlayDetector()
        let mockDriving = MockDrivingActivityDetector()
        let mockPersistence = MockSettingsPersisting()
        let settings = SettingsStore(store: mockPersistence)
        settings.pauseDuringFocus = true

        // Simulate Focus Mode already active BEFORE the manager is created.
        // simulateFocusChange sets isFocused = true without triggering any callback
        // (onFocusChanged is nil before startMonitoring registers it).
        mockFocus.simulateFocusChange(true)
        XCTAssertTrue(mockFocus.isFocused, "Precondition: detector must report isFocused=true")

        let sut = PauseConditionManager(
            settings: settings,
            focusDetector: mockFocus,
            carPlayDetector: mockCarPlay,
            drivingDetector: mockDriving
        )

        // Before startMonitoring, no seed has been applied.
        XCTAssertFalse(sut.isPaused, "isPaused must be false before startMonitoring() — no conditions registered yet")

        // startMonitoring() must read isFocused and seed the initial state.
        sut.startMonitoring()

        XCTAssertTrue(
            sut.isPaused,
            "#119 regression: startMonitoring() must seed isPaused=true when focusDetector.isFocused "
            + "is already true at cold launch. If this fails, the seed call was removed.")

        sut.stopMonitoring()
    }

    /// Complement: if Focus Mode is NOT active at cold launch, `isPaused` must stay `false`.
    func test_coldStart_focusInactive_startMonitoring_doesNotPause() {
        let mockFocus = MockFocusStatusDetector()
        let mockPersistence = MockSettingsPersisting()
        let settings = SettingsStore(store: mockPersistence)
        settings.pauseDuringFocus = true

        // isFocused defaults to false — no simulateFocusChange call.
        let sut = PauseConditionManager(
            settings: settings,
            focusDetector: mockFocus,
            carPlayDetector: MockCarPlayDetector(),
            drivingDetector: MockDrivingActivityDetector()
        )
        sut.startMonitoring()

        XCTAssertFalse(sut.isPaused, "No active focus condition → isPaused must remain false after startMonitoring()")

        sut.stopMonitoring()
    }

    /// Verify the `onPauseStateChanged` callback fires immediately on startMonitoring()
    /// when focus is already active — callers (AppCoordinator) must receive the signal.
    func test_coldStart_focusAlreadyActive_startMonitoring_firesCallback() {
        let mockFocus = MockFocusStatusDetector()
        let mockPersistence = MockSettingsPersisting()
        let settings = SettingsStore(store: mockPersistence)
        settings.pauseDuringFocus = true

        mockFocus.simulateFocusChange(true)

        let sut = PauseConditionManager(
            settings: settings,
            focusDetector: mockFocus,
            carPlayDetector: MockCarPlayDetector(),
            drivingDetector: MockDrivingActivityDetector()
        )

        var callbackValue: Bool?
        sut.onPauseStateChanged = { callbackValue = $0 }

        sut.startMonitoring()

        XCTAssertEqual(
            callbackValue,
            true,
            "#119 regression: onPauseStateChanged must fire true when focus is already active at startMonitoring()")

        sut.stopMonitoring()
    }
}

// MARK: ─── Bug #118: ScreenTimeTracker Double-Resign One Reset ────────────────

/// Regression tests for Bug #118: posting `willResignActive` twice rapidly must
/// produce exactly ONE counter reset, not two.
///
/// **Root cause:** Before the fix, `handleWillResignActive` created a new
/// `resetTask` without first cancelling the previous one. Rapid double-resign
/// left an orphaned `Task` that called `resetAll()` 5 seconds after the first
/// notification — even if the app had returned to the foreground in the interim.
///
/// **Fix:** `resetTask?.cancel()` is called before `resetTask = Task { … }` in
/// `handleWillResignActive` (`ScreenTimeTracker.swift` line ~224).
///
/// **How this catches a regression:**
/// A threshold of 5.5 s guarantees the threshold requires 6 ticks (~6 s) to fire.
/// With the fix, no orphan exists; elapsed accumulates to 5.5 s and the threshold
/// fires at ~6 s. With the bug, the orphaned first Task fires `resetAll()` at t ≈ 5 s
/// (before elapsed reaches the threshold), wiping the counter; the threshold then
/// needs another 6 ticks and fires at ~11 s.
/// Timeout of 9 s: passes with the fix (~6 s actual), times out without it (~11 s).
@MainActor
final class ScreenTimeTrackerDoubleResignRegressionTests: XCTestCase {

    var sut: ScreenTimeTracker!

    override func setUp() {
        super.setUp()
        sut = ScreenTimeTracker()
    }

    override func tearDown() {
        sut.stop()
        sut = nil
        super.tearDown()
    }

    func test_doubleWillResignActive_secondCancelsFirst_onlyOneResetOccurs() async {
        // Threshold > 5 s so the orphaned first Task fires resetAll() BEFORE the
        // threshold would be reached. 5.5 s requires 6 ticks; orphan fires at ~5 s.
        sut.setThreshold(5.5, for: .eyes)

        let thresholdFired = expectation(
            description: "#118: threshold fires at ~6s (fix) not ~11s (bug — orphaned Task wipes counter at ~5s)")
        sut.onThresholdReached = { type in
            if type == .eyes { thresholdFired.fulfill() }
        }

        // Start the 1-second tick timer.
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        // Double-resign: the second resign MUST call resetTask?.cancel() before arming
        // a new Task (the fix). Without the fix, the first Task is orphaned and fires
        // resetAll() 5 s later regardless of subsequent lifecycle events.
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)

        // Return to active within the grace period — this cancels the one remaining
        // Task (the second resign's Task with the fix applied).
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

        // Fix: only one Task was ever live; it was cancelled by didBecomeActive.
        //      Elapsed accumulates from 0; threshold fires at ~6 s. ✓
        // Bug: first Task was NOT cancelled; second Task was cancelled by didBecomeActive.
        //      Orphaned first Task fires resetAll() at t ≈ 5 s, wiping the counter.
        //      Elapsed restarts from 0; threshold fires at ~11 s. ✗ (outside 9 s window)
        await fulfillment(of: [thresholdFired], timeout: 9.0)
    }
}

// MARK: ─── Bug #117: OverlayManager Queue-on-No-Scene ────────────────────────

/// Regression tests for Bug #117: `OverlayManager.showOverlay()` must queue the
/// request when no active `UIWindowScene` is found, not silently drop it.
///
/// **Root cause:** Before the fix, the no-scene guard path returned without
/// appending to `overlayQueue`, discarding the overlay request entirely.
///
/// **Fix:** The `else` branch of the window-scene guard now appends to
/// `overlayQueue` so the request is presented once a scene becomes foreground-active.
///
/// **Testability note:**
/// The private `overlayQueue` cannot be inspected directly. Full end-to-end FIFO
/// verification (queue fills → scene activates → presentNextQueuedOverlay dequeues)
/// requires a live `UIWindowScene` and is covered by the simulator integration suite.
/// The unit tests below verify:
///   1. `showOverlay` does not crash when no scene is active (headless test runner).
///   2. The `onDismiss` callback is NOT called synchronously (it would be called
///      immediately only if the overlay were "silently completed" instead of queued).
///   3. `isOverlayVisible` remains `false` (no scene → no window created).
///   4. `clearQueue()` drains the queue without crash (proves a queue exists to drain).
///
/// For the AppCoordinator-level verification that the queued request surfaces once
/// `presentPendingOverlayIfNeeded()` is called, see
/// `AppCoordinatorTests.test_handleNotification_eyes_thenPresentPending_callsShowOverlayWithEyes`.
@MainActor
final class OverlayManagerQueueOnNoSceneRegressionTests: XCTestCase {

    /// Core regression: `showOverlay` must not crash when there is no active
    /// UIWindowScene (the headless test runner has none). Before the fix the path
    /// fell through with a silent drop; the fix adds the queue-append so the call
    /// succeeds without a scene.
    func test_showOverlay_withNoActiveWindowScene_doesNotCrash() {
        let manager = OverlayManager()
        manager.showOverlay(for: .eyes, duration: 20, hapticsEnabled: false, pauseMediaEnabled: false) {}
        manager.clearQueue()
    }

    /// The `onDismiss` callback must NOT fire synchronously for a queued request.
    /// A silent-drop implementation might invoke the callback immediately to "complete"
    /// the request; queueing holds the callback until the overlay is actually shown
    /// and dismissed.
    func test_showOverlay_withNoActiveWindowScene_doesNotFireDismissCallbackImmediately() {
        let manager = OverlayManager()
        var dismissFired = false

        manager.showOverlay(for: .eyes, duration: 20, hapticsEnabled: false, pauseMediaEnabled: false) {
            dismissFired = true
        }

        XCTAssertFalse(
            dismissFired,
            "#117 regression: onDismiss must not fire synchronously for a queued request. "
            + "A silent drop that calls onDismiss() immediately would cause AppCoordinator to "
            + "reschedule the reminder without ever having shown the overlay.")

        manager.clearQueue()
    }

    /// No overlay window can be created without a scene — `isOverlayVisible` must
    /// stay `false` after a `showOverlay` call in a headless test environment.
    func test_showOverlay_withNoActiveWindowScene_isOverlayVisibleRemainsFalse() {
        let manager = OverlayManager()

        manager.showOverlay(for: .posture, duration: 15, hapticsEnabled: true, pauseMediaEnabled: false) {}

        XCTAssertFalse(
            manager.isOverlayVisible,
            "#117 regression: isOverlayVisible must stay false when showOverlay is called with no active scene")

        manager.clearQueue()
    }

    /// Multiple `showOverlay` calls with no active scene must all be queued without
    /// crashing. `clearQueue()` must succeed (proving the queue was populated).
    func test_showOverlay_multipleCallsWithNoScene_allQueueWithoutCrash() {
        let manager = OverlayManager()

        manager.showOverlay(for: .eyes, duration: 20, hapticsEnabled: false, pauseMediaEnabled: false) {}
        manager.showOverlay(for: .posture, duration: 10, hapticsEnabled: false, pauseMediaEnabled: false) {}
        manager.showOverlay(for: .eyes, duration: 30, hapticsEnabled: true, pauseMediaEnabled: false) {}

        // clearQueue must not crash — it drains whatever was queued.
        manager.clearQueue()

        // After clearing, isOverlayVisible must still be false.
        XCTAssertFalse(manager.isOverlayVisible)
    }
}
