# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

### 2026-04-25 — defaults.json Config Layer (Danny Decision 3.6)

- **`AppConfig.load(from:)`** uses `Bundle` injection — unit tests can pass a fixture bundle pointing at a local `defaults.json` without touching `Bundle.main`.
- **`ReminderSettings.defaultEyes/defaultPosture` are now `static var`** (not `let`) because they call `AppConfig.load()` each time. That's by design — allows test bundles to substitute different JSON without the value being frozen at module init time.
- **`SettingsPersisting.hasValue(forKey:)`** was added to the protocol to detect first-launch (no `epr.*` keys present). `MockSettingsPersisting` already had this helper method — moving it to the protocol required zero mock changes.
- **`SettingsStore.init(store:configBundle:)`** now accepts a `configBundle` parameter alongside `store` for full testability of both layers simultaneously.
- **`resetToDefaults()` writes through `@Published var` setters**, not directly to `store`. This means `didSet` observers propagate to UserDefaults automatically and SwiftUI views update immediately — no manual `objectWillChange.send()` needed.
- **`Package.swift` resources**: Added `.process("Resources")` to the `executableTarget` so `defaults.json` is copied into the app bundle. Without this the file would be excluded from the bundle by SPM.
- **TEST OVERRIDE pattern is now obsolete** — change `eyeInterval` in `defaults.json` to `10` for simulator testing instead of commenting/uncommenting Swift code.

### 2026-04-24 — Xcode Project Scaffold

- **Rusty had already pre-built half the stack** before I started. Always read existing `EyePostureReminder/` files before creating new ones — Models, Services, Utilities, ViewModels, and DesignSystem were already present.
- **`Package.swift` iOS executable targets** can't be compiled with plain `swift build` on macOS because UIKit/SwiftUI iOS APIs aren't available on the host. This is expected; open the package in Xcode and target a simulator/device.
- **`OverlayManager` is `@MainActor`** — calling it from `AppDelegate` notification callbacks requires a `Task { @MainActor in ... }` wrapper.
- **`ReminderType` needed notification properties** (`categoryIdentifier`, `notificationTitle`, `notificationBody`, `init?(categoryIdentifier:)`, `overlayTitle`) — these were added to the model so every layer (Scheduler, AppDelegate, OverlayView) can derive the right strings from the type rather than hard-coding strings in multiple places.
- **Use `SettingsStore` published properties directly in ViewModel** (`eyesInterval`, `eyesBreakDuration`, etc.) — don't create wrapper `ReminderSettings` structs in the VM layer; that adds unnecessary mapping.
- **`OverlayManager.shared` singleton** is safe on `@MainActor` — added it so AppDelegate can reach the manager without dependency injection ceremony.

### 2026-04-25 — Data-Driven Config Layer: AppConfig + defaults.json (Decision 2.20)

- **Deliverable:** `Resources/defaults.json` (production values), `Models/AppConfig.swift` (Codable loader), `SettingsStore` wiring, `resetToDefaults()` method
- **JSON schema:** `{ "defaults": { "eyeInterval", "eyeBreakDuration", ... }, "features": { "masterEnabledDefault", "maxSnoozeCount" } }`
- **First-launch logic:** `SettingsPersisting.hasValue(forKey:)` guard → if keys absent, seed from JSON via `AppConfig.load(from: Bundle)`
- **Reset path:** `resetToDefaults()` clears keys and re-seeds from JSON (same code path as first launch — no new logic needed)
- **Testability:** `AppConfig.load()` + `SettingsStore.init(store:configBundle:)` both accept `Bundle` parameter for test injection
- **Protocol addition:** `SettingsPersisting.hasValue(forKey: String) -> Bool` for first-launch detection; `MockSettingsPersisting` already had this — moved to protocol with zero mock changes
- **Build verified:** `./scripts/build.sh build` → BUILD SUCCEEDED
- **Tests pending:** Livingston has 136 tests written (4 intentionally failing until Basher integration wiring complete)
- **Decision filed:** `.squad/decisions/decisions.md` (Decision 2.20)

### 2026-04-24 — Phase 1 Services Implementation (M1.1 + M1.3 + M1.4)

- **All scaffold files were already production-quality** — `SettingsStore`, `ReminderScheduler`, `AppCoordinator`, `AppDelegate`, `OverlayManager`, and `EyePostureReminderApp` were fully implemented in the scaffolding. Read carefully before over-writing.
- **SettingsViewModel preset options belong on the ViewModel** — added `static let intervalOptions` and `static let breakDurationOptions` as static arrays on `SettingsViewModel`, plus `labelForInterval` / `labelForBreakDuration` static formatters. `ReminderRowView` duplicated these locally; the canonical source is the VM.
- **OverlayView swipe direction was inverted** — the scaffold had `value.translation.height > 0` which triggers on downward swipe. The decision says swipe UP dismisses; fixed to `height < 0`. SwiftUI's Y axis is positive-downward.
- **Haptic on overlay completion** — added `UIImpactFeedbackGenerator(style: .medium)` fired when the countdown timer reaches zero, before calling `onDismiss()`. This is in `OverlayView`, not `OverlayManager`, because the haptic timing is tied to the SwiftUI countdown state.
- **Settings gear button on overlay** — decision says overlay has "× button + Settings gear button". The app root IS the Settings screen (ContentView → NavigationStack → SettingsView), so the gear button simply calls `onDismiss()` — dismissing the overlay reveals Settings automatically.
- **`OverlayView` is in the views layer, not my charter** — but since the task explicitly listed overlay behavior requirements and the view had functional bugs (wrong swipe direction, missing haptic, missing Settings button), I fixed them. Flagged in decisions inbox.

### 2026-04-24 — M1.6 Integration & Edge Case Handling

- **AppCoordinator as ReminderScheduling** — having `AppCoordinator` conform to `ReminderScheduling` is the cleanest integration seam. `SettingsViewModel` keeps its `scheduler: ReminderScheduling` abstraction (tests unchanged), but in production it receives the coordinator so all scheduling paths (notifications + fallback timers) stay in sync on every settings change.

### 2026-04-25 — Data-Driven App Configuration (Danny Decision 3.6)

- **Full config spec filed:** `app-config.json` bundles theme (colors, fonts, spacing, layout, animations, symbols), defaults (reminder intervals, enabled states), copy (all strings), and features (flags).
- **Ownership:** Basher delivers `AppConfigLoader` + `AppConfig` Codable structs with fallback graceful error handling, and updates `SettingsStore` seed/reset pipeline.
- **Tess delivers:** Color/font/spacing JSON values from `theme` section.
- **Linus delivers:** Refactored `DesignSystem` to read all tokens from `AppConfig.current.theme`, plus `AppCopy` accessor pattern for views, plus "Reset to Defaults" UI button.
- **Integration point:** This spec absorbs and supersedes `danny-data-driven-settings-spec.md` (previous settings-only spec); extends to full design system coverage.
- **Audience:** Basher (loader + pipeline), Tess (theme values), Linus (DesignSystem + view refactor).
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

### 2026-04-24 — Data-Driven Default Settings Spec (filed by Danny)

- **Problem:** Hardcoded Swift `static let` defaults require recompile; Basher had to add `// TEST OVERRIDE` comments to test with 10-second intervals.
- **Solution:** Bundle `defaults.json` in app target. `SettingsStore.init()` seeds UserDefaults from JSON on first launch only. UserDefaults always wins on subsequent launches (existing guard pattern, no overwrites).
- **Your ownership:** Build `defaults.json` schema, implement `DefaultsLoader` (JSON decoder with `Bundle` injection for testability), add seeding to `SettingsStore.init()`, expose `resetToDefaults()` API, remove `ReminderSettings.defaultEyes/defaultPosture` statics.
- **Linus ownership:** Add "Reset to Defaults" button to `SettingsView` with confirmation alert.
- **Livingston ownership:** Unit tests for `DefaultsLoader` and updated `SettingsStore`.
- **Key file:** `.squad/decisions.md` (merged from inbox; filed by Danny)
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

### 2026-04-25 — Screen-Time-Based Reminder Trigger (ScreenTimeTracker)

- **`ScreenTimeTracker`** — new `Services/` class, owns a 1-second `Timer` and observes `UIApplication.didBecomeActiveNotification` (start) / `willResignActiveNotification` (stop + reset all counters). Fires `onThresholdReached(type)` on the main thread; resets that type's counter to 0 before calling back. `pauseAll()`/`resumeAll()` used for snooze support; `stop()` for test tearDown cleanup.
- **`willResignActiveNotification` is the correct reset event** (not `didEnterBackground`). `willResignActive` fires immediately on screen off, Control Centre, and any interruption. `didEnterBackground` can fire several seconds later — too late to give accurate screen-on time.
- **UNNotification periodic triggers are now dead production code.** `ReminderScheduler.scheduleReminders()` and `rescheduleReminder()` are never called by `AppCoordinator` for normal reminders. The class and tests are intentionally left intact (reference + safety net). `cancelAllReminders()` is still called as a legacy-notification cleanup safety net.
- **Auth status no longer gates the trigger path.** Previously: authorized → UNNotifications, denied → fallback `Timer`s. Now: `ScreenTimeTracker` is universal. Auth still matters for the snooze-wake silent UNNotification.
- **`startFallbackTimers()` / `stopFallbackTimers()` retained as shims** pointing at `configureScreenTimeTracker()` / `screenTimeTracker.stop()`. Zero test changes needed.
- **`startIfActive()` pattern** — after updating thresholds mid-session (e.g., master toggle on → `scheduleReminders()` while app is foregrounded), call `screenTimeTracker.startIfActive()` to begin ticking immediately without waiting for the next `didBecomeActive` notification.
- **`configureScreenTimeTracker()` calls `resumeAll()`** — safe because it is only called from `scheduleReminders()` after the snooze guard has cleared. `performReschedule(for:)` sets individual thresholds directly and does NOT call `resumeAll()` so snooze state is preserved when settings change during a snooze.
- **Interval semantics changed:** `eyeInterval`/`postureInterval` now mean "seconds of continuous screen-on time", not "wall-clock seconds between reminders". Existing JSON values need no changes.
- **Build verified:** `./scripts/build.sh build` → BUILD SUCCEEDED
- **Decision filed:** `.squad/decisions/inbox/basher-screen-time-tracker.md`
