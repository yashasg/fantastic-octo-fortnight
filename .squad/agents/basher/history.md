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

