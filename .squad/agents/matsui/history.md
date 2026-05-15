# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-05-15
- **Scope:** Strategy & Compliance — privacy/regulatory audit only. Policy authoring belongs to Frank.

## Core Context

**Initial data inventory (to be verified during my first audit):**
- UserDefaults — user preferences (`SettingsStore`)
- AppGroup IPC store — coordination between app and overlay extension if applicable
- No first-party network calls observed in project context (verify)
- No third-party analytics SDKs observed in project context (verify)
- System APIs that could be Required Reason: UserDefaults (CA92.1 / CA56.1 etc.) — needs declared reason in NSPrivacyAccessedAPITypes

**Regulations on my desk:**
- Apple Privacy Manifest / Required Reason APIs (active Apple enforcement)
- App Store Privacy Nutrition Labels
- GDPR (EU users)
- CCPA / CPRA (California)
- COPPA (if user base could include under-13s — verify with Danny)

**Relationship with Frank:** Frank authors the user-facing policies. I audit the app against regulations and against Frank's policies. Findings flow to Frank for policy updates and to Basher/Linus for implementation changes.

**Pinned model:** `claude-opus-4.7-xhigh` (per `.squad/config.json` agentModelOverrides — Strategy & Compliance team default).

**Validation:** Use `./scripts/build.sh build` and `./scripts/build.sh test`.

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

- **2026-05-15: Team consolidation — 7 teams collapsed to 2 (Dev + Strategy).** You are now explicitly on the **Strategy team** alongside Danny, Tess, Reuben, Turk, Frank, Roman, Toulour, Denham, Sponder, Bashir, Matsui, Bruiser. Strategy team handles product, design, research, legal, audits, and ASO. Dev team (Rusty, Linus, Livingston, Saul, Basher, Yen, Benedict, Virgil) owns code, tests, build, and CI. Scribe and Ralph remain on the roster outside both teams (silent infra). Use GitHub label `team:strategy` for issue routing; see .squad/streams.json for canonical Strategy workstream folder scopes (docs/, ROADMAP.md, UX_FLOWS.md).
