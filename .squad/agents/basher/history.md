# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

### 2026-04-24 — Xcode Project Scaffold

- **Rusty had already pre-built half the stack** before I started. Always read existing `EyePostureReminder/` files before creating new ones — Models, Services, Utilities, ViewModels, and DesignSystem were already present.
- **`Package.swift` iOS executable targets** can't be compiled with plain `swift build` on macOS because UIKit/SwiftUI iOS APIs aren't available on the host. This is expected; open the package in Xcode and target a simulator/device.
- **`OverlayManager` is `@MainActor`** — calling it from `AppDelegate` notification callbacks requires a `Task { @MainActor in ... }` wrapper.
- **`ReminderType` needed notification properties** (`categoryIdentifier`, `notificationTitle`, `notificationBody`, `init?(categoryIdentifier:)`, `overlayTitle`) — these were added to the model so every layer (Scheduler, AppDelegate, OverlayView) can derive the right strings from the type rather than hard-coding strings in multiple places.
- **Use `SettingsStore` published properties directly in ViewModel** (`eyesInterval`, `eyesBreakDuration`, etc.) — don't create wrapper `ReminderSettings` structs in the VM layer; that adds unnecessary mapping.
- **`OverlayManager.shared` singleton** is safe on `@MainActor` — added it so AppDelegate can reach the manager without dependency injection ceremony.

### 2026-04-24 — Phase 1 Services Implementation (M1.1 + M1.3 + M1.4)

- **All scaffold files were already production-quality** — `SettingsStore`, `ReminderScheduler`, `AppCoordinator`, `AppDelegate`, `OverlayManager`, and `EyePostureReminderApp` were fully implemented in the scaffolding. Read carefully before over-writing.
- **SettingsViewModel preset options belong on the ViewModel** — added `static let intervalOptions` and `static let breakDurationOptions` as static arrays on `SettingsViewModel`, plus `labelForInterval` / `labelForBreakDuration` static formatters. `ReminderRowView` duplicated these locally; the canonical source is the VM.
- **OverlayView swipe direction was inverted** — the scaffold had `value.translation.height > 0` which triggers on downward swipe. The decision says swipe UP dismisses; fixed to `height < 0`. SwiftUI's Y axis is positive-downward.
- **Haptic on overlay completion** — added `UIImpactFeedbackGenerator(style: .medium)` fired when the countdown timer reaches zero, before calling `onDismiss()`. This is in `OverlayView`, not `OverlayManager`, because the haptic timing is tied to the SwiftUI countdown state.
- **Settings gear button on overlay** — decision says overlay has "× button + Settings gear button". The app root IS the Settings screen (ContentView → NavigationStack → SettingsView), so the gear button simply calls `onDismiss()` — dismissing the overlay reveals Settings automatically.
- **`OverlayView` is in the views layer, not my charter** — but since the task explicitly listed overlay behavior requirements and the view had functional bugs (wrong swipe direction, missing haptic, missing Settings button), I fixed them. Flagged in decisions inbox.

### 2026-04-24 — M1.6 Integration & Edge Case Handling

- **AppCoordinator as ReminderScheduling** — having `AppCoordinator` conform to `ReminderScheduling` is the cleanest integration seam. `SettingsViewModel` keeps its `scheduler: ReminderScheduling` abstraction (tests unchanged), but in production it receives the coordinator so all scheduling paths (notifications + fallback timers) stay in sync on every settings change.
- **Debounce in the coordinator, not in the ViewModel** — debounce logic lives in `AppCoordinator.reschedule(for:)` using per-type `Task` cancellation. `MockReminderScheduler` has no debounce, so existing `SettingsViewModelTests` continue passing. The test `test_rapidSettingChanges_allReschedulesAreTriggered` still expects 4 calls against the mock (testing SettingsViewModel dispatch) while production debounces to 2 — this is correct layering, not a gap.
- **scenePhase background tracking** — `EyePostureReminderApp` needs a `@State var wasInBackground` flag to distinguish `.inactive → .active` (task switcher) from `.background → .active` (true foreground resume). Only the latter should trigger `handleForegroundTransition()` to avoid unnecessary reschedule thrash.
- **`OverlayManager.init(audioManager:)` public with default** — keeping a `OverlayManager(audioManager: MediaControlling = AudioInterruptionManager())` init makes the singleton init transparent (`static let shared = OverlayManager()` just works) while also enabling mock injection in tests (`OverlayManager(audioManager: mockAudio)`).
- **`AVAudioSession.soloAmbient` is the right category for interrupting external audio** — it respects the silent switch, interrupts other apps (Spotify, Podcasts), and does NOT show a Control Center "now playing" entry since we don't actually play any audio ourselves. Never use `.playback` or add `UIBackgroundModes: audio`.
- **`clearQueue()` on `cancelAllReminders()`** — when the master toggle is turned off or all reminders are cancelled, the overlay queue must also be flushed so previously-queued overlays don't surface after the user thought they cancelled everything.


### 2026-04-25 — P1 Saul Review Fixes + M2.3 Snooze

- **P1-1 Snooze guard in scheduleReminders():** The guard must run *before* auth checks. Pattern: check `snoozedUntil > Date()` → cancel + arm wake → return early; else clear expired snooze and fall through. `cancelAllReminders()` on `AppCoordinator` also arms the in-process `snoozeWakeTask` when `snoozedUntil` is set, so snooze applied while in foreground gets a wake timer immediately without needing `scheduleReminders()` to be called.
- **P1-2 NotificationScheduling injection:** Added `getAuthorizationStatus() async -> UNAuthorizationStatus` to the `NotificationScheduling` protocol (wraps `notificationSettings().authorizationStatus`). `MockNotificationCenter` returns `.authorized` when `authorizationGranted == true` and `.denied` otherwise. `FailOnceNotificationCenter` in tests returns `.authorized`.
- **P1-3 OverlayPresenting injection:** Use `overlayManager: OverlayPresenting? = nil` default parameter; resolve to `OverlayManager.shared` inside init body to avoid actor-isolation issues with default parameter expressions. `clearQueue()` was already in `OverlayPresenting` protocol from a prior commit — no change needed.
- **snooze wake notification category:** Use `AppCoordinator.snoozeWakeCategory` static constant so `AppDelegate` can distinguish snooze-wake from real reminders. Snooze-wake routes to `scheduleReminders()` not `handleNotification(for:)`.
- **M2.3 SnoozeOption.restOfDay:** Compute as `Calendar.current.date(byAdding: .day, value: 1, to: startOfDay(for: now))`. Always returns a non-optional via fallback to `now + 24h`.
- **Snooze count limit:** `maxConsecutiveSnoozes = 2` enforced by `canSnooze` check in both `snooze(for:)` and `snooze(option:)`. Reset happens in `handleNotification(for:)` (real reminder fired) and `cancelSnooze()`. Do NOT reset in `scheduleReminders()` snooze-expiry path — that's implicit reset via `snoozeCount = 0` alongside `snoozedUntil = nil`.
- **Test contract preserved:** `snooze(for: 5)` still calls `cancelAllReminders()` once and `scheduleReminders` zero times. New `snooze(option:)` method is the forward-looking API; legacy method delegates to same logic.

### 2026-04-25 — 10-Second Testing Defaults

- **`ReminderSettings.defaultEyes` and `defaultPosture` changed to `interval: 10`** for simulator testing. Restore to `1200`/`1800` (20 min/30 min) before shipping. Marked with `// TEST OVERRIDE` comments in `ReminderSettings.swift`.
- **`UNTimeIntervalNotificationTrigger(repeats: true)` requires ≥ 60s** — the OS silently rejects repeating notifications under that threshold. Fixed in `ReminderScheduler` by using `repeats: reminderSettings.interval >= 60`. Short intervals (< 60s) schedule as one-shot; after delivery the notification is gone but the fallback timer path fills the gap.
- **Fallback timer path is the best way to test short intervals.** When notification permission is denied on the simulator (or revoked via Settings → reset privacy), `AppCoordinator` starts `Timer.scheduledTimer` with no OS minimum — overlays fire every 10s without restriction. Recommend testing with notifications denied for rapid-fire iteration.
- **Default interval tests in `SettingsStoreTests` will fail** while this testing override is active (they assert 1200/1800). That's expected — revert `ReminderSettings.swift` before running the full test suite or merging to main.

### 2026-04-25 — Wave 3: Dark Mode + 10-Second Testing (Orchestrated)

**Agents:** Basher (Services), Danny (PM), Tess (UI/UX)  
**Status:** ✅ SUCCESS — All tasks completed

**Basher Contribution Summary:**
- Set reminder intervals to 10s for testing (ReminderSettings.swift)
- Fixed UNTimeIntervalNotificationTrigger repeats constraint for < 60s intervals
- Dynamic `repeats` flag: `repeats: reminderSettings.interval >= 60`
- Documented decision in decisions.md as permanent correctness fix

**Team Learnings from Parallel Work:**
- Dark mode infrastructure nearly complete — 90% of app already adaptive (good SwiftUI hygiene)
- Accent colors (blue, green, orange) now have adaptive variants for dark mode
- WCAG bug fix: warningOrange in light mode now meets 3:1 contrast threshold (was 2.7:1, now 3.5:1)
- No `.preferredColorScheme` locks exist anywhere — app follows OS appearance correctly
- Overlay UIWindow correctly inherits system appearance (no `overrideUserInterfaceStyle` set)
