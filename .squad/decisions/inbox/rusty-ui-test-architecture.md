# Architecture Proposal: Making UI Tests Runnable

**Author:** Rusty (iOS Architect)  
**Date:** 2026-04-26  
**Status:** Proposed  
**Issue:** GitHub #110 — "All 31 UI tests are dead code — no xcodeproj UITest target"

---

## Problem Statement

31 XCUITest methods exist across 4 files in `Tests/EyePostureReminderUITests/` — all dead code. SPM's `.testTarget` produces XCTest unit test bundles, not XCUITest UI test bundles. XCUITest requires a UITest bundle target, which can only be defined in an `.xcodeproj` or `.xcworkspace`. The tests compile against `XCTest` but call `XCUIApplication()`, which is XCUITest-only API — they will crash or fail to link in a unit test bundle.

**Existing test inventory (31 methods):**

| File | Tests | Pattern |
|---|---|---|
| `HomeScreenTests.swift` | 7 | `XCUIApplication` launch, element queries by accessibility ID |
| `OnboardingFlowTests.swift` | 7 | Multi-step flow navigation, launch arguments |
| `SettingsFlowTests.swift` | 13 | Sheet presentation, toggle interaction, navigation |
| `OverlayTests.swift` | 4 | Negative tests (overlay not present), accessibility label checks |

All 31 tests use `XCUIApplication`, `app.launch()`, `app.launchArguments`, element queries — genuine XCUITest patterns. They are **not convertible** to ViewInspector or unit tests without a full rewrite.

---

## Options Evaluated

### Option 1: Minimal .xcodeproj for UITest Target Only (⭐ RECOMMENDED)

Add a `.xcodeproj` that contains **only** the UITest bundle target. The app target and unit test target remain in `Package.swift`.

**How it works:**
- Xcode can open `Package.swift` directly and generates an implicit scheme for the executable and test targets.
- A small `.xcodeproj` is added containing:
  1. A reference to the app product from `Package.swift` (via scheme dependency)
  2. A UITest bundle target (`EyePostureReminderUITests`) pointing at `Tests/EyePostureReminderUITests/`
- `xcodebuild test` invokes the UITest scheme, which builds the app from the SPM package and runs UI tests against the simulator.

**Minimal xcodeproj contents:**
```
EyePostureReminder.xcodeproj/
├── project.pbxproj          # UITest target only
├── xcshareddata/
│   └── xcschemes/
│       └── EyePostureReminderUITests.xcscheme
```

**Pros:**
- All 31 existing tests work as-is (zero modifications to test code)
- Unit tests stay in SPM — no regression to existing workflow
- Full XCUITest capability: real app launch, accessibility auditing, interaction testing
- `Package.swift` remains the source of truth for app code and unit tests
- `.xcodeproj` is small and unlikely to drift (it only references the UITest files)

**Cons:**
- Two build system artifacts to maintain (though the xcodeproj is minimal)
- Team must understand which tests run where
- Xcode project file is notoriously merge-unfriendly (mitigated by small size)

### Option 2: Full .xcodeproj (Dual Build System)

Create a complete `.xcodeproj` with app target, unit test target, and UITest target. Keep `Package.swift` for CLI/CI unit tests.

**Pros:** Full Xcode feature set, App Store distribution from project  
**Cons:** Significant drift risk between Package.swift and xcodeproj. Two places to add files, update settings, manage dependencies. Maintenance burden far exceeds the benefit for UITests alone. **Not recommended.**

### Option 3: ViewInspector (Third-Party Library)

Add [ViewInspector](https://github.com/nicklkokot/ViewInspector) as an SPM dependency for testing SwiftUI views as unit tests.

**Pros:** Stays entirely in SPM, fast execution, no simulator  
**Cons:**
- Tests view **structure**, not rendering or interaction — fundamentally different from XCUITest
- All 31 tests would require a **complete rewrite** — they use `XCUIApplication`, launch arguments, element queries, navigation flows
- Cannot test: app launch behavior, overlay window presentation (UIWindow), notification permission prompts, accessibility in rendered context
- Cannot test cross-view navigation flows (onboarding → home → settings)
- Limited to inspecting individual views in isolation — our tests verify **flows**

**Verdict:** Wrong tool for these tests. ViewInspector is valuable for view-level unit tests (e.g., "does ReminderRowView show the correct icon?") but cannot replace flow-based UI tests. Could be added separately as a complement — not a replacement.

### Option 4: Xcode-Generated Project from Package.swift

`xcodebuild -create-xcodeproj` (deprecated) or opening Package.swift in Xcode to get the auto-generated scheme.

**Findings:**
- `swift package generate-xcodeproj` is deprecated since Swift 5.6 and removed in later toolchains
- Xcode's "Open Package" generates a **transient** workspace — no `.xcodeproj` on disk to add a UITest target to
- You cannot add a UITest target to the implicit workspace Xcode creates from Package.swift
- Dead end.

### Option 5: Swift Testing (@Test macros)

Swift Testing (`import Testing`, `@Test`, `@Suite`) is a modern test framework but operates at the **unit test level**. It does not provide:
- Application launch (`XCUIApplication`)
- Element queries (`app.buttons["id"]`)
- Simulated user interaction (taps, swipes, typing)
- Accessibility auditing

**Verdict:** Irrelevant to this problem. Swift Testing could replace XCTest for unit tests but has zero XCUITest equivalent.

---

## Recommendation: Option 1 — Minimal .xcodeproj for UITest Target

### Implementation Plan

#### Step 1: Create the Xcode project (xcodeproj)

Use `xcodebuild` or Xcode IDE to create a minimal project containing:
- **No app target** — the app builds from Package.swift via scheme reference
- **One UITest bundle target:** `EyePostureReminderUITests`
  - Source files: `Tests/EyePostureReminderUITests/*.swift`
  - Test host: `EyePostureReminder.app` (the SPM executable product)
  - `TEST_HOST = $(BUILT_PRODUCTS_DIR)/EyePostureReminder.app/EyePostureReminder`
  - `BUNDLE_LOADER = $(TEST_HOST)`... actually for UI tests these aren't needed — UI tests launch the app as a separate process.

For a UITest target specifically:
```
TEST_TARGET_NAME = EyePostureReminderUITests
PRODUCT_BUNDLE_IDENTIFIER = com.yashasg.EyePostureReminder.UITests
TEST_TARGET_NAME = EyePostureReminder  (target application)
USES_XCTRUNNER = YES
```

**Practical approach:** The simplest path is:
1. Open `Package.swift` in Xcode
2. File → New → Target → UI Testing Bundle
3. Set the target application to `EyePostureReminder`
4. Point the source files to `Tests/EyePostureReminderUITests/`
5. Save the generated `.xcodeproj`
6. Remove auto-generated boilerplate files (Xcode creates a default test file)

#### Step 2: Create a UITest Scheme

Add `EyePostureReminderUITests.xcscheme` in `xcshareddata/xcschemes/` so it's version-controlled:
- Build action: build `EyePostureReminder` (from Package.swift) and `EyePostureReminderUITests` (from xcodeproj)
- Test action: run `EyePostureReminderUITests` on iOS Simulator

#### Step 3: Update `scripts/build.sh`

Add a new subcommand:

```bash
cmd_uitest() {
  header "UI TEST"
  require_xcodebuild
  local dest
  dest=$(detect_destination)
  info "Destination: $dest"
  info "UI Test target: EyePostureReminderUITests"

  run_xcodebuild test \
    -project "EyePostureReminder.xcodeproj" \
    -scheme "EyePostureReminderUITests" \
    -destination "$dest" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -resultBundlePath "${PACKAGE_PATH}/UITestResults.xcresult"

  pass "UI tests passed"
}
```

#### Step 4: Update CI (`.github/workflows/ci.yml`)

Add a separate job or step for UI tests:

```yaml
  ui-test:
    name: UI Tests
    runs-on: macos-15
    timeout-minutes: 30
    needs: build-and-test  # Run after unit tests pass
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -switch /Applications/Xcode_${{ env.XCODE_VERSION }}.app/Contents/Developer

      - name: UI Tests (simulator)
        run: ./scripts/build.sh uitest

      - name: Upload UI test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: ui-test-results-build${{ github.run_number }}
          path: UITestResults.xcresult
          retention-days: 30
```

**Why a separate job:**
- UI tests are slow (simulator launch + app launch per test) — 2-5 minutes for 31 tests
- Unit tests should not be blocked by UI test failures
- UI tests are inherently flakier — separate job allows re-run without re-running unit tests
- Cleaner artifact separation (TestResults.xcresult vs UITestResults.xcresult)

#### Step 5: Test File Changes

**None.** All 31 existing test files use standard XCUITest patterns and will work as-is once the UITest bundle target exists. The accessibility identifiers are already in the production code (documented in the UITests README). The launch argument handling (`--skip-onboarding`, `--reset-onboarding`) is already wired in `AppDelegate.swift`.

#### Step 6: .gitignore Updates

Add to `.gitignore`:
```
# Xcode project user data (xcodeproj is committed, but user state is not)
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
UITestResults.xcresult/
```

---

## Trade-Off Summary

| Criterion | Option 1 (Minimal xcodeproj) | Option 2 (Full xcodeproj) | Option 3 (ViewInspector) |
|---|---|---|---|
| Existing tests work as-is | ✅ Yes | ✅ Yes | ❌ Full rewrite |
| SPM unit tests unchanged | ✅ Yes | ⚠️ Risk of drift | ✅ Yes |
| Real device testing | ✅ Yes | ✅ Yes | ❌ No |
| Accessibility auditing | ✅ Yes | ✅ Yes | ❌ No |
| Maintenance burden | Low | High | Low |
| CI complexity | Medium (2 jobs) | High | Low |
| Flow testing | ✅ Full | ✅ Full | ❌ View-only |

---

## Risk Mitigation

**Risk: xcodeproj drift from Package.swift**
- Mitigation: The xcodeproj has NO app target — it only references the SPM-built app product. Drift can only occur if UITest source files are added/removed, which is infrequent.
- Add a CI check: verify UITest target source files match `Tests/EyePostureReminderUITests/*.swift` glob.

**Risk: UI test flakiness in CI**
- Mitigation: Separate CI job with retry capability. Use `xcodebuild test -retry-tests-on-failure -test-iterations 2` (Xcode 15+).

**Risk: Xcode version compatibility**
- Mitigation: Pin Xcode version in CI (already done: `XCODE_VERSION: "16.2"`). UITest bundle format is stable across Xcode versions.

---

## Future Considerations

1. **ViewInspector as complement (not replacement):** Add ViewInspector for view-level unit tests that don't need a running app. These live in the SPM test target alongside existing unit tests. Good for testing: custom view modifiers, conditional rendering, design system components.

2. **Xcode Cloud:** If the team moves to Xcode Cloud for distribution, the `.xcodeproj` becomes the primary build system and the "minimal xcodeproj" naturally evolves into a full project. This is a forward-compatible choice.

3. **Accessibility Audit Tests:** With a UITest target available, add `XCUIApplication().performAccessibilityAudit()` (Xcode 15+) tests to catch accessibility regressions automatically.

---

## Action Items

| # | Task | Owner | Effort |
|---|---|---|---|
| 1 | Create minimal `.xcodeproj` with UITest bundle target | Rusty | 1-2h |
| 2 | Verify all 31 tests pass on simulator | Livingston | 1h |
| 3 | Add `uitest` subcommand to `scripts/build.sh` | Basher | 30min |
| 4 | Add `ui-test` job to `.github/workflows/ci.yml` | Basher | 30min |
| 5 | Update `.gitignore` for xcodeproj user data | Any | 5min |
| 6 | Update UITests README to remove "not yet runnable" caveat | Livingston | 5min |

**Total effort: ~3-4 hours**
