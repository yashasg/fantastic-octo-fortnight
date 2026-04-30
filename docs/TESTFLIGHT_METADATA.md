# kshana — TestFlight Metadata

## Beta App Description

kshana (क्षण, "a moment") is a lightweight iOS wellness app that helps you build healthier app-break habits. Set your eye and posture break timing, and kshana gently reminds you when it's time to step away. It pauses automatically when you're driving, on CarPlay, or in Focus Mode, so it only nudges when it matters. This beta uses local reminder alerts with Smart Pause integration. True Interrupt Mode (app-level shielding) is in development and will arrive in a future update when Apple's entitlement approval is complete.

## What to Test

1. **First-launch onboarding:** Walk through the 4-screen onboarding flow (Welcome → Notification Permission → Schedule Setup → True Interrupt Mode). On Screen 2, verify the notification preview card appears and the system permission prompt triggers when you tap "Allow Reminder Alerts". On Screen 3, confirm eye-break and posture interval pickers are interactive. On Screen 4, verify the pending/unavailable badge and disabled "Coming Soon" button are shown, and "Skip for Now" completes onboarding.
2. **Permission handling:** Test both "Allow Reminder Alerts" and "Not now" on Screen 2. Verify the app gracefully degrades to a foreground overlay when notification access is not granted — break screens still appear in the foreground even without notification permission.
3. **App selection (Phase 3, entitlement pending):** The app/category setup surface explains that app-level shielding is not available in the current build and will arrive in Phase 3 when Apple approves the entitlement. Do not expect live selected-app shielding in this beta; it is a future capability being developed.
4. **Reminder triggers:** Leave the app in the foreground for 20+ minutes. Confirm the break screen appears after continuous screen-on time elapses (not wall-clock time). To verify local reminder alerts work correctly, allow notifications, set the shortest practical eye/posture intervals, send the app to the background or switch to another app, and confirm iOS notification banners appear at the configured interval. Tap a banner and confirm it opens kshana to the break screen; if no notification appears, report it as a bug.
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
