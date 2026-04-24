# Basher — M1 Services Layer Decisions

**Date:** 2026-04-24  
**Author:** Basher (iOS Dev — Services)  
**Phase:** M1.1 + M1.3 + M1.4

---

## Decision 1: SettingsViewModel owns preset options (canonical source)

**Context:** `ReminderRowView` had `intervalOptions` and `durationOptions` defined as private local arrays. The task spec explicitly calls for these to live in `SettingsViewModel`.

**Decision:** Move canonical definitions to `SettingsViewModel.intervalOptions` and `SettingsViewModel.breakDurationOptions` as `static let` arrays. Added `labelForInterval` and `labelForBreakDuration` static formatters.

**Impact on Views team:** `ReminderRowView` can be refactored to reference `SettingsViewModel.intervalOptions` / `.breakDurationOptions` instead of local copies. Both define the same values so no runtime difference until Views team migrates.

---

## Decision 2: OverlayView swipe-UP direction fix

**Context:** `OverlayView` had `value.translation.height > 0` for the dismiss gesture, which fires on downward swipe. The team decision (2026-04-24T01:06) explicitly states "Overlay dismisses by swiping UP".

**Decision:** Changed to `value.translation.height < 0` (negative Y = upward drag in SwiftUI's coordinate system).

**Why noted:** This was a functional bug in a Views file, fixed by Services owner because the task requirements explicitly listed it. Flagging so Linus / Views team is aware of the change.

---

## Decision 3: Overlay Settings gear button navigates by dismissal

**Context:** The team decision (2026-04-24T01:09) says the overlay must have a Settings gear button that "navigates the user to the app's Settings screen". The app root IS the Settings screen (ContentView → SettingsView). There is no navigation stack to push onto from a UIWindow overlay.

**Decision:** The Settings gear button calls `onDismiss()`. Dismissing the overlay reveals the Settings view underneath naturally. No deep-link or navigation coordinator needed in Phase 1.

**Future consideration:** If Phase 2 adds a home/dashboard screen, the gear button may need a `DeepLink` mechanism to explicitly route to Settings after dismiss.

---

## Decision 4: Haptic feedback on overlay auto-completion lives in OverlayView

**Context:** The task spec says "haptic on completion". The countdown timer logic lives in `OverlayView` (SwiftUI `@State` driven). `OverlayManager` doesn't know when the countdown finishes.

**Decision:** `UIImpactFeedbackGenerator(style: .medium)` fired in `OverlayView.startTimer()` when `secondsRemaining` hits zero, before calling `onDismiss()`. Medium impact gives a noticeable but non-jarring pulse.

**Why not in OverlayManager:** `OverlayManager` controls window lifecycle, not countdown state. Moving haptic there would require a completion callback from the view, creating coupling.
