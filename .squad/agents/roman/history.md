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

### 2026-07-17: Final Name Availability Check — Drishti vs. Kshana

- **Context:** Yashas narrowed to two Sanskrit finalists: Drishti ("sight/vision") and Kshana ("a moment"). Conducted exhaustive availability audit across App Store, domains, social, trademark, cultural sensitivity, and ASO for both names.
- **Deliverable:** `docs/app-naming-final-check.md` — full head-to-head comparison with GO/NO-GO verdicts.
- **Drishti verdict: 🔴 NO-GO** — Drishti Technologies Inc. (Palo Alto) holds a LIVE USPTO trademark for "DRISHTI" in Class 9 (software) and Class 42 (SaaS), registered since 2018. This is a hard blocker for trademark registration. Additionally: drishti.com taken, drishtiapp.com taken, Drishti Learning App has 1M+ downloads on App Store, and the word carries an "evil eye" connotation in South Asian cultures.
- **Kshana verdict: ✅ GO** — Cleanest landscape of any name across all four naming rounds. No App Store conflicts, no USPTO registration, social handles open, no cultural issues. Only caveats: kshana.app domain taken by Kshana AI (fintech startup, different industry), and "ksh" consonant cluster is unusual for English speakers.
- **Recommendation:** Kshana is the clear winner. Recommended listing: "Kshana — Eye & Posture Breaks"
- **Decision artifact:** `.squad/decisions/inbox/roman-final-name-check.md`
- **Key insight:** USPTO trademark search is the single most important availability check. A beautiful name means nothing if someone already holds a live registration in your class. Drishti looked promising until the Class 9/42 registration surfaced — always check trademarks before falling in love with a name.

### 2026-07-18: Synonym Translations (Greek/Latin/Sanskrit)

- **Context:** Yashas requested translations of 14 specific English concepts (Blink, Posture, Gaze, Glance, Rest, Ease, Breath, Gentle, Watch, Guard, Wink, Stretch, Soothe, Focus) across Greek, Latin, and Sanskrit. Current favorites: Ocella (#1) and Restwell (#2).
- **Deliverable:** `docs/app-naming-synonyms.md` — translations organized by source word, filtered for pronunciation/length/duplicates, with App Store checks and final Top 10.
- **Top new discoveries:** Anesis (#1, Greek "relief/relaxation"), Nimesha (#2, Sanskrit "blink/moment"), Mollis (#3, Latin "soft/tender"), Tener (#4, Latin "tender/gentle"), Komala (#5, Sanskrit "soft/beautiful").
- **Key finding:** The "gentle/soft" concept produces the best app names across all three languages — Mollis (Latin), Komala (Sanskrit), Mridu (Sanskrit) are all strong. Anesis (Greek) is the single strongest new find across all four naming rounds.
- **App Store landscape:** Watch/Guard/Vigilance words are heavily contested (Phylax, Skopos, Vigilia, Raksha all taken). Soft/gentle words are mostly clean. Mitis (Latin "gentle") has a direct wellness competitor ("mitis: wellness in groups").
- **Decision artifact:** `.squad/decisions/inbox/roman-synonym-naming.md`
- **Insight:** Yashas's instinct toward Ocella remains strong — it holds up well against all 60+ candidates across four rounds. The best complement/alternative from this round is Anesis (Greek "relief") which has a similar elegance profile.

### 2026-07-17: Kshanam (क्षणम्) Final Availability Check

- **Context:** Yashas added Kshanam as a third finalist alongside Drishti and Kshana. Conducted full 9-point availability audit.
- **Deliverable:** `docs/app-naming-final-check.md` — Kshanam section with App Store, domain, social, trademark, cultural, pronunciation, ASO, and comparison analysis.
- **Verdict:** 🔴 **NO-GO** — "Kshanam: Event Invites & RSVP" by Amicus Labs already exists on BOTH iOS App Store and Google Play. The 2016 Telugu thriller movie "Kshanam" dominates all search results. kshanam.com is taken. Harder to pronounce than Kshana with no compensating benefit.
- **Key finding:** Grammatical variants of Sanskrit words (e.g., accusative "-am" form) can land on entirely different name collisions than the root form. Always check inflected forms separately.
- **Recommendation:** Kshana is the strictly superior variant — shorter, cleaner namespace, no app store conflicts, easier to pronounce. Kshanam should be dropped from consideration.

### 2026-07-18: Positioning Audit — kshana App Store & Messaging

- **Context:** Read-only market/App Store positioning audit against current board state (#299 closed; owner/blockers #185/#196/#201/#209/#210 remain).
- **Files audited:** README.md, ROADMAP.md, docs/APP_STORE_LISTING.md, docs/TESTFLIGHT_METADATA.md, docs/app-naming-final-check.md, UX_FLOWS.md, all open GitHub issues.
- **Overall verdict:** Positioning is sound. True Interrupt / Screen Time Shield messaging is correctly hedged ("in development, arriving when Apple entitlement #201 is approved"). Friendly Reminder / local alert copy accurately describes current build. No overpromising on core feature set.
- **One material ASO gap found:** "wellness" in keyword field (8 chars) is already indexed by Apple from subtitle "Eye & Posture Wellness" — wasted budget. Additionally the listed character count (96) is inaccurate; actual string is 90 chars. Freeing those chars by removing "wellness" and adding "screen time" (high-intent, unrepresented search term) reaches 93/100 chars. Created issue #307.
- **Confirmed clean (no new issues needed):** True Interrupt entitlement hedging ✓, Friendly Reminder / local alerts description ✓, category (Health & Fitness primary / Productivity secondary) ✓, competitive differentiation (eye + posture combined, no accounts/ads) ✓, pricing (Free) ✓. Prior issues #272/#250/#218/#292 addressed overpromise/messaging drift risks.
- **Not duplicated:** Naming no-go research (Kshanam, Drishti), owner blockers (#185/#196/#201/#209/#210), medical disclaimer gap (#302).
