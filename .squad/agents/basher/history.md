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

