# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### 2026-04-24 — M1.2 + M1.5 Phase 1 UI layer

- **OverlayView lives in UIWindow with no EnvironmentObjects.** `OverlayManager` creates `OverlayView` via `UIHostingController` without injecting any environment objects. OverlayView must be self-contained — no `@EnvironmentObject` for SettingsStore or AppCoordinator.
- **Settings gear = dismiss overlay.** Since `ContentView → NavigationStack → SettingsView` is always the root app view, tapping the Settings gear button calls `onDismiss()`, which tears down the overlay window and reveals SettingsView underneath. No extra routing needed.
- **Swipe UP to dismiss** (`translation.height < 0`). This is non-obvious — upward drag has a **negative** Y translation in SwiftUI's coordinate space.
- **`isDismissing` guard prevents double-calls.** Both the manual dismiss path and the timer auto-dismiss path gate on `isDismissing` to ensure `onDismiss()` is called exactly once.
- **Fade animations require an `opacity` state var.** `.onAppear` fades in with `overlayAppearCurve`; manual dismiss fades out with `overlayDismissCurve`; auto-dismiss fades with `overlayFadeCurve`. The overlay is presented via `UIWindow.makeKeyAndVisible()` so the hosting controller doesn't own the transition — we own it in SwiftUI state.
- **`SettingsViewModel` is `@State` (not `@StateObject`) in SettingsView.** It's `@MainActor final class` but SettingsView only calls action methods on it — never observes its `@Published` properties. `@State` is the right tool to keep the VM alive across view updates without triggering re-renders.
- **Notification permission warning banner** reads `coordinator.notificationAuthStatus == .denied` and shows a deep-link button to open System Settings. `SettingsView` calls `coordinator.refreshAuthStatus()` in `.task` on appear to keep this accurate.
- **`ReminderRowView` uses `Label(type.title, systemImage: type.symbolName)` on the Toggle** so each reminder type has its icon displayed inline alongside the text — consistent with iOS Settings style.
