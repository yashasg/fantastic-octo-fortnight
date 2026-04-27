# Roman — History

## Project Context
- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Status:** Ship-ready (build ✅, 857 unit tests ✅, 29 UI tests ✅, legal compliance ✅)
- **Competitors identified:** LookAway (eye break reminders) — Frank assessed copyright risk as LOW
- **Pricing:** Currently planned as free app
- **Key differentiator:** Combines eye breaks AND posture reminders in one app

## Learnings
- No iOS app currently combines eye breaks + posture reminders with screen-time-triggered intelligence — this is our naming and positioning gap to own
- LookAway is Mac-first with iOS as companion only ($19+ paid) — not a direct iOS competitor
- Key ASO terms: "eye break", "posture reminder", "screen time health", "digital wellness", "20-20-20" — subtitle should contain both "eye" and "posture" since no competitor covers both
- App Store subtitle is capped at 30 characters — name itself should be brandable, not keyword-stuffed
- Top name candidates: Restwell (recommended #1), Softsight (#2), Respite (#3) — all have clean trademark landscapes in iOS wellness
- Completed app naming research: `docs/app-naming-research.md` (13 candidates, top 3 with rationale, ASO strategy)

### 2026-04-27: App Name Research & Candidate Documentation

- **Context:** Market research task to identify top app name candidates for the Eye & Posture Reminder.
- **Deliverable:** `docs/app-naming-research.md` — 13 candidates, top 3 recommendations, scoring matrix, ASO strategy.
- **Top 3:** Restwell (warm, memorable, brandable, aligns with Restful Grove aesthetic), Softsight (premium feel, distinctive), Respite (sophisticated, real English word).
- **Decision artifact:** `.squad/decisions/inbox/roman-app-naming.md` → merged into decisions.md
- **Next steps:** Danny (aesthetic fit), Yashas (final preference), Frank (trademark search).
- **Key insight:** No iOS app currently combines eye breaks + posture reminders; naming should emphasize the combined value, not just one function.

### 2025-07-16: "Respite" Name Availability Deep Dive

- **Context:** Yashas expressed preference for "Respite" — conducted comprehensive availability audit across App Store, domains, social, trademark, and ASO.
- **Deliverable:** `docs/respite-name-availability.md` — full report with GO/CAUTION/NO-GO verdict.
- **Verdict:** ⚠️ CAUTION — "Respite: Reduce Screen Time" (by Sean Lim) already exists on iOS App Store in same digital wellness category. Small app (5 ratings, last updated Sep 2023) but creates brand confusion risk.
- **Domain status:** respiteapp.com taken (caregiver service); getrespite.com/respite.app/tryrespite.com status unclear.
- **Social handles:** @respiteapp / @getrespite appear unclaimed on major platforms — should claim immediately if proceeding.
- **Trademark:** "Respite" is a dictionary word — registrable in Class 9 but narrow protection. Attorney consult recommended.
- **ASO:** Name has zero keyword relevance for "eye break" / "posture reminder" — subtitle and keyword field must compensate.
- **Recommendation:** Usable with mitigations, but Restwell remains the cleanest option with no conflicts.
- **Decision artifact:** `.squad/decisions/inbox/roman-respite-availability.md`

### 2026-07-16: Classical Language Name Candidates (Greek/Latin/Roman)

- **Context:** Yashas requested more single-word candidates exploring Greek, Latin, and Roman roots after "Respite" confirmed to have App Store conflicts.
- **Deliverable:** `docs/app-naming-classical.md` — 18 candidates with etymology, pronunciation, App Store checks, and trademark assessment.
- **Top 5:** Lenis (#1, Latin "gentle"), Requies (#2, Latin "rest"), Galene (#3, Greek goddess of calm), Placida (#4, Latin "peaceful"), Levamen (#5, Latin "relief").
- **Key finding:** 8 of 18 candidates have completely clean App Store landscapes — significantly better hit rate than expected for classical words.
- **Decision artifact:** `.squad/decisions/inbox/roman-classical-naming.md`
- **Insight:** Latin words outperform Greek for this app because they are shorter, easier to pronounce for English speakers, and connect to familiar English derivatives (gentle→lenis, alleviate→levamen, placid→placida). Greek names are more distinctive but require pronunciation guidance.
- **Otium warning:** "Otium" (Latin for leisure) is philosophically perfect but has a direct competitor in the App Store ("Otium: Block Apps Easily" — screen time management). Must avoid.

### 2026-07-17: Sanskrit Name Candidates

- **Context:** Yashas requested single-word Sanskrit names to align with the yin-yang / Eastern philosophy aesthetic.
- **Deliverable:** `docs/app-naming-sanskrit.md` — 18 candidates with meanings, pronunciation guides, App Store checks, and ease-of-pronunciation ratings.
- **Top 5:** Samata (#1, "balance/equanimity"), Netra (#2, "eye/guide"), Taraka (#3, "pupil/star"), Achala (#4, "stillness/immovable"), Drishti (#5, "sight/gaze").
- **Key finding:** Popular Sanskrit wellness words (Shanti, Prana, Dhyana, Nidra) are heavily contested on the App Store. Lesser-known words (Samata, Taraka, Achala) are completely clean.
- **Viraam warning:** "Viraam" (Sanskrit for pause) is a near-perfect match but "Viraam: Gentle Break Reminder" already exists on the Mac App Store as a 20-20-20 + posture reminder app — essentially the same product.
- **Decision artifact:** `.squad/decisions/inbox/roman-sanskrit-naming.md`
- **Insight:** Sanskrit names create stronger brand coherence with the yin-yang logo than Latin/Greek names. The well-known Sanskrit words are too contested; the sweet spot is less common but still pronounceable words like Samata and Taraka. Consonant clusters (kṣ, sth) are the main pronunciation barrier for Western audiences.

### 2026-07-17: Kshanam (क्षणम्) Final Availability Check

- **Context:** Yashas added Kshanam as a third finalist alongside Drishti and Kshana. Conducted full 9-point availability audit.
- **Deliverable:** `docs/app-naming-final-check.md` — Kshanam section with App Store, domain, social, trademark, cultural, pronunciation, ASO, and comparison analysis.
- **Verdict:** 🔴 **NO-GO** — "Kshanam: Event Invites & RSVP" by Amicus Labs already exists on BOTH iOS App Store and Google Play. The 2016 Telugu thriller movie "Kshanam" dominates all search results. kshanam.com is taken. Harder to pronounce than Kshana with no compensating benefit.
- **Key finding:** Grammatical variants of Sanskrit words (e.g., accusative "-am" form) can land on entirely different name collisions than the root form. Always check inflected forms separately.
- **Recommendation:** Kshana is the strictly superior variant — shorter, cleaner namespace, no app store conflicts, easier to pronounce. Kshanam should be dropped from consideration.
