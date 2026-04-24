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
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
┌────────────┐   ┌──────────────┐   ┌──────────┐
│   Views    │   │ ViewModels   │   │ Services │
│            │   │              │   │          │
│ Settings   │◄──┤  Settings    │◄──┤ Scheduler│
│ ReminderRow│   │  ViewModel   │   │ Overlay  │
│ Overlay    │   │              │   │          │
└────────────┘   └──────┬───────┘   └─────┬────┘
                        │                  │
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

### 4.4 UserDefaults vs SwiftData for Settings Persistence

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

## 10. References

- [Apple Human Interface Guidelines – Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications)
- [UNUserNotificationCenter Documentation](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [20-20-20 Rule (American Optometric Association)](https://www.aoa.org/healthy-eyes/caring-for-your-eyes/screen-time)

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-04-24 | Initial architecture definition | Rusty |
