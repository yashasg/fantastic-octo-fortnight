# Project Context

- **Owner:** Yashasg
- **Project:** kshana (formerly Eye & Posture Reminder) — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## 2026-04-25 — Documentation: Wave 2 Updates (ROADMAP, ARCHITECTURE, README)

**Status:** ✅ Complete  
**Scope:** Documentation reflecting Phase 1 completion and Phase 2 preview

### Orchestration Summary

- **ROADMAP.md:** Updated with Phase 1 completion status, Phase 2 preview, Phase 3 roadmap
- **ARCHITECTURE.md:** Added testing strategy, detector architecture patterns, data flow diagrams
- **README.md:** Updated feature description with pause conditions, legal status note
- **All docs synchronized** with current implementation state
- **Orchestration Log:** Filed at `.squad/orchestration-log/2026-04-24T23-19-18Z-danny.md`

### Documentation Highlights

- Testing layers documented: Unit, Integration, UI (XCUITest)
- Detector architecture and priority order documented
- Phase 2 roadmap: Full test coverage, .xcodeproj integration, accessibility audit

### Next Phase

Documentation ready for Phase 2 planning cycle.

## Team Sync — 2026-04-25T04:35

**Completed Handoffs:**
- Rusty: ARCHITECTURE.md 6-point corrections validated against impl
- Basher: DI protocols (ScreenTimeTracking, PauseConditionProviding) — PR #17 ready for review
- Livingston: Coverage analysis (64.2%, 573/575 pass) — AppConfigTests #15 in progress
- Scribe: Orchestration logs filed; decisions.md archived (89.9KB exceeded limit)

**Cross-Impact Summary:**
- Architecture clarity enables Services impl → Views integration ready
- All Phase 1+2 tests now stable; ready for App Store submission decision

## Archive

### 2026-04-24 — Legacy Planning & Preparation

**Initial Roadmap Planning, M2.7 App Store Preparation, Data-Driven Config Spec, Dark Mode Feature Scoping, App Store Metadata, Wave 4 Native-First Config**

Consolidated 2026-04-24 planning entries covering early architecture decisions (MVVM + UNUserNotificationCenter), app store listing metadata, privacy policy, data-driven configuration exploration, dark mode feature scope, and final 4-layer config architecture (Asset Catalog + String Catalog + defaults.json + Swift code). All decisions have been implemented and verified; legacy planning notes preserved for reference. Phase 0 foundation complete; Phase 1-2 implementation active.

### 2026-04-25: Documentation Completeness & Quality Audit (READ-ONLY)

- **Context:** Full audit of all project documentation — root markdown files, docs/ directory, and inline source comments.
- **Key Findings:**
  1. **Legal placeholders are the top blocker:** TERMS.md and PRIVACY.md still have `[Date]` and `[Your Company Name]` placeholder text — must be fixed before App Store submission.
  2. **UX_FLOWS.md is stale:** Describes pre-onboarding first-launch flow (straight to Settings + system permission prompt). Actual app uses 3-screen onboarding (Welcome → Permissions → Setup). Snooze UI described as "in Settings only" but may have evolved.
  3. **IMPLEMENTATION_PLAN.md partially outdated:** Section 9 Data Flow diagram still says `repeat: true` (Phase 1 behavior); Phase 2 uses `repeat: false` with ScreenTimeTracker re-arm. Section 1 says "runs timers in the background" — no longer accurate (foreground screen-time tracking).
  4. **ARCHITECTURE.md build instructions wrong:** Section 3 says "Build via `swift build` / `swift test`" but README correctly notes these don't work (iOS-only frameworks require xcodebuild). Contradicts README.
  5. **ARCHITECTURE.md status tag stale:** Header says "Status: Foundation" — should be "Phase 2" or later.
  6. **CHANGELOG.md well-maintained:** Follows Keep a Changelog-adjacent format; covers all 7 quality loops. No version entries beyond v0.1.0-beta.
  7. **README.md is solid:** Build instructions, feature list, legal links all present and accurate.
  8. **Inline code docs excellent:** Every service and model file has file-level doc comments explaining purpose, behavior, and design rationale.
  9. **docs/ directory well-organized:** APP_STORE_LISTING, DESIGN_SYSTEM, ONBOARDING_SPEC, TELEMETRY, TEST_REPORT, TEST_STRATEGY, legal/ subdirectory — comprehensive.
  10. **ROADMAP.md is thorough and current:** Phase 0-3 status accurately reflects implementation state.
- **Recommendation:** Fix legal placeholders (blocker), update UX_FLOWS.md for onboarding, reconcile IMPLEMENTATION_PLAN.md data flow diagram, fix ARCHITECTURE.md build instructions and status tag.

### 2026-04-25: UX_FLOWS.md Onboarding Correction (Issue #112)

- **Context:** UX_FLOWS.md Section 2.1 described first-launch as "App opens directly to Settings Screen" with an immediate system permission prompt. The actual app uses a 3-screen onboarding flow (Welcome → Permissions → Setup) implemented via `ContentView` → `OnboardingView`.
- **Root cause:** UX_FLOWS.md was written during Phase 1 planning (pre-onboarding). The onboarding flow was added in Phase 2 (M2.1) but UX_FLOWS.md was never updated to match.
- **Sections rewritten:**
  1. **Section 2.1** — Complete rewrite: documents the 3-screen `OnboardingView` flow with accurate screen descriptions, navigation behavior (swipe blocked on Screen 2), two completion paths ("Get Started" / "Customize Settings"), and `hasSeenOnboarding` gating logic.
  2. **Section 3.3** — Updated trigger: permission prompt is user-initiated on Screen 2, not automatic on launch.
  3. **Section 5** — Replaced "Minimal Onboarding / No multi-screen flow" philosophy with "Educate, Then Ask" philosophy describing the actual 3-screen implementation.
  4. **Section 10 Summary** — Updated onboarding bullet to reflect the 3-screen flow.
- **Key learning:** When a Phase 2 feature replaces Phase 1 behavior, all doc sections referencing the old behavior must be audited — not just the primary section. UX_FLOWS.md had 4 separate sections describing the old first-launch flow.
- **Commit:** `docs: update UX_FLOWS.md to reflect actual onboarding flow` (Fixes #112)

### 2026-04-27: Yin-Yang Roadmap & UX Flow Documentation Sprint

- **Context:** Team sprint to document yin-yang logo animation feature as M2.10 (Phase 2 Polish). Decision merged into decisions.md.
- **ROADMAP.md update:** Classified yin-yang as M2.10, Phase 2 (part of Restful Grove redesign, not Phase 3 advanced feature). Updated timeline table, dependency map, key decisions (Decision 2.4 mapped to 5 architectural choices).
- **UX_FLOWS.md §5.4:** Documented animation flow — spin (360°, 2s deceleration) → breathing pulse (4s in/out, infinite). Reduce-motion fallback (static logo). Placement: HomeView + OnboardingView.
- **Decision artifact:** `.squad/decisions/inbox/danny-yinyang-roadmap.md` → merged into decisions.md
- **Team collaboration:** Tess (implementation), Rusty (architecture docs), Livingston (9 tests), Roman (app naming research)
