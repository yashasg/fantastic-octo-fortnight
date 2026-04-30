# kshana — Onboarding Flow Spec (M2.1 — True Interrupt Mode Edition)

> **Author:** Reuben, Product Designer  
> **Date:** 2026-04-24  
> **Updated:** 2026-04-28 (True Interrupt Mode pivot)  
> **Milestone:** M2.1 — Onboarding Flow  
> **Implementer:** Linus (iOS UI Dev)  
> **Status:** Ready for implementation

---

## Overview

The onboarding flow is a 4-screen sequence shown to new users on first launch. It introduces kshana's value, requests notification permission, lets the user configure their reminder schedule with interactive pickers, and introduces True Interrupt Mode before the user starts.

**Design north star:** *Invisible setup. Maximum confidence. Zero friction.*

**Current reality:** Local reminder alerts are a fallback. The core future promise is Screen Time Shield-based interruption once Apple's entitlement is approved.

The user should leave onboarding feeling calm, informed, and ready — not overwhelmed. This is not a feature tour. It's a warm handshake.

---

## Architecture

### First-Launch Detection

```swift
// UserDefaults key — checked in EyePostureApp.swift or SceneDelegate
let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

// On onboarding completion ("Get Started" or "Customize" tap):
UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
```

**Logic in app entry point:**

```swift
if UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
    // Show SettingsView directly
} else {
    // Show OnboardingView
}
```

Onboarding is shown exactly once. If the user force-quits mid-onboarding, they see it again on next launch (flag only set on explicit completion).

---

## Navigation Structure

Use SwiftUI `TabView` with `PageTabViewStyle` for horizontal swipe between screens.

```swift
TabView(selection: $currentPage) {
    OnboardingWelcomeView(onNext: { currentPage = 1 })
        .tag(0)
    OnboardingPermissionView(onNext: { currentPage = 2 }, notificationCenter: coordinator.notificationCenter)
        .tag(1)
    OnboardingSetupView(onGetStarted: { currentPage = 3 })
        .environmentObject(settings)
        .tag(2)
    OnboardingInterruptModeView(
        onGetStarted: finishOnboarding,
        onCustomize: finishOnboardingAndCustomize,
        authorizationStatus: coordinator.screenTimeAuthorization.authorizationStatus
    )
    .tag(3)
}
.tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
.indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
```

- **Page dots:** Shown at the bottom centre of all 4 screens. Standard iOS page indicator style.
- **Swipe:** Left/right swipe navigates between pages freely (no lock on forward-only).
- **"Next" buttons:** Advance to the next page programmatically (`currentPage += 1`).
- **Back swipe:** Fully supported — users can go back and re-read.
- **Screen 4 swipe lock:** A `highPriorityGesture` prevents accidental horizontal swiping on `OnboardingInterruptModeView`, ensuring deliberate completion.

---

## Screen 1 — Welcome

### Purpose
Establish context and set a warm, confident tone. Tell the user what the app does in one breath.

### Layout

```
┌────────────────────────────────────┐
│                                    │
│                                    │
│         [Illustration Area]        │
│     SF Symbol: eye + figure        │
│         (see below)                │
│                                    │
│    Welcome to                      │
│    kshana                          │  ← Headline
│                                    │
│    Small, helpful nudges to rest   │
│    your eyes and sit up straight.  │  ← Subheadline
│    Your body will thank you.       │
│                                    │
│    ──────────────────────────────  │
│                                    │
│    [Takes less than a minute       │
│     to set up. Works quietly       │
│     in the background.]            │  ← Value prop body
│                                    │
│         [  Next  →  ]              │  ← CTA button
│                                    │
│            • ○ ○                   │  ← Page dots
└────────────────────────────────────┘
```

### Copy

| Element | Copy |
|---|---|
| **Headline** | `Welcome to kshana` |
| **Subheadline** | `Healthy app breaks, on your terms.` |
| **Body** | `Set your eye and posture break timing. kshana handles the rest. Takes less than a minute.` |
| **CTA button** | `Next` |

### Illustration

**Concept:** Two SF Symbols side by side, lightly styled — `eye.fill` (indigo/blue tint) and `figure.stand` (green tint). Displayed at ~100pt each on a soft background. Not clipart, not characters — clean and system-native.

**Implementation:**

```swift
HStack(spacing: 24) {
    Image(systemName: "eye.fill")
        .font(.system(size: 72))
        .foregroundStyle(.indigo)
    Image(systemName: "figure.stand")
        .font(.system(size: 72))
        .foregroundStyle(.green)
}
.padding(32)
.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
```

### "Next" Button Styling

```swift
Button("Next") { currentPage = 1 }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .tint(.indigo)
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 32)
```

- **Shape:** Rounded rectangle (system default for `.borderedProminent`)
- **Color:** Indigo (matches eye icon)
- **Width:** Full-width with horizontal padding (32pt)
- **Font:** Dynamic Type `body` weight `semibold` (system default for `.borderedProminent`)
- **Minimum tap target:** 44pt height (system default, verify)

### Accessibility

| Element | VoiceOver Label | VoiceOver Hint |
|---|---|---|
| Eye icon | `"Eye break icon"` | (none — decorative) |
| Figure icon | `"Posture check icon"` | (none — decorative) |
| Headline | Reads naturally | — |
| Next button | `"Next"` | `"Go to explanation screen"` |
| Page indicator | `"Page 1 of 4"` | — |

Mark illustration icons as decorative:
```swift
Image(systemName: "eye.fill")
    .accessibilityHidden(true)
```

---

## Screen 2 — Notification Permission (`OnboardingPermissionView`)

### Purpose
Request `UNUserNotificationCenter` authorization for reminder alerts. Explain why alerts are needed before the OS prompt appears, so users feel informed rather than blindsided.

### Layout

```
┌────────────────────────────────────┐
│                                    │
│    Stay on track                   │  ← Headline
│                                    │
│    [Notification preview card]     │  ← Shows what a reminder looks like
│                                    │
│    kshana sends gentle alerts      │
│    when it's time to rest your     │
│    eyes or check your posture.     │  ← Body copy
│                                    │
│    [ Allow Reminder Alerts ]       │  ← Primary CTA (triggers OS prompt)
│    Not now                          │  ← Skip option
│                                    │
│            ○ ● ○ ○                 │  ← Page dots
└────────────────────────────────────┘
```

### Copy

| Element | Copy |
|---|---|
| **Headline** | `Stay on track` |
| **Primary CTA** | `Allow Reminder Alerts` |
| **Secondary option** | `Not now` |

### Permission Request Behaviour

Tapping **Allow Reminder Alerts** calls `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])`. The onboarding advances to Screen 3 regardless of the user's choice on the system prompt. Permission denial is handled gracefully with a recovery banner in the main app (see `UX_FLOWS.md` §2.4).

### "Not now" Behaviour

- Advances to Screen 3 without requesting permission
- No swipe lock on this screen

### Accessibility

| Element | VoiceOver Label | VoiceOver Hint |
|---|---|---|
| Allow button | `"Allow Reminder Alerts"` | `"Opens system notification permission dialog"` |
| Not now | `"Not now"` | `"Skip for now, you can enable later in Settings"` |
| Page indicator | `"Page 2 of 4"` | — |

---

## Screen 3 — Reminder Schedule Setup (`OnboardingSetupView`)

### Purpose
Let the user configure their eye break and posture check intervals before entering the app. Values bind directly to `SettingsStore`, so the same settings appear in the main Settings screen later.

### Layout

```
┌────────────────────────────────────┐
│                                    │
│    Set your break schedule         │  ← Headline
│    (localised via onboarding.setup.title)
│                                    │
│    ┌─────────────────────────────┐ │
│    │ 👁  Eye Breaks              │ │  ← OnboardingReminderPickerCard
│    │   Remind me every  [20 min] │ │  ← interval picker
│    │   Break for        [20 s]   │ │  ← duration picker
│    └─────────────────────────────┘ │
│                                    │
│    ┌─────────────────────────────┐ │
│    │ 🧍 Posture Checks           │ │
│    │   Remind me every  [30 min] │ │
│    │   Break for        [10 s]   │ │
│    └─────────────────────────────┘ │
│                                    │
│    You can change these anytime    │  ← Reassurance copy
│    in Settings.                    │
│                                    │
│    [    Get Started    ]           │  ← Single primary CTA
│                                    │
│            ○ ○ ● ○                 │  ← Page dots
└────────────────────────────────────┘
```

### Copy

| Element | Copy |
|---|---|
| **Primary CTA** | `Get Started` |

Pickers use `SettingsViewModel.intervalOptions` and `SettingsViewModel.breakDurationOptions` for their values.

### "Get Started" Behaviour

Calls `onGetStarted()` on `OnboardingSetupView`, which advances `currentPage` to 3 (Screen 4 — True Interrupt Mode). Does **not** complete onboarding — the user must also pass Screen 4.

### Accessibility

| Element | VoiceOver Label | VoiceOver Hint |
|---|---|---|
| Eye Breaks card | `"Eye Breaks"` (container label) | — |
| Interval picker | Reads picker selection | Hint from `settings.reminder.intervalPicker.hint` |
| Duration picker | Reads picker selection | Hint from `settings.reminder.durationPicker.hint` |
| Get Started button | `"Get Started"` | `"Advance to the True Interrupt Mode introduction"` |
| Page indicator | `"Page 3 of 4"` | — |

---

## Screen 4 — True Interrupt Mode (`OnboardingInterruptModeView`)

### Purpose
Introduce True Interrupt Mode before the user enters the app. Sets honest expectations while the FamilyControls entitlement (#201) is pending, and offers a path to immediately open Settings for deeper customization.

### CTAs

| Button | Action |
|---|---|
| `Coming Soon` (primary, disabled) | Disabled while entitlement is unavailable |
| `Get Started without True Interrupt` (secondary) | Calls `finishOnboarding()` — logs `onboardingCompleted(cta: .getStarted)`, sets `hasSeenOnboarding = true` |
| `Customize Settings` (tertiary text link) | Calls `finishOnboardingAndCustomize()` — logs `onboardingCompleted(cta: .customize)`, sets `openSettingsOnLaunch = true` then `hasSeenOnboarding = true`; HomeView opens Settings sheet on appear |

### Swipe Lock

`OnboardingInterruptModeView` uses a `highPriorityGesture` on the drag gesture to prevent accidental backward navigation away from the completion screen.

### `Customize Settings` Behaviour

```swift
// OnboardingView.swift
private func finishOnboardingAndCustomize() {
    AnalyticsLogger.log(.onboardingCompleted(cta: .customize))
    UserDefaults.standard.set(true, forKey: AppStorageKey.openSettingsOnLaunch)
    finishOnboarding()
}
```

HomeView observes `openSettingsOnLaunch` via `@AppStorage` and opens the Settings sheet automatically:

```swift
.onAppear {
    if openSettingsOnLaunch {
        openSettingsOnLaunch = false
        showSettings = true
    }
}
```

### Accessibility

| Element | VoiceOver Label | VoiceOver Hint |
|---|---|---|
| Hero illustration | Hidden (`.accessibilityHidden(true)`) | — |
| Get Started without True Interrupt button | `"Get Started without True Interrupt"` | `"Continue without True Interrupt Mode. You can enable it later in Settings."` |
| Customize Settings link | `"Customize Settings"` | `"Start using the app and open Settings immediately to adjust reminders."` |
| Page indicator | `"Page 4 of 4"` | — |

---



## Entrance Animations

Each screen animates in when the `TabView` pages to it. Animations are subtle — they add polish without calling attention to themselves.

### Animation Pattern: Fade + Slide Up

Each screen's content fades in and slides up slightly (20pt) on appear.

```swift
struct OnboardingScreenContent: View {
    @State private var appeared = false
    let content: () -> AnyView

    var body: some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                    appeared = true
                }
            }
            .onDisappear {
                appeared = false  // reset for if user swipes back
            }
    }
}
```

### Reduce Motion Support

**Always respect `UIAccessibility.isReduceMotionEnabled`.**

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// In animation:
withAnimation(reduceMotion ? .none : .easeOut(duration: 0.4).delay(0.1)) {
    appeared = true
}
```

When Reduce Motion is enabled:
- No slide offset — content appears in place
- Fade is retained at a shorter duration (0.15s) — a simple opacity change is not considered motion
- Page swipe between `TabView` tabs still works (system behaviour, not overridden)

### Per-Screen Stagger (Optional Enhancement)

If multiple elements are on screen, stagger their appearance by 0.05–0.1s per element for a gentle cascade effect. Only apply if Reduce Motion is off.

---

## Dynamic Type Support

All text elements use SwiftUI's built-in Dynamic Type. No hardcoded font sizes.

| Element | SwiftUI Font Style |
|---|---|
| Headline | `.title2` `.bold` |
| Subheadline | `.headline` |
| Body copy | `.body` |
| Card labels | `.subheadline` `.semibold` |
| Card sublabels | `.caption` |
| Secondary links | `.subheadline` |

**Layout at large sizes:** Use `ScrollView` wrapping the screen content to prevent clipping at xxxLarge text sizes.

```swift
ScrollView {
    VStack(spacing: 24) {
        // screen content
    }
    .padding()
}
```

---

## Full `OnboardingView` Skeleton

See `EyePostureReminder/Views/Onboarding/OnboardingView.swift` for the current implementation. The skeleton below reflects the actual 4-screen structure:

```swift
struct OnboardingView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settings: SettingsStore
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingWelcomeView(onNext: { currentPage = 1 })
                .tag(0)
            OnboardingPermissionView(onNext: { currentPage = 2 }, notificationCenter: coordinator.notificationCenter)
                .tag(1)
            OnboardingSetupView(onGetStarted: { currentPage = 3 })
                .environmentObject(settings)
                .tag(2)
            OnboardingInterruptModeView(
                onGetStarted: finishOnboarding,
                onCustomize: finishOnboardingAndCustomize,
                authorizationStatus: coordinator.screenTimeAuthorization.authorizationStatus
            )
            .tag(3)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        .background(AppColor.background.ignoresSafeArea())
    }

    private func finishOnboarding() {
        AnalyticsLogger.log(.onboardingCompleted(cta: .getStarted))
        UserDefaults.standard.set(true, forKey: AppStorageKey.hasSeenOnboarding)
    }

    private func finishOnboardingAndCustomize() {
        AnalyticsLogger.log(.onboardingCompleted(cta: .customize))
        UserDefaults.standard.set(true, forKey: AppStorageKey.openSettingsOnLaunch)
        finishOnboarding()
    }
}
```

**Parent integration pattern:**

```swift
@AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

var body: some View {
    if hasSeenOnboarding {
        NavigationStack { HomeView() }
    } else {
        OnboardingView()
    }
}
```

Using `@AppStorage` ensures SwiftUI automatically re-renders when the flag changes — no manual notification needed.

---

## Edge Cases

| Scenario | Handling |
|---|---|
| User swipes past Screen 2 without tapping "Allow Reminder Alerts" | Fine — they skipped the CTA. Permission not requested. Same outcome as "Not now". |
| User taps "Allow Reminder Alerts" and system prompt is denied | Advance to Screen 3 normally. Permission denial banner shown in HomeView/Settings after onboarding. |
| User force-quits mid-onboarding | `hasSeenOnboarding` is false. They see onboarding again on next launch. Not a bug. |
| User has previously granted notifications (re-install scenario) | System prompt on Screen 2 will not appear (iOS skips prompt if already granted). `requestAuthorization` callback returns `granted: true` immediately. Advance to Screen 3 as normal. |
| VoiceOver user | TabView page swiping works with VoiceOver swipes. Page indicator announces current page. Each screen announces headline on appear. |
| iPad | Layout scales naturally. `AppLayout.onboardingMaxContentWidth` constrains content width on iPad for comfortable reading. |

---

## File Structure

Implemented files:

```
Views/
├── Onboarding/
│   ├── OnboardingView.swift                – 4-screen TabView container + page state
│   ├── OnboardingWelcomeView.swift         – Screen 1
│   ├── OnboardingPermissionView.swift      – Screen 2
│   ├── OnboardingSetupView.swift           – Screen 3 (interactive pickers)
│   └── OnboardingInterruptModeView.swift   – Screen 4 (True Interrupt Mode)
```

`hasSeenOnboarding` and `openSettingsOnLaunch` keys are defined in `AppStorageKey` constants.

---

## Summary for Linus

| Item | Decision |
|---|---|
| Navigation | `TabView` with `PageTabViewStyle` |
| Page indicator | `indexDisplayMode: .always` |
| First-launch flag | `UserDefaults` key `"hasSeenOnboarding"` — use `@AppStorage` in parent |
| Notification request | Screen 2 primary CTA (`Allow Reminder Alerts`); advances to Screen 3 regardless of outcome |
| "Get Started" and "Customize" | Screen 3 "Get Started" advances to Screen 4. Screen 4 "Get Started without True Interrupt" = `finishOnboarding()`. Screen 4 "Customize Settings" = `finishOnboardingAndCustomize()` (also sets `openSettingsOnLaunch = true`) |
| Telemetry | `AnalyticsLogger.log(.onboardingCompleted(cta: .getStarted or .customize))` on completion |
| Animations | Fade + slide (20pt) on appear via `.calmingEntrance()`; respects `accessibilityReduceMotion` |
| Button style | `.primary` / `.secondary` (custom ButtonStyles in Components.swift) |
| Secondary actions | Plain text links, `.foregroundStyle(.secondary)` |
| Cards | `.wellnessCard(elevated:)` modifier |
| Dynamic Type | All SwiftUI font styles via `AppFont`; content wrapped in `ScrollView` |
| VoiceOver | All interactive elements labeled; illustration icons `.accessibilityHidden(true)` |
| Reduce Motion | `.calmingEntrance()` checks `accessibilityReduceMotion` — no offset when enabled |
