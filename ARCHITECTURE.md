# Eye & Posture Reminder – iOS Architecture

> **Owner:** Rusty (iOS Architect)  
> **Last Updated:** 2026-04-24  
> **Status:** Foundation

---

## 1. Module Dependency Graph

```
┌─────────────────────────────────────────────────────────────┐
│                       EyePostureApp                         │
│                    (@main entry point)                      │
└────────────────────────┬────────────────────────────────────┘
                         │
          ┌───────────────┼───────────────────────────┐
          │               │                           │
          ▼               ▼                           ▼
 ┌────────────┐   ┌──────────────┐   ┌──────────────────────┐
 │   Views    │   │ ViewModels   │   │     Services         │
 │            │   │              │   │                      │
 │ Settings   │◄──┤  Settings    │◄──┤ Scheduler            │
 │ ReminderRow│   │  ViewModel   │   │ Overlay              │
 │ Overlay    │   │              │   │ ScreenTimeTracker    │
 │ Disclaimer │   │              │   │ PauseConditionManager│
 └────────────┘   └──────┬───────┘   └──────────────────────┘
                         │                  ▲
                         ▼                  │
                  ┌────────────┐            │
                  │   Models   │◄───────────┘
                  │            │
                  │ ReminderType
                  │ ReminderSettings
                  │ SettingsStore
                  └────────────┘
```

**Dependency Rules:**
- **Views** → **ViewModels** (observe via `@ObservedObject` / `@StateObject`)
- **ViewModels** → **Models + Services** (business logic coordination)
- **Services** → **Models** (read settings, define protocols)
- **Models** → No dependencies (pure data + persistence)

**Key Principle:** All dependencies flow downward. No circular references. Services never import Views or ViewModels.

---

## 2. Protocol Definitions

Protocols are the foundation of testability and decoupling from Apple frameworks.

### 2.1 `NotificationScheduling`

Abstracts `UNUserNotificationCenter` so we can test scheduling without firing real system notifications.

```swift
protocol NotificationScheduling {
    func requestAuthorization(
        options: UNAuthorizationOptions
    ) async throws -> Bool
    
    func add(_ request: UNNotificationRequest) async throws
    
    func removePendingNotificationRequests(
        withIdentifiers: [String]
    )
    
    func removeAllPendingNotificationRequests()
    
    func getPendingNotificationRequests() async -> [UNNotificationRequest]
}

// Production conformance
extension UNUserNotificationCenter: NotificationScheduling { }
```

**Why:** Unit tests inject a mock implementation; production code uses `UNUserNotificationCenter.current()` directly.

---

### 2.2 `OverlayPresenting`

Abstracts overlay window lifecycle so we can verify presentation logic without creating real UIWindows in tests.

```swift
protocol OverlayPresenting {
    func showOverlay(
        for reminderType: ReminderType,
        duration: TimeInterval,
        onDismiss: @escaping () -> Void
    )
    
    func dismissOverlay()
    
    var isOverlayVisible: Bool { get }
}
```

**Why:** UI tests verify overlay appearance; unit tests mock the presenter to verify scheduling logic doesn't double-trigger.

---

### 2.3 `SettingsPersisting`

Abstracts `UserDefaults` so we can use an in-memory store during tests.

```swift
protocol SettingsPersisting {
    func integer(forKey key: String) -> Int
    func set(_ value: Int, forKey key: String)
    func bool(forKey key: String) -> Bool
    func set(_ value: Bool, forKey key: String)
    func double(forKey key: String) -> Double
    func set(_ value: Double, forKey key: String)
}

// Production conformance
extension UserDefaults: SettingsPersisting { }
```

**Why:** Tests use a dictionary-backed mock; no file I/O during unit tests. Prevents test pollution between test runs.

---

## 3. Xcode Project Structure

```
EyePostureReminder.xcodeproj
│
├── EyePostureReminder/              (Main app target)
│   ├── App/
│   │   ├── EyePostureApp.swift      @main, scene configuration
│   │   ├── AppDelegate.swift        UNUserNotificationCenterDelegate
│   │   └── Info.plist
│   ├── Models/
│   │   ├── ReminderType.swift       enum: .eyes / .posture
│   │   ├── ReminderSettings.swift   struct: interval + breakDuration
│   │   └── SettingsStore.swift      SettingsPersisting wrapper
│   ├── Protocols/
│   │   ├── NotificationScheduling.swift
│   │   ├── OverlayPresenting.swift
│   │   └── SettingsPersisting.swift
│   ├── Services/
│   │   ├── ReminderScheduler.swift  implements scheduling via protocol
│   │   └── OverlayManager.swift     UIWindow overlay lifecycle
│   ├── ViewModels/
│   │   └── SettingsViewModel.swift  @ObservableObject
│   └── Views/
│       ├── SettingsView.swift       main screen
│       ├── ReminderRowView.swift    interval/duration pickers
│       └── OverlayView.swift        full-screen break overlay
│
├── EyePostureReminderTests/         (Unit test target)
│   ├── Mocks/
│   │   ├── MockNotificationScheduler.swift
│   │   ├── MockOverlayPresenter.swift
│   │   └── MockUserDefaults.swift
│   ├── Models/
│   │   └── SettingsStoreTests.swift
│   ├── Services/
│   │   ├── ReminderSchedulerTests.swift
│   │   └── OverlayManagerTests.swift
│   └── ViewModels/
│       └── SettingsViewModelTests.swift
│
└── EyePostureReminderUITests/       (UI test target)
    ├── SettingsFlowTests.swift      end-to-end settings changes
    └── OverlayDismissalTests.swift  overlay appearance + interaction
```

**Target Configuration:**
- **Deployment Target:** iOS 16.0 (for `.ultraThinMaterial` + modern SwiftUI List APIs)
- **Bundle ID:** `com.yashasg.eyeposturereminder`
- **Capabilities Required:**
  - Push Notifications (for `UNUserNotificationCenter`)
  - No background modes (no `UIBackgroundModes` in Info.plist)

---

## 4. Key Technical Decisions

### 4.1 Why MVVM Over Other Patterns?

**Decision:** Use Model-View-ViewModel (MVVM) pattern.

**Rationale:**
1. **SwiftUI native alignment:** `@ObservedObject` / `@StateObject` are purpose-built for MVVM. No impedance mismatch.
2. **Testability:** ViewModels are pure Swift classes—no UIKit or SwiftUI imports. Easy to unit test.
3. **Simplicity for this scope:** 1 settings screen + 1 overlay. MVVM's single-view-per-viewmodel mapping is natural here. No need for Coordinator or VIPER complexity.
4. **Clear responsibility:** Views render. ViewModels coordinate. Services execute. Models persist.

**Alternatives Considered:**
- **MVC:** UIKit's default. Too much logic bleeds into view controllers.
- **VIPER:** Overkill for 2 screens and no complex navigation.
- **The Composable Architecture (TCA):** Steep learning curve; third-party dependency. Not justified for this scope.

---

### 4.2 Why Protocols Over Concrete Types for System APIs?

**Decision:** Wrap `UNUserNotificationCenter`, `UserDefaults`, and overlay presentation in protocols.

**Rationale:**
1. **Unit test velocity:** Mocking system APIs without protocols requires swizzling or subclassing. Protocols are explicit contracts.
2. **Clear boundaries:** `ReminderScheduler` depends on `NotificationScheduling`, not `UNUserNotificationCenter`. This is a compile-time guarantee of decoupling.
3. **Easier to reason about:** When reading `ReminderScheduler`, the protocol shows *exactly* which methods we use, not the entire 50+ method surface of `UNUserNotificationCenter`.

**Trade-off:** Slight boilerplate cost (protocol definitions + conformance extensions). Worth it for testability in a health/wellness app where reminder reliability is critical.

---

### 4.3 UIWindow Overlay vs SwiftUI `.fullScreenCover`

**Decision:** Use a secondary `UIWindow` at `UIWindow.Level.alert + 1`.

**Rationale:**

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| `.fullScreenCover` | Pure SwiftUI, less code | Can be dismissed by swipe-down *without* calling `onDismiss` in some iOS versions. Doesn't cover system UI like Control Center if invoked while dragging. | ❌ Unreliable for critical reminders |
| `UIWindow` | Guaranteed to cover *all* content including keyboard, alerts, and partial sheets. Full control over dismissal. | Requires UIKit bridging via `UIHostingController`. | ✅ **Chosen** |

**Key consideration:** This app is a health intervention tool. The overlay *must* interrupt the user reliably. A SwiftUI sheet that can be accidentally swiped away defeats the purpose.

---

### 4.4 Data-Driven Configuration (Native-First, 4-Layer)

**Decision:** Use Apple's native platform mechanisms for configuration — not a monolithic JSON file.

**The 4 layers:**

| Layer | Mechanism | What It Owns |
|-------|-----------|-------------|
| **1** | Asset Catalog (`.xcassets`) | 6 semantic color tokens with automatic dark/light variants |
| **2** | String Catalog (`.xcstrings`) | ~35 user-facing strings; localization-ready |
| **3** | `defaults.json` (bundled) | Reminder intervals, break durations, feature flags (~10 values) |
| **4** | Swift code | Spacing, layout, animations, SF Symbol names, typography |

**Layer 1 — Asset Catalog colors:**
```swift
// SwiftUI (automatic dark/light adaptation)
Color("reminderBlue")

// UIKit (e.g., UIWindow tint in OverlayManager)
UIColor(named: "reminderBlue")
```
Replaces all `UIColor(dynamicProvider:)` calls in `DesignSystem.swift`. The OS handles dark/light switching — no Swift logic needed.

**Layer 2 — String Catalog:**
```swift
// SwiftUI picks up .xcstrings keys automatically
Text("overlay.eyes.title")

// Programmatic
String(localized: "overlay.eyes.title")
```
Covers all six view files. Xcode 15's String Catalog editor warns on stale keys and is localization-ready at no extra cost.

**Layer 3 — `defaults.json` load path:**
1. `SettingsStore.init()` checks if `epr.*` UserDefaults keys are absent (first launch).
2. If absent, `DefaultsLoader` reads `defaults.json` from `Bundle.main` and seeds `UserDefaults`.
3. On subsequent launches, `UserDefaults` wins — JSON is never re-read.
4. `SettingsStore.resetToDefaults()` clears `epr.*` keys and re-seeds (same path as first launch).

`DefaultsLoader` accepts a `Bundle` parameter for test injection.

**Layer 4 — Swift stays for:**
- Spacing constants (`AppSpacing.xs`, `AppSpacing.md`)
- Layout structure (`VStack`, `HStack`)
- Animation curves (`withAnimation(.easeInOut(duration: 0.3))`)
- SF Symbol names (`"eye.fill"`, `"figure.stand"`)
- Typography scale (`AppFont.headline`, `AppFont.body`)

**Override hierarchy:**
```
defaults.json (first-launch seed only)
    ↓
UserDefaults (user-editable settings)
    ↓
OS / runtime (dark mode, Dynamic Type, locale — always win)
```

**Rationale:**
1. **Asset Catalog colors** — The OS manages dark/light variants; no parsing, no `dynamicProvider` boilerplate.
2. **String Catalog** — Proper localization toolchain. JSON strings can't be pluralized or localized without re-inventing the wheel.
3. **defaults.json for settings** — Intervals and flags change frequently during development; JSON avoids PRs for tuning.
4. **Swift for layout/animation** — Type safety + autocomplete. These values are stable and never need runtime override.

**Alternatives considered and rejected:**
- **Single `app-config.json`:** JSON cannot serialize `UIColor`, `Animation`, or `UIFont`. Putting all four categories in JSON requires a bespoke parser for each and loses OS-level adaptation (dark mode, Dynamic Type).

---

### 4.6 Smart Pause – Focus Mode & Driving Detection

**Decision:** Pause reminders intelligently when users are in Focus Mode or driving.

**The Three Detectors (Phase 2 Feature):**

1. **Focus Status Detector** (`FocusStatusDetecting` protocol)
   - Uses `INFocusStatusCenter` to detect active Focus Modes (Do Not Disturb, Driving, Sleeping)
   - Requires `com.apple.intents` entitlement; available on iOS 16+
   - Query: `INFocusStatusCenter.default.focusStatus`

2. **CarPlay Detector** (`CarPlayDetecting` protocol)
   - Uses `AVAudioSession.currentRoute.outputs` to detect active CarPlay audio route
   - No special entitlement required; reliably indicates active navigation
   - Query: `.contains(where: { $0.portType == .carAudio })`

3. **Driving Activity Detector** (`DrivingActivityDetector` protocol)
   - Uses `CMMotionActivityManager` coprocessor for vehicle motion detection
   - Requires `NSMotionUsageDescription` in Info.plist
   - Query: `CMMotionActivityManager.current().dataFromDate(_:to:)` for recent activity

**Integration with AppCoordinator:**

`PauseConditionManager` aggregates signals from all three detectors and emits a single `isPaused: Bool` state:
```
isPaused = focusStatus == .active || carPlayActive || drivingDetected
```

When `isPaused` changes:
1. `AppCoordinator` calls `screenTimeTracker.pauseAll()` or `resumeAll()`
2. No reminders fire while paused; timers remain suspended
3. Timers resume from their previous elapsed time when `isPaused` returns to false

**Info.plist Permissions Required:**

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We use your location to avoid interrupting while driving.</string>
<key>NSMotionUsageDescription</key>
<string>We detect driving activity to pause reminders while you're behind the wheel.</string>
```

**Why Separate Service:**

Keeps `AppCoordinator` (450+ lines) within SRP. Pause logic is cohesive and testable independently via protocol mocks.

---

**Decision:** Use `UserDefaults` with a typed `SettingsStore` wrapper.

**Rationale:**
1. **Data model:** 5 scalar values (2 intervals, 2 durations, 1 boolean). No relationships, no queries, no history.
2. **Performance:** `UserDefaults` is in-memory after first read. Zero I/O for subsequent reads. SwiftData would introduce CoreData's entire stack for no gain.
3. **Battery:** No database file watching, no `NSPersistentContainer` background contexts.
4. **Migration simplicity:** Adding a new key to `UserDefaults` is a one-line change. SwiftData requires migration boilerplate.

**When to reconsider:** If Phase 3 requires storing *history* of breaks taken (e.g., for weekly analytics), then SwiftData becomes appropriate. Not for Phase 1.

---

## 5. Technical Risks

### 5.1 Notification Permission Flow

**Risk:** User denies notification permission → no background reminders.

**Mitigation:**
1. **Onboarding screen** (Phase 2) explains *why* we need notifications before requesting permission.
2. **Fallback mode:** If denied, `ReminderScheduler` runs a foreground-only `Timer` that fires while app is active. Settings screen shows a banner: *"Enable notifications in Settings to get reminders while using other apps."*
3. **Re-prompt strategy:** iOS doesn't allow re-prompting. We detect denial and show a deep link to `UIApplication.openSettingsURLString`.

**Severity:** Medium. Affects user experience but doesn't break the app.

---

### 5.2 Overlay on iPadOS

**Risk:** Secondary `UIWindow` behavior differs on iPadOS, especially in multitasking modes (Split View, Slide Over).

**Mitigation:**
1. **Test on iPad simulator** with all multitasking modes during Phase 1.
2. If overlay doesn't cover adjacent split-view windows: Accept this. The reminder is still visible in the app's window. Document in README.
3. Alternative: Use `UIWindowScene.windows` to find the *active* window scene and create the overlay there, rather than assuming the first scene.

**Severity:** Low. iPad is a secondary target; most users are on iPhone.

---

### 5.3 iOS Version Constraints

**Risk:** iOS 16.0 minimum excludes ~15% of devices still on iOS 15 (as of 2024).

**Mitigation:**
1. **Justify the requirement:** `.ultraThinMaterial` (iOS 15+) and SwiftUI `List` with modern section headers (iOS 16+) reduce code complexity by 30%.
2. **Backport path:** If App Store analytics show significant iOS 15 traffic, we can:
   - Replace `.ultraThinMaterial` with `.thinMaterial` (iOS 13+)
   - Use older `List` API with manual `Section` wrappers
   - Lower deployment target to iOS 15.0
3. **Cost-benefit:** For Phase 1, iOS 16+ is acceptable. Re-evaluate after TestFlight feedback.

**Severity:** Low. Forward-looking bet on iOS adoption curve.

---

### 5.4 Notification Scheduling Limits

**Risk:** `UNUserNotificationCenter` has a limit of 64 pending notifications per app.

**Mitigation:**
1. **Current design uses 2 notifications:** One for eyes, one for posture, both set to `repeats: true`. No limit risk.
2. **If we add snooze:** Each snooze creates a one-time notification. Cap snooze count at 5 per day to stay well under 64.

**Severity:** Very Low. Design naturally avoids the limit.

---

## 6. Build & Test Setup

### 6.1 Local Development

```bash
# Prerequisites
xcodebuild -version  # Xcode 15.0+
swift --version       # Swift 5.9+

# Build
xcodebuild -project EyePostureReminder.xcodeproj \
           -scheme EyePostureReminder \
           -configuration Debug \
           -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
           build

# Run unit tests
xcodebuild test \
           -project EyePostureReminder.xcodeproj \
           -scheme EyePostureReminder \
           -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
           -only-testing:EyePostureReminderTests

# Run UI tests
xcodebuild test \
           -project EyePostureReminder.xcodeproj \
           -scheme EyePostureReminder \
           -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
           -only-testing:EyePostureReminderUITests
```

---

### 6.2 CI Pipeline (GitHub Actions)

```yaml
# .github/workflows/ios-ci.yml
name: iOS CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: macos-14  # Xcode 15
    steps:
      - uses: actions/checkout@v4
      
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app
      
      - name: Build
        run: |
          xcodebuild build \
            -project EyePostureReminder.xcodeproj \
            -scheme EyePostureReminder \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0'
      
      - name: Run Unit Tests
        run: |
          xcodebuild test \
            -project EyePostureReminder.xcodeproj \
            -scheme EyePostureReminder \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
            -only-testing:EyePostureReminderTests \
            -resultBundlePath TestResults.xcresult
      
      - name: Upload Test Results
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: TestResults.xcresult
```

**Coverage Target:** 85% for Models, Services, ViewModels. Views are tested via UI tests.

---

### 6.3 Testing Strategy

| Layer | Test Type | Coverage Target | Key Tests |
|-------|-----------|-----------------|-----------|
| **Models** | Unit | 90% | `SettingsStore` read/write, default values |
| **Services** | Unit | 85% | `ReminderScheduler` schedules correct intervals; `OverlayManager` doesn't double-present |
| **ViewModels** | Unit | 85% | Settings changes trigger reschedule; bindings update correctly |
| **Views** | UI | 50% | Settings pickers save; overlay dismiss button works; countdown updates |
| **Integration** | Manual | N/A | End-to-end on device with real notifications; test in Low Power Mode |

**Manual Test Cases (Phase 1):**
1. Deny notification permission → foreground-only mode activates
2. Grant permission → background notifications fire after interval
3. Force quit app → notifications still scheduled
4. Overlay appears while app is active (no system banner)
5. Overlay auto-dismisses after break duration
6. Multiple reminders don't stack (second queues)

---

## 7. Coding Conventions

### 7.1 Naming

| Element | Convention | Example |
|---------|-----------|---------|
| **Types** (classes, structs, enums) | `PascalCase` | `ReminderScheduler` |
| **Protocols** | `PascalCase` + `-ing` suffix for capabilities | `NotificationScheduling`, `SettingsPersisting` |
| **Variables, functions** | `camelCase` | `eyesInterval`, `scheduleReminders()` |
| **Constants** | `camelCase` | `defaultEyesInterval = 1200` |
| **Enum cases** | `camelCase` | `.eyes`, `.posture` |
| **Private properties** | No prefix (Swift convention) | `private var window: UIWindow?` |

**Why:** Aligns with Swift API Design Guidelines. Protocol `-ing` suffix makes capabilities self-documenting.

---

### 7.2 File Organization

**One type per file** unless:
- A type is only used by its parent (e.g., a private nested struct)
- Related tiny types (<10 lines each) form a cohesive unit

**File naming:** Matches the primary type. `ReminderScheduler.swift` contains `final class ReminderScheduler`.

**Group related files** in Xcode:
- `Models/` folder contains all model types
- `Protocols/` folder contains all protocol definitions
- `Services/` folder contains all service implementations

---

### 7.3 Access Control Defaults

**Start with the most restrictive level:**
- `private` by default for properties and methods
- `fileprivate` only when a protocol extension in the same file needs access
- `internal` (implicit) for types and protocol conformances
- `public` only if this becomes a framework (not needed for Phase 1)

**Rationale:** Narrow interfaces reduce coupling. If a property is never accessed outside the type, `private` communicates intent.

---

### 7.4 SwiftUI View Structure

```swift
struct ExampleView: View {
    // MARK: - Properties
    @StateObject private var viewModel: ExampleViewModel
    @State private var isExpanded = false
    
    // MARK: - Body
    var body: some View {
        content
    }
    
    // MARK: - Subviews
    private var content: some View {
        VStack {
            // ...
        }
    }
    
    // MARK: - Actions
    private func handleTap() {
        // ...
    }
}
```

**Why:** `body` stays under 10 lines. Subviews are extracted to computed properties (no `@ViewBuilder` overhead for simple cases).

---

### 7.5 Error Handling

- Use `async throws` for service methods that can fail (e.g., `requestAuthorization`)
- Use `Result<Success, Failure>` for ViewModel methods that bridge async errors to SwiftUI (which doesn't support `throws` in bindings)
- Log errors via `print("...")` for Phase 1; replace with OSLog in Phase 2

**Don't:**
- Silently swallow errors with `try?` unless failure is expected and harmless (e.g., canceling an already-canceled notification)

---

### 7.6 Comments

**Write comments for:**
- Non-obvious "why" decisions (e.g., "UIWindow level must be > .alert to cover keyboard")
- Complex algorithms (if any emerge)
- TODOs with ticket numbers

**Don't comment:**
- What the code does (the code itself says that)
- Obvious SwiftUI DSL (e.g., `// Create a VStack`)

---

## 8. Technical Milestones

### Phase 1: MVP (Week 1-2)

| Milestone | Definition of Done |
|-----------|-------------------|
| **M1.1: Project scaffold** | Xcode project created, folder structure matches this doc, unit test target configured |
| **M1.2: Models + persistence** | `ReminderType`, `ReminderSettings`, `SettingsStore` implemented. Unit tests pass at 90% coverage. |
| **M1.3: Services** | `ReminderScheduler` schedules/cancels notifications via protocol. `OverlayManager` creates/dismisses UIWindow. Unit tests pass with mocks. |
| **M1.4: ViewModels** | `SettingsViewModel` exposes bindings for SwiftUI. Changes trigger reschedule. Unit tests pass. |
| **M1.5: Views** | `SettingsView` renders pickers, saves on change. `OverlayView` shows countdown, dismisses. UI tests pass. |
| **M1.6: Integration** | End-to-end manual test on simulator: set 10s interval, verify overlay appears, dismiss works, auto-dismiss works. |

**Exit Criteria:** App runs on simulator, fires foreground overlay after interval, settings persist across launches.

---

### Phase 2: Polish (Week 3)

| Milestone | Definition of Done |
|-----------|-------------------|
| **M2.1: Permission onboarding** | Onboarding screen explains notification need before requesting authorization. Fallback mode activates if denied. |
| **M2.2: Haptics** | Haptic feedback on overlay appearance (light tap). |
| **M2.3: Snooze action** | Notification actions: "Done" (dismiss) and "Snooze 5 min" (reschedule once). |
| **M2.4: Assets** | App icon designed, launch screen configured, SF Symbols chosen for overlay. |

**Exit Criteria:** TestFlight build submitted, internal testing complete.

---

### Phase 3: Optional (Future)

- iCloud sync via `NSUbiquitousKeyValueStore`
- Home Screen widget showing "Next break in X min"
- watchOS glance app
- Analytics: breaks completed vs skipped

---

## 9. Open Questions

| Question | Impact | Owner | Resolution Deadline |
|----------|--------|-------|---------------------|
| Should overlay support landscape mode with different layout? | Medium (iPad users) | Rusty | Before M1.5 |
| Do we need a "Do Not Disturb" mode (disable reminders during meetings)? | Low (MVP creep risk) | Product | After Phase 1 |
| Should settings support custom intervals (slider) vs fixed presets? | Low (UX complexity) | Design | Before M1.4 |

---

## 10. Testing Architecture

### 10.1 Test Pyramid

```
         ┌─────────────┐
         │  UI Tests   │   XCUITest — critical user flows (onboarding, settings, dismiss)
         │  (future)   │   Slowest, highest confidence for UX regressions
         └──────┬──────┘
                │
        ┌───────┴────────┐
        │  Integration   │   XCTest — real wiring between services, no mocks
        │  Tests (new)   │   Key pipelines: Settings → Coordinator → ScreenTimeTracker
        └───────┬────────┘
                │
  ┌─────────────┴──────────────┐
  │      Unit Tests            │   XCTest — isolated, mock-injected, fast
  │  Models / Services /       │   Primary layer; all logic lives here
  │  ViewModels / Views        │
  └────────────────────────────┘
```

**Unit tests** are the default. Write a unit test whenever logic can be exercised without a live UIWindowScene, real notification delivery, or real system APIs. This covers 100% of models, services, and ViewModels.

**Integration tests** sit in `Tests/EyePostureReminderTests/Integration/` (see §10.4). Use them for pipeline verification: does disabling the master toggle actually cancel pending notifications *and* stop `ScreenTimeTracker`? Integration tests use real `SettingsStore` + real `AppCoordinator` wired together, but still mock UIKit and UNUserNotificationCenter boundaries.

**UI tests** (XCUITest, future target) cover onboarding permission prompt, toggling a reminder type in settings, and tapping the overlay dismiss button. Add these before TestFlight beta.

---

### 10.2 Mock Patterns

#### Protocol-Based Mocks for System APIs

Every system boundary is behind a protocol. Tests inject mock implementations — no swizzling, no subclassing.

| Protocol | Mock Class | Production Type |
|----------|-----------|-----------------|
| `NotificationScheduling` | `MockNotificationCenter` | `UNUserNotificationCenter` |
| `SettingsPersisting` | `MockSettingsPersisting` | `UserDefaults` |
| `OverlayPresenting` | `MockOverlayPresenting` | `OverlayManager` |
| `ReminderScheduling` | `MockReminderScheduler` | `ReminderScheduler` |
| `MediaControlling` | `MockMediaControlling` | `AudioInterruptionManager` |
| `FocusStatusDetecting` | `MockFocusStatusDetector` | `LiveFocusStatusDetector` (INFocusStatusCenter) |
| `CarPlayDetecting` | `MockCarPlayDetector` | `LiveCarPlayDetector` (AVAudioSession) |
| `DrivingActivityDetecting` | `MockDrivingActivityDetector` | `LiveDrivingActivityDetector` (CMMotionActivityManager) |

**Mock contract:** Every mock class exposes call-count properties and `simulate*()` helpers so tests can drive state changes synchronously without real timers or hardware.

```swift
// Example: simulate a Focus Mode activation in PauseConditionManagerTests
mockFocus.simulateFocusChange(true)
XCTAssertTrue(sut.isPaused)
```

#### In-Memory `UserDefaults`

`MockSettingsPersisting` is a `[String: Any]` dictionary — no file I/O, no persistence across test runs. Instantiate a fresh copy in `setUp()` for full isolation:

```swift
override func setUp() {
    mockPersistence = MockSettingsPersisting()
    settings = SettingsStore(store: mockPersistence)
}
```

**When to use the real `UserDefaults`:** Never in unit tests. In integration tests, use a custom suite name (e.g., `UserDefaults(suiteName: "com.yashasg.epr.test-\(UUID())")`) and call `removeSuite(named:)` in `tearDown()`.

#### When to Mock vs. Use Real Implementations

| Scenario | Use Mock | Use Real |
|----------|----------|----------|
| Testing scheduling logic in `ReminderScheduler` | `MockNotificationCenter` | — |
| Testing that `SettingsStore` reads/writes correct keys | — | `MockSettingsPersisting` (is the real test subject) |
| Testing `PauseConditionManager` aggregation | All three detector mocks | — |
| Integration test: `AppCoordinator` full pipeline | `MockNotificationCenter`, `MockOverlayPresenting` | `SettingsStore`, `ScreenTimeTracker` |
| UI test: settings screen saves correctly | — | Full app stack |

---

### 10.3 Test Infrastructure

#### Mock Class Location & Naming

All mocks live in `Tests/EyePostureReminderTests/Mocks/`. Naming convention: `Mock` + protocol name minus the `-ing`/`-able` suffix where it reads naturally.

```
Tests/EyePostureReminderTests/Mocks/
├── MockMediaControlling.swift
├── MockNotificationCenter.swift
├── MockOverlayPresenting.swift
├── MockReminderScheduler.swift
└── MockSettingsPersisting.swift
```

PauseConditionManager detector mocks are defined inline at the top of `PauseConditionManagerTests.swift` since they are only used in that file.

#### Shared Setup Pattern

Each test class owns its own mock instances created in `setUp()` and nilled in `tearDown()`. No shared static state. No global singletons in test scope.

```swift
override func setUp() async throws {
    try await super.setUp()
    mockPersistence = MockSettingsPersisting()
    settings = SettingsStore(store: mockPersistence)
    mockScheduler = MockReminderScheduler()
    sut = SettingsViewModel(settings: settings, scheduler: mockScheduler)
}

override func tearDown() async throws {
    sut = nil
    mockScheduler = nil
    settings = nil
    mockPersistence = nil
    try await super.tearDown()
}
```

#### `@MainActor` Considerations

`SettingsViewModel`, `OverlayManager`, and `AppCoordinator` are `@MainActor` isolated. Their test classes must be annotated `@MainActor` too:

```swift
@MainActor
final class SettingsViewModelTests: XCTestCase { ... }
```

Methods that internally spawn `Task {}` require a short async sleep before assertions to let the spawned task complete:

```swift
sut.masterToggleChanged()
try? await Task.sleep(nanoseconds: 200_000_000) // 200ms for inner Task
XCTAssertEqual(mockScheduler.scheduleRemindersCallCount, 1)
```

This pattern is intentional — do not replace with `XCTestExpectation` unless the timing is genuinely unpredictable. The 200ms budget is generous for these no-I/O code paths.

---

### 10.4 File Organization

```
Tests/EyePostureReminderTests/
├── Fixtures/
│   └── defaults.json               Bundled defaults fixture for DefaultsLoader tests
├── Mocks/                          Shared mock implementations (see §10.3)
├── Models/                         Unit tests for model types
│   ├── AppConfigTests.swift
│   ├── OnboardingTests.swift
│   ├── ReminderTypeTests.swift
│   ├── SettingsStoreConfigTests.swift
│   ├── SettingsStorePhase2Tests.swift
│   └── SettingsStoreTests.swift
├── Services/                       Unit tests for service layer
│   ├── AppCoordinatorTests.swift
│   ├── AudioInterruptionManagerTests.swift
│   ├── OverlayManagerTests.swift
│   ├── PauseConditionManagerTests.swift
│   └── ReminderSchedulerTests.swift
├── ViewModels/                     Unit tests for ViewModel layer
│   ├── SettingsViewModelPhase2Tests.swift
│   └── SettingsViewModelTests.swift
├── Views/                          Unit tests for design system / string catalog
│   ├── ColorTokenTests.swift
│   ├── DesignSystemTests.swift
│   └── StringCatalogTests.swift
├── Integration/                    ← NEW: integration tests (real service wiring)
│   └── (add per pipeline, e.g. SchedulingPipelineTests.swift)
└── RegressionTests.swift           Bug regression guards; one section per fixed bug
```

**`RegressionTests.swift`** is the sentinel file. Each section is a compile-time or runtime guard against a specific bug regressing. Add a section here whenever a bug is fixed — not just when tests fail. Format:

```swift
// Bug N: <title> (fixed: <short description>)
// Root cause: ...
// How these tests catch a regression: ...
```

**Future UI test target:** `EyePostureReminderUITests/` — add before TestFlight beta. Minimum cases: onboarding permission prompt, toggling a reminder type, overlay dismiss button.

---

### 10.5 Coverage Targets

| Layer | Target | Rationale |
|-------|--------|-----------|
| **Models** | 90% | Pure Swift — all branches exercisable without system APIs |
| **Services** | 85% | Some branches require live UIWindowScene (integration-only) |
| **ViewModels** | 85% | `@MainActor` isolation makes these fast to test |
| **Views** | 50% | Design system tokens + string catalog keys; visual layout not measurable by XCTest |
| **Integration** | Key pipelines | Settings → Coordinator → ScreenTimeTracker; Pause signals → Coordinator |
| **UI** | Critical flows | Onboarding, settings save, overlay dismiss |

**Key service pipelines for integration tests:**
1. `SettingsStore.masterEnabled = false` → `AppCoordinator` cancels all notifications + stops `ScreenTimeTracker`
2. `ScreenTimeTracker` threshold reached → `AppCoordinator` shows overlay → overlay dismiss → tracker resets
3. `PauseConditionManager.isPaused = true` → `AppCoordinator` suspends `ScreenTimeTracker`; `isPaused = false` → resumes from prior elapsed time

---

### 10.6 Performance Testing

Battery-sensitive code paths use `.measure {}` blocks to establish baselines and catch regressions:

```swift
func test_pauseConditionManager_performance_allDetectorsActive() {
    measure {
        // Simulate rapid state changes across all three detectors.
        // Baseline: < 1ms per evaluation on a mid-range simulator.
        for _ in 0..<1000 {
            mockFocus.simulateFocusChange(true)
            mockFocus.simulateFocusChange(false)
        }
    }
}
```

**Where to add `.measure {}` blocks:**
- `PauseConditionManager` state aggregation (fires on every detector event)
- `ScreenTimeTracker` tick handler (fires every second while foreground)
- `SettingsStore` key serialization (fires on every settings save)

Establish baselines on the CI runner (not local) to avoid machine-dependent drift. Use `XCTest`'s `measureOptions` to set a `stdDevThreshold` of 10%.

---

## 11. References

- [Apple Human Interface Guidelines – Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications)
- [UNUserNotificationCenter Documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [20-20-20 Rule (American Optometric Association)](https://www.aoa.org/healthy-eyes/caring-for-your-eyes/screen-time)

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-04-24 | Initial architecture definition | Rusty |
| 2026-04-26 | Added Section 10: Testing Architecture | Rusty |
