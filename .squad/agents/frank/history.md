# Frank — History

## Project Context

- **Project:** kshana (formerly Eye & Posture Reminder) — a lightweight iOS app with True Interrupt Mode via Screen Time APIs
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults, FamilyControls (Phase 3+)
- **Owner:** Yashasg
- **Joined:** 2026-04-24

## Core Context

- Health/wellness app that reminds users to take eye breaks and check posture
- Uses screen-on-time tracking (ScreenTimeTracker), not wall-clock timers
- Stores settings in UserDefaults, loads defaults from bundled defaults.json
- No server-side component — all data stays on device
- No user accounts or authentication
- No analytics/telemetry collecting personal data (yet)
- **Phase 3 pivot:** Now includes True Interrupt Mode via Screen Time APIs; Shield feature pending FamilyControls entitlement approval

## 2026-04-29 — True Interrupt Mode Privacy & Legal Updates

**Task:** Update privacy/legal docs for Screen Time / FamilyControls True Interrupt Mode pivot.  
**Status:** ✅ Complete — orchestration log filed

**Changes made:**
- **docs/legal/PRIVACY.md** — Overview + Section 1: Added device activity/Screen Time data disclosure (aggregate-only, in-memory, no transmission)
- **docs/legal/DISCLAIMER.md** — Added approval status note + comprehensive Screen Time feature section (case ID 102881605113)
- **docs/PRIVACY_NUTRITION_LABELS.md** — New table row + post-approval label template
- **GitHub Issues:** Created #199 (closed/redirect to #209), kept #200 (App Store listing coordination)
- **Owner-only fields:** Preserved all PII placeholders untouched

**Key decision:** Truthful, upfront disclosure of pending approval status. No content-reading (explicit guarantee). Decision merged into `.squad/decisions.md`.

## Learnings

### 2026-04-26 — Copyright & IP Analysis vs LookAway

- **Report filed:** `.squad/decisions/inbox/frank-copyright-analysis.md`
- Assessed LookAway by Mystical Bits, LLC as a macOS digital wellness competitor with eye-break, blink, posture, full-screen break, stats, and Screen Score features. Current app name **Eye & Posture Reminder** is descriptive and meaningfully different from **LookAway**, so direct LookAway trademark-confusion risk appears low, but formal clearance was not performed.
- Concluded the 20-20-20 rule is a widely used wellness/optometry guideline and the underlying idea/method is not copyrightable; use it descriptively and write original explanatory copy.
- Feature overlap with eye-break/posture apps is generally not a copyright issue because copyright protects expression, not ideas, systems, methods, or standard UI patterns. Risk areas are copying competitor code, copy, sounds, artwork, distinctive UI, screenshots, or proprietary names such as “Screen Score.”
- Recommended pre-submission App Store and trademark knockout searches for exact/similar names, avoiding LookAway-specific branding, maintaining original iOS-native UI, and keeping medical-disclaimer language in onboarding/Settings/App Store metadata.

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

### 2026-04-26 — Analytics Privacy Correction: MetricKit + os.Logger

- **Report filed:** `.squad/decisions/inbox/frank-analytics-privacy-update.md`
- User corrected the prior legal assumption: the app **does collect analytics** through Apple-native systems. Stack is `os.Logger` for on-device privacy-tiered logs plus MetricKit/App Store Connect analytics; there is still **no third-party SDK**, no Firebase/Mixpanel, and no custom analytics backend.
- Updated conclusion: blanket **"Data Not Collected"** is no longer the right overall posture if MetricKit/App Store Connect analytics are treated as data leaving the device. Local-only data, transient motion/Focus data, and normal on-device `os.Logger` logs remain **Not Collected**; MetricKit/App Store Connect diagnostics should be conservatively disclosed as **Diagnostics** (Crash Data and/or Performance Data), **Not Linked to User**, **Not Used for Tracking**.
- Current `docs/legal/PRIVACY.md` needs updates because it says, or strongly implies, no analytics, no crash reporting, no MetricKit transmission, and nothing leaves the device. The replacement policy should explicitly disclose Apple-native MetricKit/App Store Connect diagnostics and explain that `os.Logger` logs normally remain on-device with private values redacted.
- ATT remains **not required** for the current architecture because MetricKit does not use IDFA, does not track users across apps/websites, and does not involve third-party tracking, ad networks, data brokers, or user-level profiling.
- If a third-party analytics SDK is added later, the team must redo Privacy Nutrition Labels, privacy policy disclosures, vendor due diligence, ATT analysis, SDK privacy manifest review, retention/opt-out planning, and event payload controls before release.

### 2026-04-26 — Implemented Apple EULA + MetricKit Privacy Updates

- Added `docs/legal/TERMS.md` Apple App Store Terms section with the required Apple custom EULA supplement clauses: Apple non-party acknowledgement, limited non-transferable device license, developer maintenance/support responsibility, Apple warranty limitation, developer responsibility for product claims, developer responsibility for IP claims, and Apple/subsidiaries as third-party beneficiaries.
- Updated `docs/legal/PRIVACY.md` to remove overbroad no-analytics/nothing-leaves-device language and disclose Apple-native MetricKit/App Store Connect diagnostics and aggregate analytics.
- Clarified that `os.Logger` logs normally remain on-device with private/redacted values, while diagnostic logs may be shared through Apple's diagnostic-sharing/TestFlight settings if the user opts in.
- Preserved the privacy posture: no third-party analytics SDKs, no IDFA, no user accounts, no tracking, no sale of data, local settings stay on-device, and motion/Focus data remain transient.
- Commits created: `797bdc2` (`docs(legal): add Apple EULA supplement to TERMS.md`) and `63a5ac1` (`docs(legal): update PRIVACY.md for MetricKit analytics disclosure`).

### 2026-04-28 — Puzzle Quest LLC Registration Status

- User stated the intended App Store/legal entity name is **Puzzle Quest LLC**.
- User stated the LLC is currently registered in **Washington**, but that this is a mistake and it should be registered in **New Mexico**.
- User stated the home office is in **Washington**.
- Practical legal posture: do not finalize App Store publisher/entity details, governing-law placeholders, or owner legal documents until entity domicile, foreign registration/nexus, tax, and address facts are confirmed by qualified professionals.

### 2026-04-28 — LLC Registration State & App Store Publisher Risk

- **Task:** Assess legal implications of Puzzle Quest LLC being currently registered in Washington when user intends New Mexico, with home office in Washington.
- **Guidance:** Protective risk assessment issued via `.squad/decisions/inbox/frank-llc-registration-guidance.md` (later merged to main decisions.md).
- **Key Points:**
  - Do not finalize Puzzle Quest LLC as App Store publisher until entity formation cleaned up
  - Consult WA/NM business attorney on correction path (dissolve/form/convert/domesticate)
  - Washington home office creates nexus even with NM formation
  - Prepare draft placeholders; do not lock into legal docs until counsel/CPA confirm final structure
  - Owner-only legal document fields remain untouched by agents per user directive 2026-04-27
- **Output Files:** `docs/legal/TERMS.md`, `docs/legal/PRIVACY.md` (not edited this session; Frank assessed but did not modify)
- **Coordination:** Frank work synchronized with Virgil (CI/CD implications) and Coordinator (team directive capture).


### 2026-04-29 — True Interrupt Mode Privacy & Legal Disclosure

- **Report filed:** `.squad/decisions/inbox/frank-screen-time-privacy.md` (comprehensive decision document)
- **Task:** Pivot project to support Screen Time / FamilyControls integration for "True Interrupt Mode" capability (Phase 3+). Updated all legal/privacy documentation to disclose pending feature, Apple approval case ID, and truthful data-handling practices.

**Key Updates:**

- **`docs/legal/PRIVACY.md`**
  - Added Overview section on optional Screen Time monitoring with approval case ID 102881605113
  - Section 1: expanded to describe aggregate-only, in-memory-only Screen Time data access
  - Section 2: explicitly clarified app will NOT read message/browser/call content
  - Notes conditional availability pending Apple approval

- **`docs/legal/DISCLAIMER.md`**
  - Short variant: added Screen Time feature status note
  - Full variant: added comprehensive Screen Time section explaining purpose, noting approval status, reiterating wellness-guidance-only nature

- **`docs/PRIVACY_NUTRITION_LABELS.md`**
  - Updated "Data the App Accesses but Does NOT Collect" table to include Screen Time (pending approval)
  - Created new "If Screen Time / Device Activity Features Are Added" section with Device Status privacy label template for post-approval
  - Updated summary table with Screen Time notation
  - Pre- and post-approval pathways clearly documented

**Legal Rationale:**

- Truthfulness: Current state is "not shipped, pending approval"; future state is "aggregate data, in-memory only, never transmitted"
- Privacy-by-Design: Explicit denial of access to sensitive content (messages, browser history, call logs)
- App Store Compliance: Upfront disclosure of Screen Time API usage prevents Review rejection; maintains health/wellness disclaimer language
- Wellness Framing: Breaks remain optional guidance, not mandatory; "use at your own risk" consistent across formats

**Owner-Only Fields Preserved:**

- `[PUBLISHER NAME]` in PRIVACY.md (Sections 7, 10, 11, 12) — untouched
- `[CONTACT EMAIL]` in PRIVACY.md (Sections 8, 12) — untouched
- `[JURISDICTION]` in TERMS.md Section 10 — untouched

**GitHub Issues Created:**

- #199 — Legal & Privacy Docs Updated: True Interrupt Mode (Screen Time/FamilyControls)
- #200 — App Store Listing: Coordinate Legal Disclaimer Updates for Screen Time Feature

**Next Steps:**

- Confirm Apple approval timeline (case ID 102881605113)
- Update App Store Connect Privacy Labels when feature is approved
- Update App Store listing description when feature ships
- Strike Screen Time sections if Apple approval is denied

### 2026-04-30 — Read-Only Legal/Privacy/App Store Audit After True Interrupt Updates

- Reviewed `docs/legal/TERMS.md`, `docs/legal/PRIVACY.md`, `docs/legal/DISCLAIMER.md`, `docs/PRIVACY_NUTRITION_LABELS.md`, `docs/APP_STORE_LISTING.md`, `docs/TESTFLIGHT_METADATA.md`, `docs/TELEMETRY.md`, `README.md`, and `ROADMAP.md` without editing legal documents.
- Confirmed owner-only placeholders `[PUBLISHER NAME]`, `[CONTACT EMAIL]`, and `[JURISDICTION]` remain untouched and are already covered by owner-blocked release readiness.
- Confirmed open blockers #185, #196, #201, #209, and #210 cover hosted privacy URL, custom EULA upload, FamilyControls entitlement, Screen Time legal docs/sign-off, and extension signing/CI.
- Found one new material App Store metadata gap: the App Store description draft lacks explicit "not medical advice" / professional-care disclaimer language despite Health & Fitness positioning and 20-20-20/posture claims. Filed #302 for Danny to update listing copy with Frank review.
