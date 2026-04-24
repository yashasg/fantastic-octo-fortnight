# Linus — M1 UI Decisions
**Date:** 2026-04-24
**Author:** Linus (iOS Dev UI)

---

## Decision 1: Settings gear on OverlayView calls onDismiss()

**Context:** OverlayView is created inside UIHostingController with no EnvironmentObjects. It has no way to push a navigation destination or call AppCoordinator directly.

**Decision:** The "Settings" gear button on the overlay calls `onDismiss()`. Since `ContentView → NavigationStack → SettingsView` is always the root view behind the overlay window, dismissing the overlay naturally reveals SettingsView.

**Why it's team-relevant:** Any future work on OverlayView's Settings button (e.g., deep-linking to a specific Settings section) requires injecting a callback into OverlayManager.showOverlay() — OverlayManager.swift would need a new parameter.

---

## Decision 2: accessibilityViewIsModal(true) replaces .accessibilityAddTraits(.isModal)

**Context:** The scaffold used `.accessibilityAddTraits(.isModal)` but the spec requires `accessibilityViewIsModal = true`.

**Decision:** Use `.accessibilityViewIsModal(true)` SwiftUI modifier (available iOS 14+). This correctly hides other UI elements from VoiceOver while the overlay is visible.

---

## Decision 3: isDismissing guard on OverlayView

**Context:** Both the × button and the countdown timer can trigger dismiss concurrently (e.g., user taps × exactly when timer hits 0).

**Decision:** Added `@State private var isDismissing = false`. Both `performDismiss()` and `performAutoDismiss()` check this guard first and set it immediately. Ensures `onDismiss()` is called exactly once, preventing OverlayManager from receiving duplicate dismissal callbacks.

---

## Decision 4: Notification permission warning in SettingsView

**Context:** When the user denies notifications, reminders only work in the foreground. The spec doesn't explicitly require a banner in Phase 1, but users could be confused about why reminders don't fire in the background.

**Decision:** Added a non-blocking warning row in SettingsView when `coordinator.notificationAuthStatus == .denied`, with a deep-link button to iOS Settings. This is purely informational and doesn't block any other settings.
