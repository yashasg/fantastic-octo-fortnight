# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-05-15
- **Scope:** Strategy & Compliance — App Store Connect listing optimization only. No production code.

## Core Context

**App Store Connect surfaces I own:**
- App name (30 chars), subtitle (30 chars), keywords field (100 chars, comma-separated), promotional text (170 chars), description (4000 chars)
- Primary + secondary category
- Screenshot set per device class (6.5" / 6.1" / 5.5" / iPad if applicable)
- App Preview videos (when used)
- Localized listings per locale

**Initial position (to verify):**
- Single-locale listing (English) — expansion candidates depend on Roman/Bashir keyword work
- Free app, no IAP/subscription declared (verify with Danny)
- Pricing tier and category declarations to be confirmed during first audit pass

**Inputs I depend on:**
- Bashir for category-narrow keyword research
- Roman for broader market context
- Matsui for privacy nutrition label coordination
- Denham for App Review Section 4 listing-asset compliance

**Pinned model:** `claude-opus-4.7-xhigh` (per `.squad/config.json` agentModelOverrides — Strategy & Compliance team default).

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

- **2026-05-15: Team consolidation — 7 teams collapsed to 2 (Dev + Strategy).** You are now explicitly on the **Strategy team** alongside Danny, Tess, Reuben, Turk, Frank, Roman, Toulour, Denham, Sponder, Bashir, Matsui, Bruiser. Strategy team handles product, design, research, legal, audits, and ASO. Dev team (Rusty, Linus, Livingston, Saul, Basher, Yen, Benedict, Virgil) owns code, tests, build, and CI. Scribe and Ralph remain on the roster outside both teams (silent infra). Use GitHub label `team:strategy` for issue routing; see .squad/streams.json for canonical Strategy workstream folder scopes (docs/, ROADMAP.md, UX_FLOWS.md).
