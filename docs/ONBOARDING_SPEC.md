# Eye & Posture Reminder — Onboarding Flow Spec (M2.1)

> **Author:** Reuben, Product Designer  
> **Date:** 2026-04-24  
> **Milestone:** M2.1 — Onboarding Flow  
> **Implementer:** Linus (iOS UI Dev)  
> **Status:** Ready for implementation

---

## Overview

The onboarding flow is a 3-screen sequence shown to new users on first launch. It introduces the app's value, explains why notifications are needed, and previews the default configuration before the user starts.

**Design north star:** *Invisible setup. Maximum confidence. Zero friction.*

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
    WelcomeScreen()
        .tag(0)
    NotificationPermissionScreen()
        .tag(1)
    QuickSetupScreen()
        .tag(2)
}
.tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
.indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
```

- **Page dots:** Shown at the bottom centre of all 3 screens. Standard iOS page indicator style.
- **Swipe:** Left/right swipe navigates between pages freely (no lock on forward-only).
- **"Next" buttons:** Advance to the next page programmatically (`currentPage += 1`).
- **Back swipe:** Fully supported — users can go back and re-read.

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
│    Eye & Posture Reminder          │  ← Headline
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
| **Headline** | `Welcome to Eye & Posture Reminder` |
| **Subheadline** | `Small, helpful nudges to rest your eyes and sit up straight.` |
| **Body** | `Takes less than a minute to set up. Works quietly in the background — you'll barely know it's there.` |
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
| Next button | `"Next"` | `"Go to notifications screen"` |
| Page indicator | `"Page 1 of 3"` | — |

Mark illustration icons as decorative:
```swift
Image(systemName: "eye.fill")
    .accessibilityHidden(true)
```

---

## Screen 2 — Notification Permission

### Purpose
Explain *why* the app needs notifications before triggering the system prompt. Remove anxiety. Build trust. The user should feel informed, not interrogated.

**Key principle:** Never just throw a system prompt at a user cold. Educate first — they'll say yes far more often, and they'll understand what they agreed to.

### Layout

```
┌────────────────────────────────────┐
│                                    │
│    [Notification preview card]     │
│    ┌────────────────────────────┐  │
│    │ 👁  Eye & Posture Reminder │  │
│    │ Eye Break                  │  │
│    │ Time to rest your eyes.    │  │
│    │                    now     │  │
│    └────────────────────────────┘  │
│                                    │
│    Stay on track,                  │
│    effortlessly.                   │  ← Headline
│                                    │
│    Reminders arrive as             │
│    notifications — so the app      │
│    works even when you're not      │
│    looking at it.                  │  ← Explanation copy
│                                    │
│    No spam. Just the breaks        │
│    you asked for, when you         │
│    need them.                      │  ← Reassurance copy
│                                    │
│    [ Enable Notifications ]        │  ← Primary CTA
│    Maybe Later                     │  ← Secondary option
│                                    │
│            ○ • ○                   │  ← Page dots
└────────────────────────────────────┘
```

### Copy

| Element | Copy |
|---|---|
| **Headline** | `Stay on track, effortlessly.` |
| **Explanation** | `Reminders arrive as notifications — so the app works even when you're not looking at it.` |
| **Reassurance** | `No spam. Just the breaks you asked for, when you need them.` |
| **Primary CTA** | `Enable Notifications` |
| **Secondary option** | `Maybe Later` |

### Notification Preview Card

A visual mock of an iOS notification to set expectations. Not a real notification — a styled `RoundedRectangle` view that resembles one.

```swift
VStack(alignment: .leading, spacing: 4) {
    HStack(spacing: 8) {
        Image(systemName: "eye.fill")
            .foregroundStyle(.indigo)
            .font(.caption)
        Text("Eye & Posture Reminder")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
        Spacer()
        Text("now")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
    Text("Eye Break")
        .font(.subheadline)
        .fontWeight(.semibold)
    Text("Time to rest your eyes.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
}
.padding(16)
.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
.padding(.horizontal, 16)
.accessibilityElement(children: .combine)
.accessibilityLabel("Example notification: Eye Break — Time to rest your eyes.")
```

### "Enable Notifications" Button Behaviour

Tapping **Enable Notifications** triggers the system permission prompt:

```swift
Button("Enable Notifications") {
    UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .sound, .badge]
    ) { granted, _ in
        DispatchQueue.main.async {
            currentPage = 2  // advance regardless of outcome
        }
    }
}
.buttonStyle(.borderedProminent)
.controlSize(.large)
.tint(.indigo)
.frame(maxWidth: .infinity)
.padding(.horizontal, 32)
```

The onboarding advances to Screen 3 regardless of the user's choice on the system prompt. Permission denial is handled gracefully in the main app (see `UX_FLOWS.md` §2.4).

### "Maybe Later" Behaviour

```swift
Button("Maybe Later") {
    currentPage = 2  // advance without requesting permission
}
.foregroundStyle(.secondary)
.font(.subheadline)
```

- Plain text link, no button chrome
- Secondary color (`.secondary`) — present but not dominant
- **No guilt trip.** The label is neutral. Not "Skip (reminders won't work)" — that's a dark pattern.
- Advances to Screen 3 without showing the system prompt

### Accessibility

| Element | VoiceOver Label | VoiceOver Hint |
|---|---|---|
| Notification card | `"Example notification: Eye Break — Time to rest your eyes."` | (none) |
| Enable button | `"Enable Notifications"` | `"Opens system notification permission prompt"` |
| Maybe Later | `"Maybe Later"` | `"Skip for now, you can enable notifications later in Settings"` |
| Page indicator | `"Page 2 of 3"` | — |

---

## Screen 3 — Quick Setup Preview

### Purpose
Show the user what's already configured. Build confidence. Let them "get started" immediately or tweak settings if they want to. The app is ready — they just need to confirm.

### Layout

```
┌────────────────────────────────────┐
│                                    │
│    You're all set.                 │  ← Headline
│                                    │
│    Here's how we've set things     │
│    up for you:                     │  ← Subheadline
│                                    │
│    ┌─────────────────────────────┐ │
│    │ 👁  Eye Breaks              │ │
│    │     Every 20 min            │ │
│    │     20 second break         │ │
│    └─────────────────────────────┘ │
│                                    │
│    ┌─────────────────────────────┐ │
│    │ 🧍 Posture Checks           │ │
│    │     Every 30 min            │ │
│    │     10 second check         │ │
│    └─────────────────────────────┘ │
│                                    │
│    You'll get a gentle reminder    │
│    to look away and sit up —       │
│    no effort required from you.    │  ← Reassurance copy
│                                    │
│    [    Get Started    ]           │  ← Primary CTA
│    Customize settings              │  ← Secondary option
│                                    │
│            ○ ○ •                   │  ← Page dots
└────────────────────────────────────┘
```

### Copy

| Element | Copy |
|---|---|
| **Headline** | `You're all set.` |
| **Subheadline** | `Here's how we've set things up for you:` |
| **Reassurance** | `You'll get a gentle reminder to look away and sit up straight — no effort required from you.` |
| **Primary CTA** | `Get Started` |
| **Secondary option** | `Customize settings` |

### Default Settings Cards

Display the two reminder types as summary cards showing default values. These are **read-only display** — not interactive pickers. The message is: "it's already configured."

```swift
struct SetupPreviewCard: View {
    let icon: String
    let color: Color
    let title: String
    let interval: String
    let duration: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack(spacing: 8) {
                    Label(interval, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(duration, systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): every \(interval), \(duration) break")
    }
}

// Usage:
SetupPreviewCard(
    icon: "eye.fill",
    color: .indigo,
    title: "Eye Breaks",
    interval: "20 min",
    duration: "20 seconds"
)
SetupPreviewCard(
    icon: "figure.stand",
    color: .green,
    title: "Posture Checks",
    interval: "30 min",
    duration: "10 seconds"
)
```

### "Get Started" Button Behaviour

```swift
Button("Get Started") {
    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
    // Dismiss onboarding → app navigates to SettingsView
    // Reminders are already scheduled with defaults
}
.buttonStyle(.borderedProminent)
.controlSize(.large)
.tint(.indigo)
.frame(maxWidth: .infinity)
.padding(.horizontal, 32)
```

- Dismisses the `OnboardingView`
- App transitions to `SettingsView` (main content)
- Default reminders are already scheduled (set up during `SettingsStore` initialization)
- No additional confirmation needed

### "Customize settings" Behaviour

```swift
Button("Customize settings") {
    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
    // Dismiss onboarding → navigate to SettingsView
    // Same outcome as "Get Started" — SettingsView is already the main screen
}
.foregroundStyle(.indigo)
.font(.subheadline)
```

- Same navigation outcome as "Get Started" — goes to `SettingsView`
- The distinction is communicative: "Customize" signals to curious users that they *can* change settings
- `SettingsView` is the app's home screen — landing there from either path is correct

### Accessibility

| Element | VoiceOver Label | VoiceOver Hint |
|---|---|---|
| Eye Breaks card | `"Eye Breaks: every 20 minutes, 20 second break"` | (none) |
| Posture Checks card | `"Posture Checks: every 30 minutes, 10 second break"` | (none) |
| Get Started button | `"Get Started"` | `"Dismiss setup and begin using the app"` |
| Customize button | `"Customize settings"` | `"Go to settings to adjust reminder intervals"` |
| Page indicator | `"Page 3 of 3"` | — |

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

```swift
struct OnboardingView: View {
    @State private var currentPage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TabView(selection: $currentPage) {
            WelcomeScreen(onNext: { currentPage = 1 })
                .tag(0)
            NotificationPermissionScreen(onNext: { currentPage = 2 })
                .tag(1)
            QuickSetupScreen(onGetStarted: finishOnboarding,
                             onCustomize: finishOnboarding)
                .tag(2)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        .ignoresSafeArea(edges: .top)
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        // Parent view observes this flag and transitions to SettingsView
    }
}
```

**Parent integration pattern:**

```swift
@AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

var body: some View {
    if hasSeenOnboarding {
        SettingsView()
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
| User swipes to Screen 3 without tapping "Enable Notifications" | Fine — they skipped Screen 2 CTA. Permission not requested. Same as "Maybe Later". |
| User taps "Enable Notifications" and system prompt is denied | Advance to Screen 3 normally. Permission denial banner shown in SettingsView after onboarding. |
| User force-quits mid-onboarding | `hasSeenOnboarding` is false. They see onboarding again on next launch. Not a bug. |
| User has previously granted notifications (re-install scenario) | System prompt on Screen 2 will not appear (iOS skips prompt if already granted). `requestAuthorization` callback returns `granted: true` immediately. Advance to Screen 3 as normal. |
| VoiceOver user | TabView page swiping works with VoiceOver swipes. Page indicator announces current page. Each screen announces headline on appear. |
| iPad | Layout scales naturally. Constrain max content width to 540pt on iPad for comfortable reading. |

---

## File Structure

New files to create:

```
Views/
├── Onboarding/
│   ├── OnboardingView.swift          – TabView container + page state
│   ├── WelcomeScreen.swift           – Screen 1
│   ├── NotificationPermissionScreen.swift  – Screen 2
│   ├── QuickSetupScreen.swift        – Screen 3
│   └── SetupPreviewCard.swift        – Reusable card component
```

`hasSeenOnboarding` key added to `SettingsStore.swift` constants (or declared as `static let` in a `UserDefaultsKeys` enum if one exists).

---

## Summary for Linus

| Item | Decision |
|---|---|
| Navigation | `TabView` with `PageTabViewStyle` |
| Page indicator | `indexDisplayMode: .always` |
| First-launch flag | `UserDefaults` key `"hasSeenOnboarding"` — use `@AppStorage` in parent |
| Notification request | Screen 2 primary CTA; advances to Screen 3 regardless of outcome |
| "Get Started" and "Customize" | Both set flag and go to `SettingsView` — no distinction in navigation |
| Animations | Fade + slide (20pt) on appear; respect `accessibilityReduceMotion` |
| Button style | `.borderedProminent`, `.controlSize(.large)`, `.tint(.indigo)` |
| Secondary actions | Plain text links, `.foregroundStyle(.secondary)` or `.foregroundStyle(.indigo)` |
| Cards | `.regularMaterial` background, `RoundedRectangle(cornerRadius: 16)` |
| Illustration | SF Symbols `eye.fill` + `figure.stand` at 72pt, `.regularMaterial` backing card |
| Dynamic Type | All SwiftUI font styles; wrap content in `ScrollView` |
| VoiceOver | All interactive elements labeled; illustration icons `.accessibilityHidden(true)` |
| Reduce Motion | `@Environment(\.accessibilityReduceMotion)` — no offset when enabled |
