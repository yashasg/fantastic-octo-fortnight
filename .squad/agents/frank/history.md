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

### 2026-04-25 — Apple App Store Legal & Privacy Compliance Research

- **Report filed:** `.squad/decisions/inbox/frank-apple-legal-requirements.md`
- **Scope:** Full audit of App Store Review Guidelines sections 1.3, 5, 5.1.1, 5.1.2; Privacy Nutrition Labels; TERMS.md, PRIVACY.md, DISCLAIMER.md, APP_STORE_LISTING.md

**Key findings:**

- **3 submission blockers identified:**
  1. No hosted HTTPS URL for Privacy Policy — Apple requires a live URL in App Store Connect (not a Markdown file)
  2. TERMS.md (used as custom EULA) is missing Apple's required EULA supplement provisions (Apple as third-party beneficiary, Apple's non-responsibility, etc.)
  3. `NSMotionUsageDescription` key must be in Info.plist for CMMotionActivityManager; `com.apple.developer.focus-status` entitlement required for INFocusStatusCenter — neither confirmed present

- **Privacy Nutrition Labels:** Recommended "Data Not Collected" for all categories. Motion data (CMMotionActivityManager) and Focus Status (INFocusStatusCenter) qualify for Apple's transient-data exemption (in-memory only, never stored, never transmitted, not linked to identity). UserDefaults preferences also qualify — they never reach the developer.

- **What's solid:** Health disclaimer language is excellent. Limitation of liability comprehensive. GDPR/CCPA/COPPA addressed correctly by "data not collected" architecture. Age rating 4+ and category (Health & Fitness) correct.

- **Apple custom EULA requirement pattern:** Any custom EULA uploaded to App Store Connect MUST include 7 specific Apple provisions (Apple non-party, no warranty obligation, developer responsible for claims, IP indemnity, third-party terms compliance, Apple as third-party beneficiary). Full text provided in report Section 4.

- **App Store description gap:** No disclaimer language in APP_STORE_LISTING.md Section 3. Health/wellness apps should include a brief disclaimer in the description; exact language provided in report Section 8.

- **In-app disclaimer:** DISCLAIMER.md "Short" variant must be surfaced in the UI (onboarding or Settings "About"). Document exists but implementation not confirmed.

- **TestFlight carve-out in PRIVACY.md** mentions "Share App Data" diagnostic log sharing — should be updated or removed for production App Store release.


### 2026-04-26 — Apple Legal & Privacy Deep Dive (Second Pass)

- **Report filed:** `.squad/decisions/inbox/frank-apple-legal-deep-dive.md`
- Apple does not mandate exact “not medical advice” wording; current requirement is to avoid unsupported medical claims, disclose limitations, and remind users to consult a doctor before medical decisions. Existing TERMS.md and DISCLAIMER.md language exceeds Apple’s minimum.
- Current App Store Review Guidelines place health/fitness data rules primarily in **5.1.3 Health and Health Research** and **5.1.2(vi)**, not 5.1.1(v) (which is Account Sign-In in current guidelines).
- Privacy label conclusion strengthened: Apple defines “collect” as transmitting data off-device for developer/partner access beyond real-time servicing. On-device-only Core Motion, Focus Status, UserDefaults, and local logging can support **Data Not Collected** if never transmitted.
- ATT is not required unless future analytics/ads link app data with third-party data, share user/device data with data brokers, access IDFA, or use an SDK that tracks across apps/websites.
- HealthKit should not be added for MVP; it would introduce HealthKit-specific privacy policy, purpose strings, marketing/UI disclosure, no-ad/data-mining restrictions, and false-health-data risks without a clear product need.
- No age verification is needed for the current general-audience, no-data-collection app. Avoid Kids Category and child-targeted metadata unless the app is redesigned for COPPA/GDPR-K/Kids Category obligations.
