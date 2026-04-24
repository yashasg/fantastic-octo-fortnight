# Skill: Minimal Onboarding for Simple Apps

**Type:** UX Design Pattern  
**Domain:** Onboarding, First-Run Experience  
**Created:** 2026-04-24 (Reuben)  
**Last Updated:** 2026-04-24

---

## When to Use This Pattern

Apply this pattern when:
- The app has **< 5 core features** that are immediately understandable
- The app's purpose is **self-explanatory from its name** (e.g., "Eye & Posture Reminder")
- Defaults are sensible and work for 80%+ of users without customization
- The target audience is **tech-savvy** (familiar with iOS patterns)

**Do NOT use this pattern when:**
- The app has complex workflows that require explanation
- The app introduces novel interaction paradigms (e.g., gesture-based navigation not used in standard iOS apps)
- Onboarding includes account creation or multi-step setup (e.g., connecting bank accounts)

---

## Core Principles

1. **No tutorial screens.** Launch directly to the main functional screen.
2. **Defaults are pre-configured.** User should be able to close the app immediately and trust it will work.
3. **Permission requests are immediate.** If the app's core function requires a permission, request it on first launch — don't hide it behind a tutorial.
4. **Optional welcome banner.** A single, dismissible banner is acceptable for reassurance ("You're all set!") — but it must be dismissible and never reappear.

---

## Implementation Checklist

### Phase 1: Core Onboarding Flow

- [ ] **Launch screen** → 1 second or less
- [ ] **First screen** → Main functional screen (e.g., Settings, Home, Dashboard)
- [ ] **Defaults loaded** → All settings have sensible defaults (no "Please configure..." placeholders)
- [ ] **Permission request** → System permission prompt appears automatically (if required)
- [ ] **User can close immediately** → No forced "Next" or "Continue" buttons

### Phase 2: Optional Enhancements

- [ ] **Welcome banner** (optional) → Single, dismissible banner at bottom of first screen:
  - Example: "👋 You're all set! Your reminders will appear every 20 minutes."
  - Dismissed via `UserDefaults.hasSeenWelcome = true`
  - Never reappears after dismissal
- [ ] **Tooltip on first use** (optional) → Subtle, contextual tooltip on first interaction with a non-obvious feature (e.g., swipe gesture):
  - Appears once per feature
  - Auto-dismisses after 3 seconds or on interaction
  - Stored in `UserDefaults` to prevent re-display

---

## Anti-Patterns (What NOT to Do)

❌ **Multi-screen tutorial carousel** ("Swipe to learn more!")
- Users skip these without reading
- Delays time-to-value

❌ **"Tutorial overlays" with forced interaction** (coach marks, arrows pointing at buttons)
- Annoying and condescending
- Users often can't proceed without tapping the highlighted element

❌ **"Complete your profile" or "Set up your preferences" screens**
- If setup is optional, don't force it
- Use inline prompts later when context is relevant

❌ **Video tutorials on first launch**
- No one watches these
- Bandwidth-heavy for first launch

---

## Example: Eye & Posture Reminder

**What we did:**
1. User taps app icon → launch screen (< 1s)
2. Settings screen appears with defaults already set:
   - Eyes: every 20 min, 20 s break
   - Posture: every 30 min, 10 s break
   - Toggle: ON
3. System permission prompt appears automatically: "Would Like to Send You Notifications"
4. User taps "Allow" → done. Reminders are scheduled.
5. User can adjust settings if desired, or close the app immediately.

**What we didn't do:**
- No "Welcome to Eye & Posture Reminder!" splash screen
- No "Here's how it works" tutorial carousel
- No "What is the 20-20-20 rule?" educational content (user knows this already)
- No "Swipe up to see settings" coach mark

**Result:**
- Time-to-value: < 10 seconds
- Zero friction
- User trusts the app "just works"

---

## Testing This Pattern

**Success criteria:**
- 90%+ of users complete onboarding in < 15 seconds
- < 5% of users uninstall within first 24 hours due to "confusion"
- Permission grant rate > 70% (if app requires permissions)

**Failure modes to watch for:**
- Users open app, see main screen, and immediately close without understanding what it does → **App name or icon is unclear**
- Users adjust settings repeatedly in first session → **Defaults are wrong**
- Users deny permission and then uninstall → **Permission request wasn't framed with value prop**

---

## Variants

### Variant A: First Launch with Optional Welcome Banner

**Use when:** You want to reassure users that setup is complete without adding a tutorial.

**Implementation:**
```swift
// SettingsView.swift
@State private var showWelcome = !UserDefaults.standard.bool(forKey: "hasSeenWelcome")

var body: some View {
    VStack {
        if showWelcome {
            welcomeBanner
        }
        settingsContent
    }
}

var welcomeBanner: some View {
    HStack {
        Text("👋 You're all set! Reminders will appear every 20 minutes.")
        Button("Got it") {
            UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
            showWelcome = false
        }
    }
    .padding()
    .background(Color.blue.opacity(0.1))
}
```

---

### Variant B: Zero-UI Onboarding (Background Service Apps)

**Use when:** The app has no UI that users interact with regularly (e.g., background tracking, automation).

**Implementation:**
- Launch → show single screen explaining what the app does
- "Enable" button → triggers permission requests
- Once permissions granted → screen shows "Running" status
- User closes app, never opens it again

**Example apps:** Ad blockers, VPN apps, clipboard managers

---

## Related Patterns

- **Progressive Disclosure:** Reveal advanced features only when user needs them (don't show all settings upfront)
- **Graceful Degradation:** If permission denied, app still works in limited capacity (with clear prompt to re-enable)
- **Smart Defaults:** Use sensible defaults based on research or industry standards (e.g., 20-20-20 rule for eye breaks)

---

## References

- Apple Human Interface Guidelines: Onboarding ([link](https://developer.apple.com/design/human-interface-guidelines/onboarding))
- "Don't Make Me Think" by Steve Krug (Chapter on obviousness)
- iOS permission request best practices ([Apple Developer](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications))

---

**Pattern Status:** ✅ Validated (Eye & Posture Reminder project)  
**Next Review:** After user testing / beta feedback
