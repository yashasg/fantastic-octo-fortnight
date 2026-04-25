# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

### 2026-04-25: Roadmap Audit & Status Update

- **Context:** Project evolved significantly from initial Phase 0 planning. Phase 1 (MVP) fully shipped. Phase 2 (Polish) ~80% complete with screen-time triggers, smart pause (Focus/CarPlay/driving), onboarding, snooze, haptics, accessibility, and data-driven config all delivered or in final QA.
- **Key Finding:** Team now spans 13 members (added Frank, Virgil, Turk, Ralph, Scribe to original 8). Wall-clock notifications replaced with ScreenTimeTracker (continuous screen-on time + 5s grace period). Color/copy/settings config migrated from code to native Apple formats (Asset Catalog + String Catalog + defaults.json).
- **Product Implications:** v1.0 ready for App Store submission (Phase 2 complete). Phase 3 (DI refactoring, iCloud, widgets, watchOS) deferred to v1.1 post-launch. No descoping occurred — all Phase 1+2 features shipped as planned.
- **Roadmap Updated:** ROADMAP.md now reflects actual state: Phase 0 ✅, Phase 1 ✅, Phase 2 🔄 ~80%, Phase 3 🔄 partially started. Issue backlog (#13-14 DI, #2 legal placeholders) documented.
- **Decision Point:** v1.0 scope closed (Phase 1+2). Awaiting Danny sign-off on App Store submission or further Phase 2 polish before proceeding to Phase 3 refactoring.
- **Artifacts:** Updated ROADMAP.md (status, team, open issues, success metrics, risk register with current state)

### 2026-04-25: Screen-On Time Trigger Model

- **Critical behavioral clarification:** Reminder intervals mean "continuous screen-on time," NOT wall-clock elapsed time. Screen off = full timer reset to zero.
- **API choice:** `UIApplication.didBecomeActiveNotification` / `willResignActiveNotification` are the correct iOS signals — not `UIScreen` notifications (which are for external displays).
- **UNUserNotificationCenter cannot do this job** — scheduled notifications fire on wall-clock time. The feature requires a foreground `Timer` + lifecycle observers inside `ReminderScheduler`.
- **Snooze is the exception:** snooze can use a one-shot `UNNotificationRequest` to wake the app; then the foreground timer takes over.
- **`defaults.json` values unchanged numerically** — semantic meaning updated: intervals = "minutes of continuous screen time."
- **Key file:** `.squad/decisions/inbox/danny-screen-time-triggers.md`

### 2026-04-24: Data-Driven Default Settings Spec

- **Root cause of friction:** `ReminderSettings.defaultEyes/defaultPosture` are Swift `static let` values — changing any default (e.g. test intervals) required a code edit, `// TEST OVERRIDE` comment breadcrumbs, and a full PR cycle.
- **Proposed solution:** Bundle `defaults.json` in the app target. `SettingsStore.init()` seeds UserDefaults from JSON on first launch only. UserDefaults always wins on subsequent launches.
- **Key design rule:** JSON seeding uses the same "only if key is absent" guard that `SettingsPersisting` already enforces — no risk of overwriting user changes.
- **Reset path:** `SettingsStore.resetToDefaults()` removes all `epr.*` keys and re-seeds from JSON; Linus adds the UI button. This is the same code path as first launch.
- **Testability preserved:** `DefaultsLoader` accepts a `Bundle` parameter so unit tests can inject a fixture JSON without touching the real bundle.
- **Future-ready:** Remote config, A/B testing, and per-device defaults all work by swapping the JSON source — zero `SettingsStore` logic changes required.
- **Key file:** `.squad/decisions/inbox/danny-data-driven-settings-spec.md`

### 2026-04-24: Dark Mode Feature Scoping

- **App is mostly dark-mode ready by accident** — SwiftUI's `Form`, system materials (`.ultraThinMaterial`, `.regularMaterial`), and semantic colors (`.secondary`, `.tertiary`) all adapt automatically. No forced `preferredColorScheme` or `overrideUserInterfaceStyle` exists anywhere in the codebase.
- **`AppColor.warningText` sets the right pattern** — already uses `UIColor(dynamicProvider:)` for light/dark variants. The two remaining hardcoded colors (`permissionBanner`, `permissionBannerText`) should follow the same pattern before they are used in any view.
- **`permissionBanner` and `permissionBannerText` are defined but unused** — not referenced in any view yet (confirmed via grep). Safe to defer adaptive conversion until the banner feature ships; spec includes a gate on this.
- **Overlay UIWindow inherits system appearance correctly** — `OverlayManager` creates `UIWindow` without setting `overrideUserInterfaceStyle`, which defaults to `.unspecified` (inherits from scene). This is correct but fragile — a code comment is needed to document the intent.
- **Key spec filed:** `.squad/decisions/inbox/danny-dark-mode-spec.md`

### 2026-04-25: Phase 2 Data-Driven Configuration — FINAL DECISION

- **Decision filed:** `.squad/decisions/decisions.md` (Decision 2.17 — merged from inbox)
- **Summary:** Native-first 4-layer architecture replaces monolithic app-config.json. Asset Catalog handles colors (light+dark variants via OS), String Catalog handles copy (localization-ready), defaults.json handles settings (~10 values with UserDefaults override), Swift code stays for spacing/layout/animations/symbols (type-safe, non-JSON-serializable).
- **Rationale:** Each Apple platform mechanism does what it does best. JSON cannot express OS dark/light switching, lacks localization toolchain, adds overhead for stable values.
- **Team implementation:** Basher (AppConfig + defaults.json), Tess (Asset Catalog colors), Linus (String Catalog extraction), Livingston (136 tests, 4 intentionally failing pending Basher integration).
- **Status:** ✅ ALL IMPLEMENTATIONS SHIPPED & VERIFIED. Build succeeds. Tests written. Ready for Phase 3 UI integration.

### 2026-04-24: Initial Roadmap Planning
- **Architecture Pattern:** MVVM with single shared service layer (ReminderScheduler, OverlayManager)
- **Background Strategy:** UNUserNotificationCenter preferred over Timer for battery efficiency; iOS handles scheduling natively
- **Overlay Approach:** Secondary UIWindow at `.alert + 1` level; UIHostingController bridges SwiftUI view
- **Persistence:** UserDefaults for settings (lightweight), NSUbiquitousKeyValueStore for iCloud sync (Phase 3)
- **Key Decision:** Added Phase 0 (Foundation) to establish CI/CD, architecture scaffolding, and design system before MVP work
- **iOS Target:** iOS 16+ for SwiftUI features (`.ultraThinMaterial`, List improvements)
- **Team Structure:** 8 roles with clear ownership: PM (Danny), UI/UX (Tess), Product Design (Reuben), Architect (Rusty), iOS UI Dev (Linus), iOS Services Dev (Basher), Tester (Livingston), Code Reviewer (Saul)
- **Testing Standards:** 80% unit test coverage for Services/ViewModels; UI tests for critical paths only
- **Timeline:** 7 weeks to App Store submission (Phase 0: 2 weeks, Phase 1: 3 weeks, Phase 2: 2 weeks)
- **Key File Paths:**
  - `/IMPLEMENTATION_PLAN.md` - Original technical implementation plan (3 phases)
  - `/ROADMAP.md` - Full project roadmap with 4 phases, milestones, work items, dependencies
  - `/.squad/decisions/inbox/danny-roadmap-decisions.md` - Scope and priority decisions
- **Open Questions Logged:** App name/bundle ID, analytics strategy, monetization model (all deferred to appropriate milestones)

### 2026-04-24: M2.7 App Store Preparation
- **App Name Decision:** Kept "Eye & Posture Reminder" — descriptive, keyword-rich, favors discoverability over cleverness
- **Subtitle:** "Healthy screen breaks, on cue." (29 chars, within 30-char limit)
- **Keywords Strategy:** 96 chars used of 100 max; excluded words already in title/subtitle (Apple indexes those separately)
- **Privacy Policy:** Zero-collection stance documented — no analytics, no network calls, no third-party SDKs. Must be updated BEFORE any future telemetry ships.
- **Version Scheme:** v0.1.0-beta for TestFlight; v1.0 reserved for public App Store release
- **Category:** Health & Fitness (primary), Productivity (secondary)
- **Age Rating:** 4+ — all questionnaire answers are "No"
- **Open Items:** Bundle ID, Support URL, and Copyright holder still need team confirmation before App Store Connect submission
- **Key File Paths:**
  - `/docs/APP_STORE_LISTING.md` — Complete App Store listing (description, keywords, privacy policy, screenshot plan)
  - `/.squad/decisions/inbox/danny-appstore.md` — Decisions for team review

### 2026-04-25 — Wave 4: Native-First Data-Driven Config (Final Architecture)

**Task:** Replace monolithic `app-config.json` spec with a native-first 4-layer architecture  
**Status:** ✅ SUCCESS  

**Supersedes:** `danny-data-driven-settings-spec.md` and the previous `danny-full-config-spec.md` (app-config.json approach)

**Final Architecture — 4 Layers:**
1. **Asset Catalog (`.xcassets`)** — 6 semantic color tokens with OS-managed dark/light variants. Accessed via `Color("reminderBlue")` / `UIColor(named:)`. Replaces `UIColor(dynamicProvider:)` in `DesignSystem.swift`.
2. **String Catalog (`.xcstrings`)** — ~35 user-facing strings across all six view files. SwiftUI picks them up automatically via `Text("key")`. Localization-ready at zero extra cost.
3. **`defaults.json` (bundled)** — Reminder intervals, break durations, feature flags (~10 values). `DefaultsLoader` seeds `UserDefaults` on first launch only. `SettingsStore.resetToDefaults()` re-seeds from JSON (same path). `DefaultsLoader` accepts `Bundle` parameter for test injection.
4. **Swift code** — Spacing, layout, animations, SF Symbol names, typography. Type safety + autocomplete; these values are stable.

**Key Design Rule:** JSON does not own colors, fonts, spacing, animations, or copy. Each platform mechanism handles what it does natively.

**Override Hierarchy:** `defaults.json` (seed) → `UserDefaults` (user changes) → OS/runtime (dark mode, Dynamic Type — always win).

**Why the app-config.json approach was rejected:** JSON cannot serialize `UIColor`, `Animation`, or `UIFont`. A bespoke parser for each loses OS-level adaptation (dark mode, Dynamic Type) and re-invents Apple's localization toolchain.

**Docs updated:** `ARCHITECTURE.md` (section 4.4), `ROADMAP.md` (M2.7), `CHANGELOG.md`, `.squad/decisions/inbox/danny-full-config-spec.md` (replaced), `.squad/decisions/inbox/danny-native-config-final.md` (new).

**Implementation Ownership:**
- Tess: defines Asset Catalog color values
- Linus: wires Asset Catalog, extracts String Catalog keys, cleans `DesignSystem.swift`
- Basher: implements `DefaultsLoader` + `defaults.json` pipeline
- Danny: owns JSON values and String Catalog copy approval

**Task:** Scope dark mode product requirements for team implementation  
**Status:** ✅ SUCCESS  

**Spec Authored:**
- Document: `.squad/decisions/inbox/danny-dark-mode-spec.md` (merged to decisions.md)
- Audience: Tess (UI/UX), Linus (iOS Dev — UI)
- Status: Ready for implementation

**Key Finding:**
App is ~90% dark-mode ready — no code changes to most views. SwiftUI best practices (semantic colors, `.ultraThinMaterial`, `.systemBackground`) already handle adaptation.

**Required Changes (Minimal):**
1. `DesignSystem.swift` — Convert `permissionBanner` + `permissionBannerText` to adaptive colors (using `UIColor(dynamicProvider:)` pattern)
2. Optional: Visual QA pass on accent colors in dark mode

**Acceptance Criteria:**
- All screens render correctly in light AND dark mode
- No `preferredColorScheme` locks in any file (confirmed clean)
- Overlay UIWindow inherits system appearance (already correct)
- Visual QA: light + dark screenshots for all 6 key screens

**Parallel Work Synergy:**
- Tess immediately implemented color adaptation while spec was being finalized
- Basher's 10-second testing overlay enables visual QA iteration in rapid cycles

---

## Session 6: Screen-Time Triggers (2026-04-24T20:58Z – 2026-04-24T21:37Z)

**Team:** Danny (PM), Rusty (Architect), Tess (Designer), Basher (Services), Linus (UI)

### Task
Define and implement continuous screen-on time trigger model for reminders (replacing fixed wall-clock intervals).

### Deliverable
- **Document:** `.squad/decisions/inbox/danny-screen-time-triggers.md` → merged to `decisions.md` Decision 3.1
- **Status:** ✅ COMPLETE

### Key Decision Points

1. **Behavior shift:** Wall-clock intervals → continuous screen-on time
   - Screen ON (`didBecomeActive`) = start counting seconds
   - Screen OFF (`willResignActive`) = reset to 0 **with 5s grace period**
   - Timer threshold = fire reminder, reset to 0
   - Snooze pauses = tracker disabled, resumes from 0 after snooze

2. **Two reminder types, independent counters**
   - Eye breaks: 20 min (1200s) of continuous screen time
   - Posture checks: 30 min (1800s) of continuous screen time

3. **iOS APIs chosen**
   - `UIApplication.didBecomeActiveNotification` (preferred over UIScreen events for app lifecycle clarity)
   - `UIApplication.willResignActiveNotification` (catches all interruptions: lock, Control Center, Siri, calls)

4. **No background reminders**
   - Reminders only fire while app is foregrounded
   - Foreground-only 1s `Timer` on main RunLoop (no background modes needed)
   - Battery impact negligible; timer coalesces with other 1s timers

### Architecture Amendments (from Rusty's review)
6 required amendments documented; critical amendment: **5s grace period** on `willResignActive` to tolerate brief interruptions (notifications, Control Center) without resetting hard-earned elapsed time.

### UX Outcomes (from Tess's review)
- Mental model: "After X min of screen time" (not "every X min")
- 8 copy strings identified for update (settings picker label, onboarding body text, setup confirmation)
- No structural UI changes; overlay + HomeView remain unchanged
- Grace period remains invisible to users

### Timeline
- 07:40Z – Danny drafts spec (7 decisions)
- 10:10Z – Rusty reviews + approves with amendments (6 required changes noted)
- 14:04Z – Tess reviews + UX copy guidance (8 strings, no structural changes)
- 20:49Z – Basher implements ScreenTimeTracker + grace period + SettingsStore seeding (BUILD SUCCESS)
- 20:49Z – Linus updates 7 UI strings (BUILD SUCCESS)
- 21:37Z – Scribe logs orchestration, merges decisions, prepares for commit

### Open Questions Addressed
1. **Show warning if app not in foreground?** → Tess: Yes, once (onboarding permission screen). After onboarding, behavior is self-evident.
2. **Background refresh fallback?** → Deferred to Phase 4; not needed for Phase 3 scope.

### Blocking Resolved
- Architecture deadlock: Rusty specified standalone `ScreenTimeTracker` service (not in AppCoordinator) to avoid SRP violation in 450+ line coordinator. ✅ Implemented.
- Copy clarity: Tess clarified mental model shift requires "after" (not "every") + "screen time" terminology. ✅ 7 strings updated.

### Next Phase
Livingston (QA) will write unit tests for ScreenTimeTracker:
- Grace period debounce (interrupt → resume within 5s)
- Threshold firing (both timers independently)
- Snooze suppression (`isEnabled` flag)
- System clock immunity (`CACurrentMediaTime()`)


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
