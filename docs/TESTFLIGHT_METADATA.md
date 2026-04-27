# kshana — TestFlight Metadata

## Beta App Description

kshana (क्षण, "a moment") is a lightweight iOS wellness app that reminds you to take eye breaks and posture checks based on your actual screen-on time — not a fixed clock. It pauses automatically when you're driving, on CarPlay, or in Focus Mode, so it only nudges when it matters.

## What to Test

1. **First-launch onboarding:** Walk through the 3-screen onboarding flow (Welcome → Permissions → Setup). Verify notification permission prompt appears and "Get Started" works.
2. **Reminder triggers:** Leave the app in the foreground for 20+ minutes. Confirm the eye-break overlay appears after continuous screen-on time elapses (not wall-clock time).
3. **Overlay interaction:** When the overlay appears, test the countdown ring, swipe-up dismiss, × button dismiss, and auto-dismiss at the end of the countdown.
4. **Snooze:** Tap a snooze option (5 min / 15 min / 30 min / Rest of Day). Verify the reminder returns after the snooze period. Confirm max 2 consecutive snoozes are enforced.
5. **Smart Pause:** Enable Focus Mode (e.g., Do Not Disturb) and verify reminders pause. Connect to CarPlay or simulate driving — reminders should pause automatically.
6. **Settings persistence:** Change intervals, break durations, haptic toggle, and kill the app. Relaunch and confirm all settings are preserved.
7. **Accessibility:** Enable VoiceOver and navigate the entire app. Verify all controls are labeled, the countdown is announced as a live region, and Dynamic Type scales correctly.
8. **Visual identity:** Check the yin-yang logo animation on HomeView (spin → breathing pulse). Enable Reduce Motion in iOS Settings and confirm the logo is static.

## Release Notes (v0.2.0)

**v0.2.0 — Restful Grove**

- 🎨 New Restful Grove visual identity with calming Sage & Mint palette
- ☯️ Animated yin-yang logo on home screen (respects Reduce Motion)
- 📛 App renamed to **kshana** — "a moment, an instant"
- 🔧 7 quality passes: reliability, accessibility, localization, analytics, test coverage, CI hardening, completeness
- 🛡 Smart Pause cold-start fix — no more stuck-paused state
- ♿ WCAG AA contrast verified on all screens; 44pt minimum tap targets
- 🧪 1,382 unit tests + 53 UI tests (81%+ coverage)
- 🔒 Privacy manifest (`PrivacyInfo.xcprivacy`) added for App Store compliance
- 🐛 Fixed: overlay double-present, snooze wake reliability, dead color tokens, AppColor bundle resolution
