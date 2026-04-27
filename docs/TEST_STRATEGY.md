# kshana — Test Strategy

> **Author:** Livingston (Tester)  
> **Created:** 2026-04-24  
> **Phase:** Phase 1  
> **Stack:** XCTest, XCUITest, Swift 5.9+, iOS 16.0+

---

## 1. Test Pyramid

```
           ▲
          /█\        UI Tests (E2E)
         / █ \       ~10% of total tests
        /─────\      Slow, brittle, high confidence on real flows
       / ██████\
      / ████████\    Integration Tests
     /────────────\  ~20% of total tests
    / ████████████\  Medium speed, real system interactions mocked
   /────────────────\
  / ████████████████\ Unit Tests
 /────────────────────\ ~70% of total tests
/──────────────────────\ Fast, deterministic, pure logic isolation
```

### Rationale

| Layer | Count (target) | Speed | Confidence | Scope |
|-------|----------------|-------|------------|-------|
| **Unit** | ~70 tests | < 0.5s each | Logic correctness | Services, ViewModels, Models |
| **Integration** | ~20 tests | 1–3s each | Protocol wiring + scheduling math | Scheduler + mock notification center |
| **UI** | ~10 tests | 10–30s each | User flows end-to-end | Settings screen, overlay lifecycle |

**Total target:** ~100 automated tests for Phase 1 milestone.

---

## 2. Coverage Targets

| Layer | Target | Rationale |
|-------|--------|-----------|
| **Models** | **90%** | Pure Swift data structures — no excuses for missing coverage |
| **Services** | **80%** | `ReminderScheduler`, `OverlayManager` — high risk, high reward to test |
| **ViewModels** | **80%** | Pure Swift `ObservableObject` — no UIKit/SwiftUI dependencies |
| **Views** | **60%** | UI tests cover critical paths; layout edge cases accepted as manual |
| **Integration** | N/A (manual baseline) | Real device with live notifications — not tracked by Xcode coverage |

> **Coverage is measured per-target in Xcode.** Run with `⌘U` → Product → Test → Show Code Coverage. Gate CI on 80% for `EyePostureReminderTests`.

---

## 3. Mock Strategy

### 3.1 `MockNotificationScheduler` — mocking `NotificationScheduling`

**Why:** `UNUserNotificationCenter` triggers real iOS system calls. Unit tests must never fire live notifications, touch the notification permission UI, or depend on system state.

```swift
// EyePostureReminderTests/Mocks/MockNotificationScheduler.swift

final class MockNotificationScheduler: NotificationScheduling {
    
    // MARK: - Call Tracking
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var removeAllCalled = false
    var pendingRequests: [UNNotificationRequest] = []
    
    // MARK: - Configurable Responses
    var authorizationResult: Bool = true
    var authorizationError: Error? = nil
    
    // MARK: - NotificationScheduling
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if let error = authorizationError { throw error }
        return authorizationResult
    }
    
    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }
    
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }
    
    func removeAllPendingNotificationRequests() {
        removeAllCalled = true
    }
    
    func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        return pendingRequests
    }
    
    // MARK: - Test Helpers
    func reset() {
        addedRequests = []
        removedIdentifiers = []
        removeAllCalled = false
    }
}
```

**Tests that use this mock:** `ReminderSchedulerTests`, `SettingsViewModelTests`

---

### 3.2 `MockOverlayPresenter` — mocking `OverlayPresenting`

**Why:** `OverlayManager` creates a real `UIWindow` at `.alert + 1` level. That requires a running `UIWindowScene`, which is unavailable in unit test hosts. Mocking `OverlayPresenting` lets us verify scheduling logic never calls `show()` twice without an intervening `dismiss()`.

```swift
// EyePostureReminderTests/Mocks/MockOverlayPresenter.swift

final class MockOverlayPresenter: OverlayPresenting {
    
    // MARK: - State
    private(set) var isOverlayVisible: Bool = false
    private(set) var showCallCount = 0
    private(set) var dismissCallCount = 0
    private(set) var lastShownType: ReminderType? = nil
    private(set) var lastDuration: TimeInterval = 0
    var onDismissCallback: (() -> Void)? = nil
    
    // MARK: - OverlayPresenting
    func showOverlay(
        for reminderType: ReminderType,
        duration: TimeInterval,
        onDismiss: @escaping () -> Void
    ) {
        isOverlayVisible = true
        showCallCount += 1
        lastShownType = reminderType
        lastDuration = duration
        onDismissCallback = onDismiss
    }
    
    func dismissOverlay() {
        isOverlayVisible = false
        dismissCallCount += 1
        onDismissCallback?()
        onDismissCallback = nil
    }
    
    // MARK: - Test Helpers
    func simulateDismiss() {
        dismissOverlay()
    }
    
    func reset() {
        isOverlayVisible = false
        showCallCount = 0
        dismissCallCount = 0
        lastShownType = nil
        onDismissCallback = nil
    }
}
```

**Tests that use this mock:** `OverlayManagerTests`, `ReminderSchedulerTests` (verifying no double-show)

---

### 3.3 `MockAudioSession` — mocking `MediaControlling`

**Why:** `AVAudioSession` requires a real audio hardware context that is not available in unit test environments. Mocking lets us verify the app correctly activates/deactivates the audio session around overlay presentation without touching real system audio.

```swift
// EyePostureReminderTests/Mocks/MockAudioSession.swift

final class MockAudioSession: MediaControlling {
    
    private(set) var setActiveCalled = false
    private(set) var lastActiveState: Bool? = nil
    private(set) var lastCategory: AVAudioSession.Category? = nil
    var setActiveError: Error? = nil
    
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        if let error = setActiveError { throw error }
        setActiveCalled = true
        lastActiveState = active
    }
    
    func setCategory(_ category: AVAudioSession.Category) throws {
        lastCategory = category
    }
    
    func reset() {
        setActiveCalled = false
        lastActiveState = nil
        lastCategory = nil
    }
}
```

**Tests that use this mock:** `OverlayManagerTests` (audio session around overlay), any future background audio interruption tests

---

### 3.4 `InMemoryUserDefaults` — in-memory `SettingsPersisting` for `SettingsStore`

**Why:** Real `UserDefaults` writes to disk, persists across test runs, and allows test pollution — a passing test can corrupt state for the next test. An in-memory dictionary-backed implementation isolates every test and runs without I/O.

```swift
// EyePostureReminderTests/Mocks/MockUserDefaults.swift

final class MockUserDefaults: SettingsPersisting {
    
    private var store: [String: Any] = [:]
    
    func integer(forKey key: String) -> Int {
        return store[key] as? Int ?? 0
    }
    
    func set(_ value: Int, forKey key: String) {
        store[key] = value
    }
    
    func bool(forKey key: String) -> Bool {
        return store[key] as? Bool ?? false
    }
    
    func set(_ value: Bool, forKey key: String) {
        store[key] = value
    }
    
    func double(forKey key: String) -> Double {
        return store[key] as? Double ?? 0.0
    }
    
    func set(_ value: Double, forKey key: String) {
        store[key] = value
    }
    
    // MARK: - Test Helpers
    func reset() {
        store = [:]
    }
    
    func dump() -> [String: Any] {
        return store
    }
}
```

**Tests that use this mock:** `SettingsStoreTests`, `SettingsViewModelTests`

---

## 4. Critical Test Scenarios — Phase 1

### 4.1 Settings Persistence (`SettingsStoreTests`)

| # | Test Name | Scenario | Expected Result |
|---|-----------|----------|-----------------|
| SP-01 | `testSaveAndLoad_eyeInterval` | Save eye interval 30 min, reload store | Returns 30 min |
| SP-02 | `testSaveAndLoad_postureInterval` | Save posture interval 45 min, reload store | Returns 45 min |
| SP-03 | `testSaveAndLoad_eyeBreakDuration` | Save eye break 20s, reload | Returns 20s |
| SP-04 | `testSaveAndLoad_postureBreakDuration` | Save posture break 60s, reload | Returns 60s |
| SP-05 | `testDefaultValues` | Fresh MockUserDefaults, read all settings | Eyes: 20min/20s, Posture: 30min/10s, enabled: true |
| SP-06 | `testToggle_eyesEnabled` | Toggle eyes reminder to false, reload | Eyes disabled |
| SP-07 | `testToggle_postureEnabled` | Toggle posture reminder to false, reload | Posture disabled |
| SP-08 | `testToggle_masterEnabled` | Toggle master switch to false, reload | All reminders disabled |
| SP-09 | `testClearAllSettings` | Save values then reset store | All values return to defaults |
| SP-10 | `testSnoozeExpiry_notActive` | Snooze not set | isSnoozeActive returns false |
| SP-11 | `testSnoozeExpiry_activeNotExpired` | Set snooze expiry 5 min in future | isSnoozeActive returns true |
| SP-12 | `testSnoozeExpiry_expired` | Set snooze expiry 1 min in past | isSnoozeActive returns false |
| SP-13 | `testPerTypePersistence_independent` | Save eye=off, posture=on | Only posture fires; eyes skipped |

---

### 4.2 Notification Scheduling (`ReminderSchedulerTests`)

| # | Test Name | Scenario | Expected Result |
|---|-----------|----------|-----------------|
| NS-01 | `testScheduleAll_addsTwoRequests` | Call `scheduleAll()` with both enabled | Mock receives exactly 2 `add()` calls |
| NS-02 | `testScheduleAll_correctEyeInterval` | Schedule with eye interval 20 min | Request trigger is `timeInterval = 1200`, `repeats = true` |
| NS-03 | `testScheduleAll_correctPostureInterval` | Schedule with posture interval 30 min | Request trigger is `timeInterval = 1800`, `repeats = true` |
| NS-04 | `testReschedule_cancelsFirst` | Change interval, call `reschedule()` | `removePendingNotificationRequests` called before new `add()` |
| NS-05 | `testReschedule_schedulesNew` | Reschedule after interval change | New request added with updated interval |
| NS-06 | `testCancel_removesAll` | Call `cancelAll()` | `removeAllPendingNotificationRequests()` called once |
| NS-07 | `testDisabledType_notScheduled` | Eyes disabled, posture enabled | Only 1 request added (posture only) |
| NS-08 | `testBothDisabled_noRequests` | Both disabled | Zero requests added |
| NS-09 | `testSnoozeCheck_skipsScheduling` | Snooze active, schedule called | No new request added during active snooze |
| NS-10 | `testSnoozeCheck_schedulesAfterExpiry` | Snooze expired, schedule called | Request added normally |
| NS-11 | `testIntervalAccuracy_10min` | Schedule with 10 min interval | Trigger interval exactly 600 seconds |
| NS-12 | `testIntervalAccuracy_60min` | Schedule with 60 min interval | Trigger interval exactly 3600 seconds |
| NS-13 | `testRequestIdentifiers_unique` | Schedule both types | Eye identifier ≠ posture identifier |
| NS-14 | `testAuthorizationDenied_handledGracefully` | Mock returns `false` from authorization | Scheduler marks permission denied, no scheduling |
| NS-15 | `testAuthorizationError_handledGracefully` | Mock throws from authorization | Scheduler catches error, no crash |

---

### 4.3 Overlay Logic (`OverlayManagerTests`)

| # | Test Name | Scenario | Expected Result |
|---|-----------|----------|-----------------|
| OV-01 | `testShow_setsVisibleTrue` | Call `show()` | `isOverlayVisible` is true |
| OV-02 | `testDismiss_setsVisibleFalse` | Call `show()` then `dismiss()` | `isOverlayVisible` is false |
| OV-03 | `testAutoDismiss_atZero` | Countdown reaches 0 | `dismissOverlay()` called automatically |
| OV-04 | `testAutoDismiss_doesNotFireBeforeZero` | 1 second remaining | Overlay still visible |
| OV-05 | `testQueueOverlapping_noDoubleShow` | Call `show()` twice with no dismiss | `showCallCount == 1`; second queued |
| OV-06 | `testQueueOverlapping_showsSecondAfterDelay` | First dismissed → 2s passes | Second overlay shown after gap |
| OV-07 | `testQueueOverlapping_2sGap` | Measure time between first dismiss and second show | Gap ≥ 2.0 seconds |
| OV-08 | `testSwipeUpDismiss_callsDismiss` | Simulate swipe-up gesture | `dismissOverlay()` called |
| OV-09 | `testDismissButton_callsDismiss` | Simulate × tap | `dismissOverlay()` called |
| OV-10 | `testOnDismissCallback_invoked` | Provide `onDismiss` closure, then dismiss | Closure invoked exactly once |
| OV-11 | `testOnDismissCallback_notCalledBeforeDismiss` | Show overlay, do not dismiss | Closure not yet invoked |
| OV-12 | `testEyeType_correctContent` | Show overlay for `.eyes` | Title contains "eyes", icon is `eye.fill` |
| OV-13 | `testPostureType_correctContent` | Show overlay for `.posture` | Title contains "posture", icon is `figure.stand` |

---

### 4.4 Permission Flow (`SettingsViewModelTests` + manual)

| # | Test Name | Type | Scenario | Expected Result |
|---|-----------|------|----------|-----------------|
| PF-01 | `testPermissionGranted_schedulesReminders` | Unit | Auth returns true | `scheduleAll()` called |
| PF-02 | `testPermissionDenied_showsBanner` | Unit | Auth returns false | `showPermissionBanner == true` |
| PF-03 | `testPermissionDenied_noScheduling` | Unit | Auth returns false | `addedRequests.isEmpty` |
| PF-04 | `testPermissionDeniedThenGranted_schedulesOnReturn` | Unit | Denial → grant via viewDidAppear | `scheduleAll()` called after re-check |
| PF-05 | Permission granted — end-to-end | Manual | Grant on first launch | Background notifications fire at correct intervals |
| PF-06 | Permission denied — foreground mode | Manual | Deny on first launch | Banner visible; app works while open |
| PF-07 | Denied → Settings → Grant → return | Manual | Follow Open Settings flow | Banner disappears; background reminders resume |

---

### 4.5 App Lifecycle (`AppLifecycleTests` + manual)

| # | Test Name | Type | Scenario | Expected Result |
|---|-----------|------|----------|-----------------|
| LC-01 | `testBackground_doesNotCancelNotifications` | Unit | App goes to background | Scheduled requests remain in mock |
| LC-02 | `testForeground_recheckPermission` | Unit | `sceneDidBecomeActive` called | Permission re-checked; re-schedules if needed |
| LC-03 | Force-quit recovery | Manual | Force-quit; wait 20 min | Notification fires; tapping opens app and shows overlay |
| LC-04 | Background → foreground mid-countdown | Manual | App backgrounds, returns | Countdown continues from correct position |
| LC-05 | Fresh install → background immediately | Manual | Launch, close app in < 5s | Notifications still fire at scheduled time |

---

### 4.6 Edge Cases

| # | Test Name | Type | Scenario | Expected Result |
|---|-----------|------|----------|-----------------|
| EC-01 | `testBothSameInterval_queued` | Unit | Eyes and posture both set to 20 min | Overlays appear sequentially with 2s gap |
| EC-02 | `testSettingsChangeDuringOverlay_appliesAfterDismiss` | Unit | Settings changed while overlay visible | New interval used for next schedule after dismiss |
| EC-03 | `testSettingsChangeDuringOverlay_noMidCycleCrash` | Unit | Settings changed while overlay visible | No crash; overlay completes normally |
| EC-04 | Low Power Mode — notifications only | Manual | Enable Low Power Mode | Foreground timer suspended; notifications still fire |
| EC-05 | Low Power Mode — overlay animations | Manual | Enable Reduce Motion + Low Power | Overlay appears without slide animation |
| EC-06 | `testMinimumInterval_10min` | Unit | Set interval to minimum (10 min) | Trigger = 600s, no underflow |
| EC-07 | `testMaximumInterval_60min` | Unit | Set interval to maximum (60 min) | Trigger = 3600s, no overflow |
| EC-08 | `testBreakDuration_zero_autoDismissImmediate` | Unit | Break duration = 0s | Overlay calls dismiss immediately |

---

## 5. Device Matrix

| Device | Form Factor | iOS Version | Why |
|--------|------------|-------------|-----|
| **iPhone SE (3rd gen)** | 4.7" small screen | iOS 16.0 (min target) | Smallest supported device; tests compact layout, small overlay |
| **iPhone 15 Pro** | 6.1" standard | iOS 17.x | Primary development target; Dynamic Island, ProMotion 120Hz |
| **iPad Pro 12.9" (M2)** | 12.9" large | iOS 16.0+ | Tests overlay on split view, full-screen coverage on large display |

### Device-Specific Test Focus

**iPhone SE:**
- Settings rows don't truncate on small screen
- Overlay dismiss button (44pt tap target) accessible with one thumb
- Picker labels don't wrap or clip

**iPhone 15 Pro:**
- Baseline for all test scenarios
- Overlay doesn't clip into Dynamic Island
- ProMotion: countdown ring animation is smooth at 120Hz

**iPad Pro:**
- Overlay covers full window in all multitasking modes (Split View, Slide Over — see ARCHITECTURE.md §5.2)
- Settings screen doesn't leave large empty whitespace at wide layout
- VoiceOver rotor works correctly with expanded rows

---

## 6. Accessibility Test Checklist

Run this checklist manually before every release candidate.

### 6.1 VoiceOver Navigation

- [ ] **Settings Screen:** VoiceOver reads "Enable Reminders, toggle, on/off" for master switch
- [ ] **Eye Breaks row:** Reads "Eye Breaks, Every 20 min, 20 s break, collapsed" (or expanded)
- [ ] **Posture Checks row:** Reads "Posture Checks, Every 30 min, 10 s break, collapsed"
- [ ] **Pickers (expanded):** "Remind me every, 20 minutes, selected" — swiping changes read value
- [ ] **Permission banner:** VoiceOver reads full warning text + announces "Open Settings button"
- [ ] **Overlay appear:** Focus jumps to overlay when it appears (`accessibilityViewIsModal = true`)
- [ ] **Overlay dismiss button:** Reads "Dismiss reminder, button. Double tap to close"
- [ ] **Overlay countdown:** VoiceOver announces "15 seconds remaining" every 5 seconds
- [ ] **Overlay auto-dismiss:** VoiceOver says something when overlay disappears (e.g., focus returns to underlying app)

### 6.2 Dynamic Type — 200%

- [ ] Settings screen: All text visible and unclipped at AX5 (200%+)
- [ ] Reminder row subtitles: Text wraps gracefully, doesn't truncate
- [ ] Picker labels: "Remind me every" label fully visible
- [ ] Overlay title: "Time to rest your eyes" fully visible at large scale
- [ ] Countdown number: Still readable at 200% (64pt becomes ~128pt)
- [ ] Dismiss button (×): Not obscured by large text

### 6.3 Reduce Motion

- [ ] Overlay appear: No slide animation — appears with cross-fade instead
- [ ] Overlay dismiss (manual): No slide animation — fades out
- [ ] Overlay dismiss (auto): Already fade-out; no change needed
- [ ] Settings row expand: No spring animation — instant or subtle fade
- [ ] Countdown ring: Animated progress ring replaced by static number display if Reduce Motion is on (or ring animates non-continuously)

### 6.4 High Contrast / Increase Contrast

- [ ] Settings background and text: Sufficient contrast ratio (WCAG AA — 4.5:1 minimum)
- [ ] Reminder row icons: High contrast mode renders with increased stroke weight
- [ ] Toggle: On/off state clearly distinguishable without color alone
- [ ] Overlay background: Blur is dark enough for text legibility
- [ ] Countdown ring: Thicker stroke in high contrast (as specified in UX_FLOWS.md)
- [ ] Overlay title text: White on dark blur has ≥ 4.5:1 ratio

### 6.5 Button Accessibility Sizing

- [ ] Dismiss (×) button: Minimum 44×44pt tap target (verified in UI test or visual inspection)
- [ ] Pickers: Item rows at least 44pt tall
- [ ] Settings toggle: Tap area ≥ 44pt height

---

## 7. Bug Triage Priorities

### P0 — Blocker (Fix before any release)

> **Definition:** Core functionality broken; no workaround. Crash or data loss.

- App crashes on launch
- Notifications never fire (scheduling logic broken)
- Overlay never appears on notification receipt
- Settings not persisted — all values reset to default on relaunch
- Crash when granting/denying notification permission
- Crash when dismissing overlay
- Overlay appears but cannot be dismissed (user is stuck)
- Snooze schedules infinite loop of notifications

### P1 — Major (Fix before App Store submission)

> **Definition:** Significant impairment of user experience; workaround exists but is painful.

- Permission banner does not appear when permission is denied
- "Open Settings" deeplink does not open iOS Settings
- Settings changes not applied to future notifications (reschedule broken)
- Overlay shows wrong type (eyes instead of posture, or vice versa)
- Countdown does not reach 0 (timer drift > 1s over a 60s countdown)
- Second overlay in queue never appears (queue logic broken)
- Force-quit causes notifications to stop firing
- VoiceOver completely non-functional on any screen
- Dynamic Type at 200% breaks layout severely (content obscured)

### P2 — Minor (Fix before App Store submission if possible; else in next update)

> **Definition:** Noticeable but tolerable impairment. User can work around it.

- Countdown animation is choppy (< 30 FPS consistently)
- Overlay slide-up animation wrong direction or wrong duration
- Permission banner appears on every launch instead of once per session
- Settings row expansion animation missing or janky
- Notification body text incorrect (wrong interval displayed)
- iPad overlay covers only part of screen in Split View (known limitation — document it)
- Auto-dismiss fires 1–2 seconds late

### P3 — Cosmetic (Fix in future sprint; low urgency)

> **Definition:** Visual imperfection with zero functional impact.

- Overlay background blur slightly too dark/light
- Font weight off by one level in settings rows
- Countdown ring start/end angle slightly off
- Icon color slightly off-brand (blue vs indigo)
- Settings navigation title slightly misaligned on iPad
- Lock screen notification body has minor grammar issue

---

## 8. Regression Strategy

### After Each Milestone

#### Milestone 1 → Milestone 2 (Core → Snooze / Lock Screen Actions)
Re-test everything in §4.2 (Notification Scheduling). Snooze introduces new scheduling paths — verify:
- Existing repeating notifications unaffected when snooze is active
- Snooze one-time notifications are cleaned up after firing
- Max snooze cap (5/day per ARCHITECTURE.md §5.4) enforced

#### Milestone 2 → Milestone 3 (Snooze → Onboarding / Welcome Banner)
Re-test §4.4 (Permission Flow). Onboarding screen changes when notification permission is requested — verify:
- First-launch flow now shows onboarding screen before permission prompt
- No regression: permission grant/denial/recovery still works
- `UserDefaults.hasSeenWelcome` key doesn't conflict with settings keys

#### Milestone 3 → App Store Submission
Full regression pass: run all unit tests, all UI tests, and full manual checklist for all 3 devices in device matrix. Pay special attention to:
- iOS 16.0 deployment target (test on SE with iOS 16 if possible)
- Accessibility checklist §6 fully checked
- All P0 and P1 bugs resolved

### Automated Regression Gate (CI)

Every pull request into `main` must pass:
1. `EyePostureReminderTests` — all unit tests green
2. Code coverage ≥ 80% for Models + Services + ViewModels
3. `EyePostureReminderUITests` — settings flow + overlay dismissal
4. Build succeeds for iOS Simulator (iPhone 15, iOS 17)

Reference CI config: `ARCHITECTURE.md §6.2`

### High-Risk Change Triggers

Re-run the **full manual test checklist** whenever any of these files change:

| Changed File | Re-test Focus |
|---|---|
| `ReminderScheduler.swift` | NS-01 through NS-15, LC-01, LC-02 |
| `OverlayManager.swift` | OV-01 through OV-13, EC-01–EC-03 |
| `SettingsStore.swift` | SP-01 through SP-13, PF-01 through PF-04 |
| `SettingsViewModel.swift` | SP-06–SP-09, PF-01–PF-04 |
| `OverlayView.swift` | VoiceOver checklist §6.1, Reduce Motion §6.3 |
| `AppDelegate.swift` | LC-03–LC-05, PF-05–PF-07 |

---

## 9. Test File Map

```
EyePostureReminderTests/
├── Mocks/
│   ├── MockNotificationScheduler.swift   (§3.1)
│   ├── MockOverlayPresenter.swift        (§3.2)
│   ├── MockAudioSession.swift            (§3.3)
│   └── MockUserDefaults.swift            (§3.4)
├── Models/
│   └── SettingsStoreTests.swift          (§4.1 — SP-01 to SP-13)
├── Services/
│   ├── ReminderSchedulerTests.swift      (§4.2 — NS-01 to NS-15)
│   └── OverlayManagerTests.swift         (§4.3 — OV-01 to OV-13)
└── ViewModels/
    └── SettingsViewModelTests.swift      (§4.4 — PF-01 to PF-04)

EyePostureReminderUITests/
├── SettingsFlowTests.swift               (§4.1 save/load via UI)
└── OverlayDismissalTests.swift           (§4.3 dismiss button, swipe)
```

---

*Written by Livingston — "If you didn't test it, it doesn't work. Even if it looks like it works."*
