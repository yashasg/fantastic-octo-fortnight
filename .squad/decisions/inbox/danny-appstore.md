# Decision: App Store Listing & Identity Choices (M2.7)
**Author:** Danny (Product Manager)  
**Date:** 2026-04-24  
**Status:** Proposed

## Decisions Made

### Decision 1: App name — "Eye & Posture Reminder"
- Kept the working title as the final App Store name
- Rationale: Descriptive, keyword-rich, immediately communicates value. Apple's search algorithm favors clarity. Alternatives like "ScreenBreak" or "GentleBreak" are catchier but sacrifice discoverability.
- Impact: Bundle ID should align (e.g., `com.yashasg.eye-posture-reminder`)

### Decision 2: Privacy policy — zero-collection stance
- Documented that the app collects no data, makes no network calls, uses no third-party SDKs
- Rationale: Honest and accurate for current state. Simplifies App Store review.
- Commitment: If analytics or telemetry are added in future phases, privacy policy must be updated BEFORE those features ship, and users notified via release notes

### Decision 3: App Store category — Health & Fitness (primary)
- Primary: Health & Fitness; Secondary: Productivity
- Rationale: Core value is health (eye care, posture). Productivity is secondary benefit.
- Impact: Affects which category charts the app appears in

### Decision 4: Version scheme — v0.1.0-beta for TestFlight
- Initial TestFlight submission as v0.1.0 (not v1.0)
- Rationale: Beta testing phase. v1.0 reserved for public App Store release after beta feedback incorporated.

## Open Items Requiring Team Input
- **Bundle ID:** Needs confirmation before App Store Connect setup
- **Support URL:** Needs landing page or GitHub repo link
- **Copyright holder:** Using "Yashasg" — confirm if different entity needed
