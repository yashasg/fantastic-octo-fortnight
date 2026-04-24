# Work Routing

How to decide who handles what.

## Routing Table

| Work Type | Route To | Examples |
|-----------|----------|----------|
| Product roadmap, priorities, scope | Danny | Feature prioritization, user stories, phased delivery |
| UI/UX design, screens, accessibility | Tess | Screen layouts, design system, SF Symbols, VoiceOver |
| User flows, experience strategy | Reuben | Journey maps, onboarding, information architecture |
| Architecture, technical decisions | Rusty | MVVM structure, API design, module integration |
| SwiftUI views, overlays, animations | Linus | SettingsView, OverlayView, UIKit bridging |
| Notifications, persistence, lifecycle | Basher | ReminderScheduler, SettingsStore, AppDelegate |
| Testing | Livingston | Unit tests, UI tests, edge cases, mock setup |
| Code review | Saul | Review PRs, check quality, suggest improvements |
| Scope & priorities | Danny | What to build next, trade-offs, decisions |
| Session logging | Scribe | Automatic — never needs routing |

## Issue Routing

| Label | Action | Who |
|-------|--------|-----|
| `squad` | Triage: analyze issue, assign `squad:{member}` label | Lead |
| `squad:{name}` | Pick up issue and complete the work | Named member |

### How Issue Assignment Works

1. When a GitHub issue gets the `squad` label, the **Lead** triages it — analyzing content, assigning the right `squad:{member}` label, and commenting with triage notes.
2. When a `squad:{member}` label is applied, that member picks up the issue in their next session.
3. Members can reassign by removing their label and adding another member's label.
4. The `squad` label is the "inbox" — untriaged issues waiting for Lead review.

## Rules

1. **Eager by default** — spawn all agents who could usefully start work, including anticipatory downstream work.
2. **Scribe always runs** after substantial work, always as `mode: "background"`. Never blocks.
3. **Quick facts → coordinator answers directly.** Don't spawn an agent for "what port does the server run on?"
4. **When two agents could handle it**, pick the one whose domain is the primary concern.
5. **"Team, ..." → fan-out.** Spawn all relevant agents in parallel as `mode: "background"`.
6. **Anticipate downstream work.** If a feature is being built, spawn the tester to write test cases from requirements simultaneously.
7. **Issue-labeled work** — when a `squad:{member}` label is applied to an issue, route to that member. The Lead handles all `squad` (base label) triage.
