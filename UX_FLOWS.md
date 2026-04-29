# kshana — UX Flows & Interaction Design

> **Author:** Reuben, Product Designer  
> **Date:** 2026-04-24  
> **Purpose:** Complete user experience design — flows, principles, screen inventory, and interaction models

---

## 1. Design Principles

These principles guide every UX decision in the app:

### 1.1 **Interruptions Should Feel Helpful, Not Annoying**
Every break exists to improve the user's wellbeing. The break screen should feel like a gentle nudge from a caring friend, not a jarring interruption. Calm visual design, user choice, and immediate dismissibility all support this feeling.

### 1.2 **Friction is the Enemy of Habit Formation**
The app must fade into the background of the user's life. Setup should take seconds, not minutes. No mandatory onboarding tours. No confusing settings. The user should forget the app is running — until it helpfully reminds them to take a break.

### 1.3 **Respect User Autonomy**
The user chooses which apps or categories to monitor. They set the timing. They can disable at any time. The app is transparent: kshana does not read messages, content, or report activity beyond what's needed to suggest breaks.

### 1.4 **Battery Life is a Feature**
Users shouldn't worry that enabling this app will drain their battery. The implementation leverages iOS's native scheduling APIs and system-managed interruption to minimize CPU and memory usage. The UX should reflect this lightness — simple, fast, efficient.

### 1.5 **Accessibility is Not Optional**
Every screen and interaction must work perfectly with VoiceOver, Dynamic Type, and Reduce Motion. Designing for accessibility improves the experience for everyone.

---

## 2. Complete User Flows

### 2.1 First Launch → Onboarding → Permissions → Home Screen

The app uses a 4-screen onboarding flow (`OnboardingView`) shown once on first launch. `ContentView` checks the `hasSeenOnboarding` flag in `@AppStorage` and routes to either `OnboardingView` or `HomeView`.

**Current reality:** Local reminder alerts are a fallback. The core future promise is Screen Time Shield-based interruption over selected apps/categories once Apple's entitlement is approved.

```
User taps app icon (first time)
    │
    ▼
Launch Screen (standard iOS animation, < 1 second)
    │
    ▼
ContentView checks @AppStorage("hasSeenOnboarding")
    │
    ├─ false (first launch)
    │      │
    │      ▼
    │  ┌─────────────────────────────────────────────┐
    │  │  SCREEN 1 — Welcome (OnboardingWelcomeView) │
    │  │                                              │
    │  │  Illustration: eye + figure SF Symbols       │
    │  │  Headline: "Welcome to kshana"               │
    │  │  Subheadline: "Healthy app breaks,          │
    │  │               on your terms"                 │
    │  │  Body: "Gentle nudges to rest your eyes      │
    │  │  and check your posture. Choose which        │
    │  │  apps get break screens. You're in control." │
    │  │                                              │
    │  │  [ Next → ]  (borderedProminent, blue)       │
    │  │  Page dots: ● ○ ○ ○                          │
    │  └─────────────────────────────────────────────┘
    │      │
    │      ▼  User taps "Next" (or swipes left)
    │
    │  ┌──────────────────────────────────────────────────┐
    │  │  SCREEN 2 — App Break Access (Pre-Permission)    │
    │  │                                                   │
    │  │  Headline: "How does kshana work?"                │
    │  │  Body: "kshana monitors which apps you use        │
    │  │  (like Safari or social media) and gently         │
    │  │  suggests breaks. Think of it as a friendly       │
    │  │  reminder card—not a blocker.                     │
    │  │                                                   │
    │  │  You choose which apps to monitor, when breaks    │
    │  │  happen, and can disable anytime.                 │
    │  │                                                   │
    │  │  kshana does not:                                 │
    │  │  • Read messages or see content                   │
    │  │  • Report your activity anywhere                  │
    │  │  • Require an account"                            │
    │  │                                                   │
    │  │  [ Next → ]  (borderedProminent, blue)            │
    │  │  "Maybe Later" skip link                          │
    │  │  Page dots: ○ ● ○ ○                               │
    │  └──────────────────────────────────────────────────┘
    │      │
    │      ├─ User taps "Next"
    │      │      │
    │      │      ▼  (advances to Screen 3)
    │      │
    │      └─ User taps "Maybe Later"
    │             │
    │             ▼  (skips to Screen 4 Setup Preview)
    │
    │  ┌──────────────────────────────────────────────────┐
    │  │  SCREEN 3 — App Break Access Permission          │
    │  │  (OnboardingScreenTimePermissionView)             │
    │  │                                                   │
    │  │  Headline: "Permission to suggest breaks"        │
    │  │  Body: "kshana needs access to see which apps     │
    │  │  you're using so it can suggest breaks at the     │
    │  │  right time.                                      │
    │  │                                                   │
    │  │  Your privacy matters. This does not give kshana  │
    │  │  access to your messages, photos, or any other    │
    │  │  content."                                        │
    │  │                                                   │
    │  │  [ Grant App Break Access ]  ← triggers          │
    │  │    system Screen Time/Family Controls prompt      │
    │  │  "Not now" skip link  ← advances without          │
    │  │                          requesting permission    │
    │  │  Page dots: ○ ○ ● ○                               │
    │  │                                                   │
    │  │  ⚠ Horizontal swipe is blocked on this screen     │
    │  │    (highPriorityGesture prevents accidental skip)  │
    │  └──────────────────────────────────────────────────┘
    │      │
    │      ├─ User taps "Grant App Break Access"
    │      │      │
    │      │      ▼
    │      │  System permission prompt appears:
    │      │  "kshana" requests access to Screen Time
    │      │  [Allow] [Don't Allow]
    │      │      │
    │      │      ├─ User taps "Allow" → permission granted ✓
    │      │      └─ User taps "Don't Allow" → permission denied
    │      │      │
    │      │      ▼  (either way, advances to Screen 4)
    │      │
    │      └─ User taps "Not now"
    │             │
    │             ▼  (advances to Screen 4 without prompting)
    │
    │  ┌──────────────────────────────────────────────────┐
    │  │  SCREEN 4 — Setup Preview (OnboardingSetupView)  │
    │  │                                                   │
    │  │  Headline: "You're all set"                       │
    │  │  Body: "kshana will help you build better         │
    │  │  habits. Your breaks, your timing, your control." │
    │  │                                                   │
    │  │  Default config preview:                           │
    │  │    • Eye Breaks: every 20 min                     │
    │  │    • Posture Checks: every 30 min                 │
    │  │    • Fallback local alerts when Screen Time       │
    │  │      access is unavailable                        │
    │  │                                                   │
    │  │  [ Get Started ]    ← sets hasSeenOnboarding,     │
    │  │                       transitions to HomeView     │
    │  │  "Customize Settings" ← sets hasSeenOnboarding    │
    │  │                         + openSettingsOnLaunch,    │
    │  │                         opens Settings on arrival  │
    │  │  Page dots: ○ ○ ○ ●                               │
    │  └──────────────────────────────────────────────────┘
    │      │
    │      ▼
    │  hasSeenOnboarding = true (written to UserDefaults)
    │  ContentView transitions to HomeView (opacity crossfade, 0.4s)
    │  If permission granted, app begins monitoring selected apps
    │  If permission denied, fallback to local alerts when app runs
    │
    └─ true (returning user)
           │
           ▼
       HomeView loads directly (no onboarding)
```

**Key UX decisions:**
- **4-screen onboarding educates before asking.** Screen 1 explains value. Screen 2 educates on how kshana works (privacy-first). Screen 3 requests the Screen Time access permission. This order builds confidence.
- **Pre-permission education screen (Screen 2).** Many users find the system Screen Time/Family Controls prompt scary. A calm pre-screen explains what kshana does (and doesn't do) in plain language, reducing anxiety.
- **Permission screen blocks accidental swipe-past.** A `highPriorityGesture` prevents horizontal swiping on Screen 3, ensuring the user makes a deliberate choice.
- **"Maybe Later" / "Not now" paths are always available.** The user can skip permissions and still proceed. A banner on the Home/Settings screen later offers recovery (see Section 2.4). The app works in degraded mode with local alerts as fallback.
- **Defaults are pre-configured.** Screen 4 previews the defaults so the user knows what to expect. No mandatory customization.
- **"Customize Settings" path.** Users who want to adjust before starting can tap the secondary CTA, which opens Settings immediately after onboarding.
- **Onboarding is shown exactly once.** The `hasSeenOnboarding` flag is only set on explicit completion ("Get Started" or "Customize"). Force-quitting mid-onboarding means it shows again next launch.
- **Graceful degradation.** If permission is denied, the app works in foreground-only mode with local alerts. A persistent banner on the Home/Settings screen provides a path to fix (see Section 2.4).

---

### 2.2 Normal Usage Loop: App Background → Notification → Overlay → Dismiss → Repeat

```
App is running in background
Reminders are scheduled via UNUserNotificationCenter
    │
    ▼
[20 minutes elapse]
    │
    ▼
iOS fires Eye Reminder notification
    │
    ├─ Device is UNLOCKED, app in foreground or background
    │      │
    │      ▼
    │  App receives notification
    │  OverlayManager.show() called immediately
    │  (notification does NOT appear as banner)
    │      │
    │      ▼
    │  Full-screen overlay slides up from bottom (0.3s ease-out animation)
    │  User sees:
    │    • Eye icon (SF Symbol: eye.fill)
    │    • "Time to rest your eyes"
    │    • Circular countdown: "15" → "14" → "13"...
    │    • Dismiss button (×) in top-right
    │    • Settings button (⚙️) in top-left (opens Settings screen)
    │      │
    │      ├─ User taps × or swipes UP
    │      │      │
    │      │      ▼
    │      │  Overlay slides up and off-screen (0.2s ease-in)
    │      │  Overlay window removed from hierarchy
    │      │  User returns to what they were doing
    │      │  Next reminder already scheduled (repeat: false; ScreenTimeTracker re-arms after each break)
    │      │  [No snooze sheet — snooze controls live in Settings only]
    │      │
    │      ├─ User taps ⚙️
    │      │      │
    │      │      ▼
    │      │  Overlay dismissed
    │      │  Settings screen opens (snooze controls accessible here)
    │      │
    │      └─ User does nothing
    │             │
    │             ▼
    │         Countdown reaches 0
    │         Device vibrates (haptic feedback, Phase 1)
    │         Overlay auto-dismisses (fade-out, 0.3s)
    │         Next reminder already scheduled
    │
    └─ Device is LOCKED
           │
           ▼
       Notification appears on Lock Screen:
       "👁 Eye Break"
       "Look 20 ft away for 20 seconds."
           │
           ├─ User ignores notification
           │      │
           │      ▼
           │  Notification remains in Notification Centre
           │  (can be cleared later)
           │  Next reminder still scheduled
           │
           └─ User taps notification
                  │
                  ▼
              Device unlocks (Face ID / Touch ID)
              App opens
              OverlayManager.show() called
              Overlay appears (same flow as above)
```

**Key UX decisions:**
- **Overlay appears immediately** when app is foreground/background and device is unlocked. No notification banner clutter.
- **Lock screen notifications are standard.** This is expected iOS behaviour — users understand this pattern.
- **Auto-dismiss is gentle.** No jarring sounds or haptics on dismiss. The overlay simply fades away.
- **Next reminder is already scheduled.** User never has to think about whether the app is "still running."

---

### 2.3 Settings Adjustment Flow

```
User opens app (taps icon on Home Screen)
    │
    ▼
Settings Screen loads
Current values displayed:
  • Reminders toggle: ON
  • Eyes: every 20 min, 20 s break
  • Posture: every 30 min, 10 s break
    │
    ▼
User taps "Eyes" row
    │
    ▼
Row expands inline (smooth animation, 0.2s)
Shows two pickers:
  • "Remind me every" [10 min | 20 min ✓ | 30 min | 45 min | 60 min]
  • "Break duration" [10 s | 20 s ✓ | 30 s | 60 s]
    │
    ▼
User taps "30 min" in first picker
    │
    ▼
Picker updates immediately
SettingsStore.save() called
ReminderScheduler.reschedule() triggered
    │
    ▼
All pending notifications cancelled
New notifications scheduled with updated interval (30 min)
    │
    ▼
No confirmation dialog
No "Save" button required
Changes are immediate
    │
    ▼
User closes app (swipes up)
    │
    ▼
App enters background
Reminders continue working with new interval
```

**Key UX decisions:**
- **Inline expansion.** No modal sheets or navigation stack. Settings stay visible.
- **Immediate persistence.** No "Save" button cognitive load. Changes apply instantly.
- **No confirmation spam.** Users trust that their changes stuck. (Advanced: could show a subtle toast "Reminders updated" for 1s, but not required.)

---

### 2.4 Permission Denied Recovery Flow

```
User opens app
Permission was denied during first launch or in iOS Settings
    │
    ▼
Settings Screen displays
Banner at top (yellow background, system-style alert):
"⚠️ Notifications disabled. Reminders will only work when app is open."
[Open Settings] button
    │
    ├─ User taps "Open Settings"
    │      │
    │      ▼
    │  Deep link to iOS Settings > kshana > Notifications
    │  User toggles "Allow Notifications" ON
    │      │
    │      ▼
    │  User returns to app (swipes up, taps app icon)
    │      │
    │      ▼
    │  App checks permission status in viewDidAppear
    │  Permission now granted
    │  Banner disappears
    │  ReminderScheduler.scheduleAll() called
    │  Reminders now work in background
    │
    └─ User ignores banner
           │
           ▼
       Banner remains visible (not dismissible)
       App continues in foreground-only mode
       User can still adjust settings
       Foreground timer (DispatchQueue.asyncAfter) runs while app is active
```

**Key UX decisions:**
- **Single, persistent banner.** Not a modal blocker. User can still use the app.
- **Clear call-to-action.** "Open Settings" is a direct link — no guessing.
- **No repeated prompts.** Banner appears once per session, doesn't nag on every screen load.
- **Graceful fallback.** Even without permissions, the app provides value (foreground reminders).

---

### 2.5 Force-Quit Recovery Flow

```
User force-quits the app (swipes up in App Switcher)
    │
    ▼
App process terminates
BUT: scheduled notifications remain in iOS Notification Centre
(UNUserNotificationCenter persists independently of app lifecycle)
    │
    ▼
[20 minutes elapse]
    │
    ▼
iOS fires Eye Reminder notification
Notification appears on Lock Screen / Notification Centre:
"👁 Eye Break"
"Look 20 ft away for 20 seconds."
    │
    ▼
User taps notification
    │
    ▼
App launches (cold start)
UNUserNotificationCenterDelegate.didReceive() called
OverlayManager.show() triggered
    │
    ▼
Overlay appears normally
User sees countdown and can dismiss
    │
    ▼
Overlay dismissed
App remains open in background
Next notification already scheduled (repeat: false; ScreenTimeTracker re-arms after each break)
All reminders continue normally
```

**Key UX decisions:**
- **Force-quit doesn't break the app.** Notifications persist thanks to iOS architecture.
- **User never knows the app was killed.** Experience is seamless.
- **No "Please don't force-quit!" nag screens.** The app handles this gracefully without user education.

---

## 3. Screen Inventory

### 3.1 Settings Screen (Primary)

**Purpose:** Configure reminder intervals, durations, and toggle all reminders on/off.

**Key Elements:**
- Navigation title: "Reminders"
- Master toggle: "Enable Reminders" (ON / OFF)
- List of reminder types (2 rows):
  - **Eyes row:**
    - Icon: 👁 or SF Symbol `eye.fill`
    - Label: "Eye Breaks"
    - Subtitle: "Every 20 min, 20 s break" (dynamically updates)
    - Chevron (tap to expand)
  - **Posture row:**
    - Icon: 🧍 or SF Symbol `figure.stand`
    - Label: "Posture Checks"
    - Subtitle: "Every 30 min, 10 s break"
    - Chevron (tap to expand)
- When expanded:
  - Two inline pickers/menus:
    - "Remind me every" [10 min, 20 min, 30 min, 45 min, 60 min]
    - "Break duration" [10 s, 20 s, 30 s, 60 s]
- **Per-type enable toggles** (Phase 1): Each reminder row includes an inline ON/OFF toggle, independent of the master toggle
- **Snooze controls section** (Phase 1):
  - Label: "Pause Reminders"
  - Three full-width buttons:
    - [5 minutes]
    - [1 hour]
    - [Rest of day] — **orange warning tint** (consequential action; prevents casual selection)
  - Active snooze shows remaining time and a "Cancel snooze" link
- **Version display** (bottom of screen): App version string (e.g., "v1.0.0 (42)")
- **Conditional banner** (top of screen, only if notifications denied):
  - "⚠️ Notifications disabled. Reminders will only work when app is open."
  - [Open Settings] button

**States:**
- Default (both rows collapsed)
- Eyes expanded
- Posture expanded
- Both collapsed, banner visible (permission denied)
- Snooze active (snooze controls show remaining time + cancel)

**Accessibility:**
- VoiceOver labels for toggle, pickers, expand/collapse
- Dynamic Type support (all text scales)
- High contrast mode support

---

### 3.2 Overlay Screen (Modal, Fullscreen)

**Purpose:** Display the active reminder break with countdown and allow immediate dismissal.

**Key Elements:**
- **Background:** Semi-opaque blur (`.ultraThinMaterial` in SwiftUI, or `UIBlurEffect.Style.systemUltraThinMaterial` in UIKit)
- **Icon:** Large (80pt) SF Symbol centered:
  - Eye break: `eye.fill` in blue
  - Posture break: `figure.stand` in green
- **Title:** Bold, 28pt
  - "Time to rest your eyes" or "Time to check your posture"
- **Circular countdown ring:**
  - Outer ring fills/empties as time elapses (Core Graphics or SwiftUI Circle stroke)
  - Center displays seconds remaining: "15" → "14" → "13"...
  - Font: 64pt, monospace
- **Dismiss button (×):**
  - Top-right corner (standard iOS position)
  - "×" symbol (SF Symbol `xmark.circle.fill`)
  - 44pt tap target (meets accessibility minimum)
  - Label: "Dismiss reminder" (for VoiceOver)
- **Settings button (⚙️):**
  - Top-left corner (mirrors dismiss button)
  - SF Symbol `gearshape.fill`
  - 44pt tap target
  - Label: "Open Settings" (for VoiceOver)
  - On tap: dismisses overlay and opens Settings screen (snooze controls accessible there)
- **Swipe-UP gesture:**
  - Pan gesture recognizer on full overlay surface
  - Overlay follows finger upward; on release, slides up and off-screen (0.2s ease-in)
  - Dismisses overlay (same outcome as tapping ×)

**Animations:**
- **Appear:** Slide up from bottom, 0.3s ease-out
- **Dismiss (manual):** Slide up and off the top of the screen, 0.2s ease-in
- **Dismiss (auto):** Vibrate once (Phase 1), then fade out, 0.3s linear
- **Countdown ring:** Smooth progress animation (60 FPS, using CABasicAnimation or SwiftUI `.animation()`)

**States:**
- Eyes reminder (blue theme)
- Posture reminder (green theme)

**Accessibility:**
- `accessibilityViewIsModal = true` (traps VoiceOver focus within overlay)
- Countdown announces remaining time every 5 seconds
- Dismiss button has accessible label and hint ("Dismiss reminder", "Double tap to close")

---

### 3.3 Permission Prompt (System, During Onboarding)

**Purpose:** Request notification permission (shown by iOS, not custom UI).

**Content:**
- Title: "kshana Would Like to Send You Notifications"
- Body: (standard iOS text)
- Buttons: [Don't Allow] [Allow]

**Trigger:** User taps "Enable Notifications" on Onboarding Screen 2 (`OnboardingPermissionView`). The prompt is **not** automatic — it only appears after the user has seen the Welcome screen and the permission education screen.

**Post-interaction:**
- User allows → advances to Setup screen (Screen 3); reminders scheduled after onboarding completion
- User denies → advances to Setup screen (Screen 3); banner appears on Home/Settings screen after onboarding
- User taps "Not now" → advances to Setup screen without triggering the system prompt at all

---

### 3.4 Lock Screen Notification (System)

**Purpose:** Display reminder when device is locked.

**Content:**
- **Eye Break:**
  - Title: "👁 Eye Break"
  - Body: "Look 20 ft away for 20 seconds."
- **Posture Check:**
  - Title: "🧍 Posture Check"
  - Body: "Sit up straight and roll your shoulders."

**Actions (Phase 2):**
- [Done] — dismisses notification
- [Snooze 5 min] — reschedules for 5 minutes later

---

## 4. Overlay Interaction Model

### 4.1 Dismissal Methods

**Option 1: Tap dismiss button (×)**
- User taps the top-right × button
- Overlay slides down with 0.2s ease-in animation
- UIWindow is removed from hierarchy
- User returns to previous app state (e.g., Safari, Messages)

**Option 2: Swipe UP**
- User swipes up from anywhere on the overlay (pan gesture, minimum 50pt vertical movement)
- Overlay follows finger upward during drag
- Release → overlay completes slide-up and exits off the top of the screen
- Same outcome as tap dismiss

**Option 3: Auto-dismiss (timer elapses)**
- Countdown reaches 0
- Overlay fades out with 0.3s linear animation (no slide)
- UIWindow removed
- User returns to previous app state

**Decision rationale:**
- **Three dismissal methods** cover different user preferences and contexts:
  - Tap ×: Precise, intentional dismiss
  - Tap ⚙️: Opens Settings for snooze (deliberate path to snooze controls)
  - Swipe UP: Natural "flick away" gesture
  - Auto-dismiss: Zero interaction required (users who follow the break)
- **Snooze is not on the overlay.** Users who want to snooze tap ⚙️ → Settings. This prevents accidental snooze and keeps the break screen calm.

### 4.2 Animations

**Appear:**
- Overlay window is created and added to key window hierarchy at `.alert + 1` level
- Initial position: off-screen (y = screen height)
- Animates to y = 0 over 0.3s with `UIView.AnimationOptions.curveEaseOut`

**Dismiss (manual — × tap or swipe UP):**
- User taps × or completes swipe-UP gesture
- Overlay animates to y = -(screen height) over 0.2s with `.curveEaseIn` (exits through top)
- Window is hidden and removed from hierarchy on completion
- No haptic feedback (dismissal is user-initiated, no need to confirm)

**Dismiss (auto — timer reaches 0):**
- Countdown reaches 0
- Device vibrates: `.notificationOccurred(.success)` (Phase 1 — indicates break complete)
- Overlay fades out (alpha: 1.0 → 0.0) over 0.3s with `.curveLinear`
- Window is hidden and removed on completion

**Media pause (Phase 2, opt-in, default OFF):**
- Optional: pause active media playback when overlay appears (user preference in Settings)
- Resume media on any dismissal path

### 4.3 Countdown Behaviour

**Timer implementation:**
- `DispatchQueue.main.asyncAfter` with 1-second intervals
- Updates countdown label each second: 15 → 14 → 13 → ... → 1 → 0
- Circular progress ring animates in sync (e.g., `strokeEnd` from 1.0 → 0.0)
- On reaching 0: device vibrates once (`.notificationOccurred(.success)`) before fade-out (Phase 1)

**User experience:**
- Countdown is **not** a blocker — user can dismiss at any time
- Reaching 0 simply means "suggested break duration complete"
- No guilt or pressure if user dismisses early

**Accessibility:**
- VoiceOver announces countdown every 5 seconds ("15 seconds remaining")
- Countdown label uses monospace font for stable layout (digits don't shift width)
- High contrast mode uses thicker stroke for progress ring

### 4.4 Edge Case: Multiple Overlays

**Scenario:** Eye reminder and posture reminder fire within seconds of each other (unlikely but possible if intervals are manually set to collide).

**Handling:**
```
First reminder fires
OverlayManager.show(type: .eyes)
Overlay window created, eye break displayed
    │
    ▼
[5 seconds later]
Second reminder fires (posture)
OverlayManager checks: is an overlay currently visible?
    │
    ├─ YES
    │      │
    │      ▼
    │  Queue second reminder internally (stored in OverlayManager)
    │  Do NOT create second overlay window
    │      │
    │      ▼
    │  User dismisses first overlay (eyes)
    │      │
    │      ▼
    │  OverlayManager.dismiss() called
    │  Check queue: is there a pending reminder?
    │      │
    │      └─ YES
    │             │
    │             ▼
    │         Wait 2 seconds (breathing room)
    │         OverlayManager.show(type: .posture)
    │         Second overlay appears
    │
    └─ NO
           │
           ▼
       Show second overlay normally
```

**UX rationale:**
- **Never stack overlays.** This would be confusing and block the entire screen.
- **Queue with delay.** Give user a moment to return to their previous task before showing the second reminder.
- **Transparent to user.** They see two reminders in sequence, not simultaneously.

---

## 5. Onboarding Flow

### 5.1 Philosophy: Educate, Then Ask

**Core belief:** Even a simple app benefits from a brief, warm introduction — especially when a system permission is required.

**Approach:**
- **3-screen onboarding flow** (Welcome → Permissions → Setup) shown exactly once on first launch.
- **Educate before asking.** The permission request comes on Screen 2, after the user understands the app's value. This produces higher grant rates than a cold prompt.
- **Preview defaults.** Screen 3 shows the default configuration so users feel confident before starting.
- **Two completion paths:** "Get Started" (use defaults) or "Customize Settings" (jump to Settings).
- **Swipe navigation** between screens via `TabView` with `PageTabViewStyle`. Page dots indicate progress.

### 5.2 First Launch Experience

**Goal:** User should be through onboarding in < 30 seconds.

**Flow:**
1. App icon tap → launch screen (< 1s)
2. Welcome screen establishes context and tone
3. Permission screen explains why notifications matter, then offers "Enable Notifications" or "Not now"
4. Setup screen previews default config (eye breaks every 20 min, posture checks every 30 min)
5. User taps "Get Started" or "Customize Settings"
6. `hasSeenOnboarding` flag set → ContentView crossfades to HomeView
7. Reminders are scheduled. Done.

**Implementation details:**
- `ContentView` checks `@AppStorage(hasSeenOnboarding)` to gate the flow
- `OnboardingView` uses a `TabView` with `PageTabViewStyle` for horizontal swipe between screens
- `OnboardingPermissionView` blocks accidental swipe-past with a `highPriorityGesture`
- `OnboardingSetupView` offers two CTAs: "Get Started" (defaults) and "Customize Settings" (opens Settings)
- Force-quitting mid-onboarding re-shows onboarding (flag only set on explicit completion)

### 5.3 What We're NOT Doing

❌ **No account creation or sign-in** (no backend, all local)
❌ **No upsell or "Pro" feature gates** (not in scope)
❌ **No feature tour or coach marks** (the 3 screens cover value, permission, and setup — nothing more)

### 5.4 Yin-Yang Logo Animation (Restful Grove Redesign)

The yin-yang logo is the app's primary brand mark, appearing on both `OnboardingView` (Welcome screen) and `HomeView`. It is a custom-drawn symbol using SwiftUI `Path`, not an SF Symbol.

**Visual Design:**
- Two interlocking teardrops forming a yin-yang circle
- Colors: Sage (`#2F6F5E` / `AppColor.primaryRest`) + Mint (`#EEF6F1` / `AppColor.surfaceTint`)
- Inner dots use the opposing color (Sage dot on Mint half, Mint dot on Sage half)

**Animation Sequence (when Reduce Motion is OFF):**

```
Logo appears (static, centered)
    │
    ▼
Phase 1 — Spin (one-time)
    360° rotation over 2 seconds
    Easing: deceleration curve (fast start → gentle stop)
    Purpose: draws attention on screen entry
    │
    ▼
Phase 2 — Breathing Pulse (infinite loop)
    Scale up slightly over 4 seconds (ease-in-out)
    Scale down to original size over 4 seconds (ease-in-out)
    Repeats indefinitely
    Purpose: conveys calm, living presence — mirrors breathing rhythm
```

**When Reduce Motion is ON:**
- Logo renders as a static image — no spin, no pulse
- Ensures WCAG AA compliance for motion-sensitive users

**Where it appears:**
| Screen | Placement | Behavior |
|---|---|---|
| `OnboardingView` (Welcome) | Above headline text | Full animation sequence on appear |
| `HomeView` | Header area | Full animation sequence on appear |

**Design rationale:**
- SwiftUI `Path` (not SF Symbols) gives full control over shape and color
- Sage/Mint palette chosen for Restful Grove's wellness aesthetic — calming, nature-inspired
- The spin → breathe transition mirrors "settle in, then relax" — the core app promise
- 10+ HTML prototype iterations refined timing and easing before final approval

---

## 6. Edge Case UX

### 6.1 Both Reminders Fire at the Same Time

**Scenario:** User sets both eye and posture reminders to the same interval (e.g., both every 20 min).

**UX:**
- Overlays appear sequentially (as described in Section 4.4)
- First reminder shows → user dismisses → 2s delay → second reminder shows
- No change to user — they see two separate breaks

**Future enhancement (Phase 3):**
- Detect overlapping intervals and offer "combined break" overlay:
  - "Time for a break!"
  - "Rest your eyes AND check your posture"
  - Single countdown (longer duration, e.g., 30s)

---

### 6.2 Device is Locked

**Scenario:** Reminder fires while device is locked.

**UX:**
- Notification appears on Lock Screen (standard iOS behaviour)
- User sees: "👁 Eye Break" / "🧍 Posture Check" with body text
- User can:
  - **Ignore** → notification remains in Notification Centre
  - **Tap** → device unlocks (Face ID / Touch ID) → app opens → overlay appears
  - **Clear** → notification dismissed, next reminder still scheduled

**No special handling required** — this is expected iOS behaviour.

---

### 6.3 Low Power Mode is Active

**Scenario:** User has Low Power Mode enabled in iOS Settings.

**Impact on app:**
- `UNUserNotificationCenter` **still delivers notifications normally**
- iOS may delay non-critical background tasks, but time-based notifications are unaffected
- Overlay animations run normally (iOS doesn't throttle UI animations in Low Power Mode)

**UX:**
- No visible change to the user
- App works identically

**Note:** If we add optional haptics (Phase 2), those may be suppressed in Low Power Mode — this is fine and expected.

---

### 6.4 User Hasn't Opened the App in Days

**Scenario:** User installed the app, enabled reminders, then never opened it again for a week.

**Expected behaviour:**
- Reminders continue firing in the background (Lock Screen notifications)
- User receives notification → taps → app opens (cold start) → overlay appears
- All settings persist via UserDefaults
- No data loss, no "re-onboarding"

**Potential issue (iOS limitation):**
- If the user has **many** unread notifications from the app, iOS may throttle further deliveries
- This is out of our control (iOS policy to prevent spam)

**UX mitigation (Phase 2):**
- App could detect "last opened > 7 days ago" and show a friendly banner:
  - "👋 Welcome back! Your reminders are still active."
  - No action required, just reassurance

---

### 6.5 User Disables One Reminder Type

**Scenario:** User turns off eye breaks but keeps posture checks enabled.

**Current implementation (from plan):**
- Settings has a master "Enable Reminders" toggle (all or nothing)

**UX gap identified:**
- No per-type enable/disable in current plan

**Recommendation:**
- Add a toggle to each reminder row in Settings:
  ```
  Eyes
    [Toggle] Enable eye breaks
    Remind me every: 20 min
    Break duration: 20 s
  ```
- `ReminderScheduler` checks per-type enabled state before scheduling
- This allows users to customize which reminders they want

**Status: Resolved — Phase 1.** Per-type enable/disable toggles are included in Phase 1. Each reminder row in Settings has an independent ON/OFF toggle. `ReminderScheduler` checks the per-type enabled state before scheduling. Both types can be toggled independently of the master toggle.

---

### 6.6 User Changes Interval While Overlay is Visible

**Scenario:** User is viewing the eye break overlay, dismisses it, opens Settings, and changes the interval.

**Expected behaviour:**
- Overlay is dismissed (window removed)
- User opens Settings (app now in foreground)
- User changes eye interval from 20 min → 30 min
- `ReminderScheduler.reschedule()` called immediately
- All pending notifications cancelled and re-added with new interval
- Next eye break will now be in 30 minutes from now (not from the previous dismissal)

**UX edge case:**
- If user expected "30 minutes from when I dismissed the overlay," they may be confused if the new schedule starts immediately

**Mitigation:**
- This is acceptable behaviour — changing settings resets the schedule
- No need for complex "preserve elapsed time" logic
- User can always manually dismiss and wait if they want to control timing

---

## 7. Experience Metrics

**How do we measure UX success?**

### 7.1 Primary Metrics (Qualitative)

Since this is a personal health app (likely no analytics backend in MVP), success is subjective:

**User feels:**
- ✅ "The app doesn't drain my battery"
- ✅ "I can dismiss reminders instantly when I'm in a meeting"
- ✅ "I've been taking more breaks since installing this"
- ✅ "I forgot the app was even installed — it just works"

### 7.2 Proxy Metrics (If Analytics are Added Later)

If we instrument the app with privacy-respecting analytics:

| Metric | Success Threshold | Why It Matters |
|---|---|---|
| **Permission grant rate** | > 70% | If users deny notifications, the app's value drops significantly |
| **Average dismissal time** | 3-8 seconds | Too fast = users aren't taking breaks; Too slow = overlay is annoying |
| **Auto-dismiss rate** | 40-60% | Indicates users are following the break (not dismissing immediately) |
| **Settings changes in first week** | 1-3 per user | Users customize to fit their workflow (good), but don't thrash (bad) |
| **Force-quit rate** | < 5% | High rate suggests users find the app intrusive |
| **Days between app opens** | 7-30 days | Users shouldn't need to open the app often — reminders work in background |

### 7.3 UX Failure Modes to Watch For

**Red flags that UX is failing:**
- 🚩 Users immediately turn off reminders after first launch
- 🚩 High uninstall rate in first 24 hours
- 🚩 Reviews mention "annoying," "can't dismiss," or "drains battery"
- 🚩 Users set intervals to maximum (60 min) — suggests defaults are too aggressive
- 🚩 Permission grant rate < 50% — onboarding isn't communicating value

---

## 8. Open UX Questions for Team

### 8.1 Per-Type Enable/Disable Toggles

**Status: Resolved — Phase 1.**

Each reminder type (eyes, posture) has its own independent ON/OFF toggle in Settings, in addition to the master toggle. This lets users disable one type while keeping the other active.

**Implemented design:**
- Each reminder row shows an inline toggle
- Toggling a type off cancels its scheduled notifications immediately
- Toggling on reschedules from now
- If both per-type toggles are OFF, master toggle visually reflects "nothing active" (no behaviour change required beyond UX clarity)

---

### 8.2 Snooze Controls (Resolved — Phase 1)

**Status: Resolved — Phase 1.**

Snooze controls are in the **Settings screen**, not on the overlay. This separates the calm break moment from the snooze decision.

**Implemented design (Settings screen “Pause Reminders” section):**
- [5 minutes] — standard style
- [1 hour] — standard style
- [Rest of day] — **orange warning tint** (consequential; prevents casual selection)

**Snooze access path:** Overlay → tap ⚙️ → Settings screen → snooze button. Two deliberate taps prevents accidental suppression.

**Lock screen notification action (Phase 2):** A "Snooze 5 min" notification action on the lock screen remains a Phase 2 enhancement.

---

### 8.3 Haptic Feedback on Timer Completion (Resolved — Phase 1)

**Status: Resolved — Phase 1.**

The device vibrates once when the countdown reaches 0 (`.notificationOccurred(.success)`). This signals "break complete" without interrupting users who dismissed early.

- **On appear:** No haptic (keep arrival gentle)
- **On auto-dismiss (timer = 0):** Single vibration — Phase 1, always on
- **On manual dismiss:** No haptic (user-initiated, no confirmation needed)

**Note:** A user-configurable haptic preference toggle may be added in Phase 2 if user feedback requests it. Default would be ON (matching Phase 1 behaviour).

---

### 8.4 Dark/Light Theme for Overlay

**Question:** Should the overlay background colour adapt to Light/Dark Mode, or always be neutral?

**Options:**
- **A) Adaptive** (different colours for light/dark) — matches system aesthetic
- **B) Always neutral** (same semi-opaque blur in both modes) — consistent experience

**Recommendation:** **Adaptive** (Option A). Use `.ultraThinMaterial` in SwiftUI, which automatically adapts to system theme. No extra work required.

---

## 9. Future Enhancements (Phase 3+)

These are outside the MVP scope but worth documenting:

### 9.1 Home Screen Widget
- Shows "Next break in X minutes"
- Provides quick glanceable value
- Requires WidgetKit integration

### 9.2 Apple Watch Glance
- Haptic tap on wrist when break is due
- Simplified countdown on watch face
- Requires watchOS companion app

### 9.3 Combined Breaks
- If both reminders fire within 2 minutes of each other, show a single "combined break" overlay
- Longer duration (sum of both break durations)
- Reduces interruption frequency

### 9.4 Smart Scheduling
- Detect when user is likely AFK (e.g., no device interaction for 10 min)
- Skip reminder or delay until user returns
- Requires Screen Time API or heuristics (complex)

### 9.5 Break Streak Tracking
- Show "You've taken 15 breaks this week!" on Settings Screen
- Gamification to encourage habit formation
- Requires analytics/persistence of completion events

---

## 10. Summary

This document defines the complete user experience for kshana. Key takeaways:

1. **Design is guided by 5 core principles** (helpful interruptions, low friction, user autonomy, battery efficiency, accessibility).
2. **User flows are detailed and cover all states** — from first launch to edge cases like force-quit recovery.
3. **The overlay interaction model balances flexibility and simplicity** — three dismissal methods, smooth animations, no stacking.
4. **Onboarding is a warm 3-screen handshake** — Welcome → Permissions → Setup. Educates before asking, previews defaults, then gets out of the way.
5. **Edge cases are handled gracefully** — locked device, Low Power Mode, overlapping reminders, permission denial.
6. **Success is measured by invisibility** — the best UX is when users forget the app exists until it helpfully reminds them.

**Next steps:**
- Design team (Reuben): Create visual mockups for Settings Screen and Overlay (Figma/Sketch)
- Development team: Use this doc as the UX spec during implementation
- QA: Test all flows, especially edge cases in Section 6

---

**Document version:** 1.2  
**Last updated:** 2026-04-25 (onboarding flow correction — Fixes #112)  
**Owner:** Reuben (Product Designer)

---

## Session Revision Log

> **Session date:** 2026-04-24  
> **Author:** Reuben (Product Designer)  
> **Summary:** Nine design decisions made this session; all reflected in sections above.

| # | Decision | Section(s) affected | Notes |
|---|---|---|---|
| 1 | **Overlay simplification** — Remove all snooze buttons. Overlay shows only × (dismiss) and ⚙️ (open Settings). | 2.2, 3.2, 4.1 | Prevents accidental snooze; keeps break screen calm |
| 2 | **15-second countdown** (was 20s) | 2.2, 3.2, 4.3 | Shorter default break duration |
| 3 | **Swipe UP to dismiss** (was swipe down) | 2.2, 3.2, 4.1, 4.2 | Overlay exits through top of screen; mirrors natural "flick away" gesture |
| 4 | **Vibrate on timer completion — Phase 1** (was Phase 2) | 2.2, 3.2, 4.2, 4.3, 8.3 | `.notificationOccurred(.success)` when countdown reaches 0 |
| 5 | **Media pause moved to Phase 2, opt-in, default OFF** | 4.2 | New section note added under Animations |
| 6 | **Two-phase overlay model confirmed** — snooze lives in Settings only (not a post-dismiss bottom sheet) | 2.2, 3.2, 4.1 | Clean countdown → user taps ⚙️ to reach snooze controls in Settings |
| 7 | **Settings screen additions** — Snooze controls (5 min / 1 hr / rest of day), per-type enable toggles, version display | 3.1, 8.1, 8.2 | All Phase 1 |
| 8 | **os.Logger added to Phase 1 (M0.2)** | (engineering decision; noted for completeness) | No UX impact |
| 9 | **Rest-of-day snooze gets orange warning tint** | 3.1, 8.2 | Consequential action treatment prevents casual selection |
