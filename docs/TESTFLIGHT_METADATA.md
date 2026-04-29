# kshana — TestFlight Metadata

## Beta App Description

kshana (क्षण, "a moment") is a lightweight iOS wellness app that helps you build healthier app-break habits. Choose which apps you'd like to monitor, set your break timing, and kshana gently reminds you when it's time to step away. It pauses automatically when you're driving, on CarPlay, or in Focus Mode, so it only nudges when it matters. Fallback local alerts work even if System Screen Time access is unavailable.

## What to Test

1. **First-launch onboarding:** Walk through the 4-screen onboarding flow (Welcome → App Break Explanation → Screen Time Permission → Setup). Verify the calm pre-permission education screen appears, then the system permission prompt, and "Get Started" works.
2. **Permission handling:** Test both "Grant App Break Access" (accepted) and "Not now" (skipped). Verify the app gracefully degrades to local alert fallback if permission is not granted.
3. **App selection (roadmap):** Note that app/category selection UI is a future feature. Current version uses default scope.
4. **Reminder triggers:** Leave the app in the foreground for 20+ minutes. Confirm the break screen appears after continuous screen-on time elapses (not wall-clock time). When Screen Time access is unavailable, verify local alerts work.
5. **Break screen interaction:** When the break screen appears, test the countdown ring, swipe-up dismiss, × button dismiss, settings button (⚙️), and auto-dismiss at the end of the countdown.
6. **Snooze:** Tap a snooze option (5 min / 1 hour / Rest of Day). Verify the reminder returns after the snooze period. Confirm max 2 consecutive snoozes are enforced.
7. **Smart Pause:** Enable Focus Mode (e.g., Do Not Disturb) and verify reminders pause. Connect to CarPlay or simulate driving — reminders should pause automatically.
8. **Settings persistence:** Change intervals, break durations, haptic toggle, and kill the app. Relaunch and confirm all settings are preserved.
9. **Accessibility:** Enable VoiceOver and navigate the entire app. Verify all controls are labeled, the countdown is announced as a live region, and Dynamic Type scales correctly.
10. **Visual identity:** Check the yin-yang logo animation on HomeView (spin → breathing pulse). Enable Reduce Motion in iOS Settings and confirm the logo is static.

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
