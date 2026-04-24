# Eye & Posture Reminder – iOS App

A lightweight iOS app that runs in the background and reminds you to rest your eyes and fix your posture. Built exclusively with core iOS libraries (SwiftUI, UserNotifications, UIKit) to minimise battery and memory usage.

## Features

- 👁 **Eye-rest reminders** – configurable interval and break duration (e.g. 20-20-20 rule)
- 🧍 **Posture reminders** – configurable interval and break duration
- Full-screen dismissible overlay with countdown timer
- Dropdown pickers for reminder interval and break length
- Battery-efficient background scheduling via `UNUserNotificationCenter`

## Implementation Plan

See **[IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)** for the full architecture, design decisions, file structure, data flow, and phased delivery plan.