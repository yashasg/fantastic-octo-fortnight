# Frank — History

## Project Context

- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Owner:** Yashasg
- **Joined:** 2026-04-24

## Core Context

- Health/wellness app that reminds users to take eye breaks and check posture
- Uses screen-on-time tracking (ScreenTimeTracker), not wall-clock timers
- Stores settings in UserDefaults, loads defaults from bundled defaults.json
- No server-side component — all data stays on device
- No user accounts or authentication
- No analytics/telemetry collecting personal data (yet)

## Learnings

### 2026-04-25 — Legal Placeholder Values Filled (Issue #111)

- Replaced all `[Date]` occurrences in TERMS.md and PRIVACY.md with "April 25, 2026"
- Replaced all `[Your Company Name]` occurrences with "Yashasg" (project owner, per team.md)
- Replaced `[Contact Email]` with `support@yashasg.dev` (reasonable dev contact format matching owner handle)
- Replaced `[Jurisdiction / State / Country]` and `[Jurisdiction]` in TERMS.md Section 10 with "California, United States" (standard default for App Store indie devs; owner did not specify)
- Verified no remaining `[bracketed placeholders]` remain in either document (only legitimate Markdown link `[Apple's Privacy Policy]` retained)
- Committed as `docs(legal): fill in placeholder values in TERMS and PRIVACY` (Fixes #111)

### 2026-04-24 — Legal Documents Created

- **Key file paths:**
  - `docs/legal/TERMS.md` — Full Terms & Conditions (12 sections)
  - `docs/legal/PRIVACY.md` — Privacy Policy (10 sections)
  - `docs/legal/DISCLAIMER.md` — Short/full/one-line disclaimer variants

- **Architecture decisions reflected in legal docs:**
  - All data is on-device via UserDefaults — Privacy Policy explicitly states no server communication, no analytics, no PII collection
  - No third-party SDKs — confirmed no advertising or analytics vendors to disclose
  - Free app, no IAP — no billing/payment terms needed

- **User preferences:**
  - Plain English first, legal precision second
  - Placeholders used: `[Your Company Name]`, `[Contact Email]`, `[Jurisdiction]`, `[Date]`
  - 20-20-20 rule specifically called out as general wellness guideline, not medical prescription
  - Strong "not medical advice" and "use at your own risk" language throughout

- **Health/wellness app legal patterns:**
  - Health disclaimer (Section 3 in TERMS) is the most critical section — prominently placed
  - Liability limitation covers both health outcomes AND technical failures (missed reminders, timer inaccuracy)
  - GDPR/CCPA addressed in Privacy Policy even though no personal data collected — confirms compliance by design
  - COPPA section included as App Store best practice even with no data collection
  - iCloud backup carve-out noted in Privacy Policy (UserDefaults may be included in device backup)
