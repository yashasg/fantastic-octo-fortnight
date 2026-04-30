# kshana — App Store Listing

> **Author:** Danny (Product Manager)  
> **Date:** 2026-04-24  
> **Version:** v0.2.0 — Restful Grove  
> **Milestone:** M2.7 — App Store Preparation

---

## 1. App Name

**kshana**

*App Store subtitle:* Eye & Posture Wellness

*Origin:* Sanskrit (क्षण) — "a moment, an instant"

*Previous name:* Eye & Posture Reminder (renamed for brand identity)

---

## 2. Subtitle

**Eye & Posture Wellness**

*(22 characters — within Apple's 30-character App Store subtitle limit)*

**Subtitle rationale:** The owner-selected subtitle "Eye & Posture Wellness" is intentionally retained for broader wellness positioning over the alternative "Eye & Posture Breaks". "Wellness" frames the app as a holistic health companion rather than a simple timer, appealing to a wider health-conscious audience. Per keyword strategy (Section 4), "wellness" and "posture" are excluded from the keyword field because Apple indexes subtitle words separately — avoiding duplication maximises keyword slot value.

---

## 3. Description

Set your timing. Let kshana gently nudge you to take healthier eye and posture breaks — without accounts, ads, or a custom backend.

kshana uses timer-based screen tracking and reminder alerts to suggest eye breaks (20-20-20 rule) and posture checks at customizable intervals. When you choose to take a break, a calm break screen guides you with a countdown timer. Smart Pause automatically silences reminders during Focus Mode, CarPlay navigation, and when driving. True Interrupt Mode (app-level shielding) is in development and will arrive in a future update pending Apple's entitlement approval.

**Key features:**
- Custom eye break and posture check timing
- Eye break reminders (20-20-20 rule) and posture check reminders at customizable intervals
- Smart Pause during Focus Mode, CarPlay, and driving detection
- Full-screen break screen with countdown timer and haptic feedback
- Snooze options (5 min, 1 hour, rest of day)
- Battery-friendly—native iOS scheduling, minimal background activity
- Privacy-first — no accounts, no ads, no tracking, and no custom analytics backend
- True Interrupt Mode (app-level shielding) coming in a future update when Apple entitlement is approved

**Not medical advice.** kshana is a wellness reminder tool — not a medical device and not a substitute for professional healthcare. The 20-20-20 rule and posture reminders are general wellness suggestions, not medical advice, and are not intended to diagnose, treat, or prevent any condition. If you have health concerns, consult a qualified healthcare professional. True Interrupt Mode uses Apple's FamilyControls API with your authorization, for your own personal wellness use on your device; this feature is pending Apple entitlement approval and is not yet available.

Built for people who spend hours at a screen and want control over their break habits.

*(~185 words)*

---

## 4. Keywords

```
eye health,20-20-20,screen break,reminder,timer,eye strain,ergonomic,rest,screen time,neck pain
```

*(95 characters — within 100-char limit)*

**Keyword strategy notes:**
- Prioritized high-intent terms: "eye health", "screen break", "reminder"
- Included the well-known "20-20-20" rule for discoverability
- "eye strain" captures pain-point searchers
- "ergonomic" broadens reach into health-conscious audiences
- "screen time" captures high-intent users searching for screen-time management tools
- "neck pain" targets users seeking relief from screen-related neck discomfort
- Excluded words already in app name/subtitle (Apple indexes those separately); "wellness" and "posture" removed since both appear in the subtitle ("Eye & Posture Wellness")

---

## 5. What's New (v0.2.0 — Restful Grove)

```
kshana v0.2.0 — Restful Grove

• New visual identity: Sage & Mint color palette with Restful Grove design tokens
• Yin-yang logo animation with Reduce Motion support
• Smart Pause: auto-silence reminders during Focus Mode, CarPlay, and driving
• Screen-time-aware reminders: breaks fire after continuous screen-on time
• Snooze options: 5 min, 1 hour, or rest of day
• 4-screen onboarding flow with app break explanation
• In-app legal documents (Terms, Privacy, Disclaimer)
• Accessibility: WCAG AA contrast, VoiceOver live regions, 44pt tap targets
• Improved stability and reliability

Download kshana on the App Store and start building healthier break habits today.
```

---

## 6. Privacy Policy

### kshana — Privacy Policy

**Effective date:** 2026-04-24  
**Last updated:** 2026-04-26

#### What we collect

kshana is built with privacy as a core value. The app uses **no third-party analytics SDKs**, no advertising frameworks, no user accounts, no tracking, and no custom backend.

The app uses Apple's built-in diagnostics and analytics tools, including **MetricKit** and **App Store Connect analytics**, to understand aggregate app performance, reliability, crashes, hangs, launch times, memory use, and similar technical metrics. These reports are processed through Apple's systems and are provided to the developer in aggregated or diagnostic form. They are **not used to identify you**, track you across apps or websites, build advertising profiles, or sell data.

#### How the app works

- All your settings (reminder intervals, break durations, preferences) are stored locally on your device using iOS UserDefaults.
- Motion activity and Focus status are accessed transiently in memory to pause reminders — they are never stored or transmitted.
- Current builds use local reminder alerts as the primary reminder mechanism. True Interrupt Mode (app-level shielding) is not available in v0.2.0 and will arrive in a future update when Apple's entitlement approval is complete.
- The app uses Apple's `os.Logger` framework for on-device diagnostic logging. These logs remain on your device. In release builds, values that could be sensitive are marked private/redacted. If you choose to share diagnostics with Apple or a TestFlight developer, some diagnostic logs may be included according to Apple's diagnostic-sharing settings.
- No third-party SDKs or frameworks are used — the app is built exclusively with Apple's native iOS libraries (SwiftUI, UIKit, UserNotifications, MetricKit).

#### Permissions

The app requests **notification permission** to deliver reminder alerts when in the background. It requests **motion activity permission** to detect driving and pause reminders. No other permissions are requested beyond what is declared in the app's Info.plist.

#### Data sharing

We do not share data with third-party advertisers, analytics vendors, or data brokers. Apple may process App Store downloads, TestFlight feedback, crash logs, diagnostic logs, and performance metrics through Apple's systems as described above and in Apple's privacy policy.

#### Children's privacy

The app contains no objectionable content and is rated 4+. It does not knowingly collect information from children.

#### Changes to this policy

If we add analytics or data collection features in a future update, this privacy policy will be updated before those features ship. Users will be notified via the App Store update notes.

#### Contact

For questions about this privacy policy, contact the developer via the App Store support link or at the GitHub repository.

---

## 7. Screenshot Descriptions

Five screenshots required for App Store listing. Capture on iPhone 15 Pro (6.1") and iPhone 15 Pro Max (6.7") for required asset sizes.

| # | Screen | What to show | Key callout text |
|---|--------|-------------|-----------------|
| 1 | **Settings View** | Main settings screen with eye and posture reminder rows, interval/duration pickers visible, toggle ON | "Customize your reminders in seconds" |
| 2 | **Eye Break Overlay** | Full-screen eye break overlay with countdown ring, blurred background, eye icon | "Gentle eye breaks with the 20-20-20 rule" |
| 3 | **Posture Check Overlay** | Full-screen posture overlay with countdown, posture icon, dismiss button visible | "Posture check reminders" |
| 4 | **Onboarding Welcome** | First onboarding screen with app icon, welcome message, get-started flow | "Set up in seconds — no account needed" |
| 5 | **Snooze Options** | Overlay or settings showing snooze choices (5 min / 1 hour / rest of day) | "Snooze when you need to — no guilt" |

**Design notes:**
- Use device frames (Xcode Screenshot tool or third-party frame generator)
- Light mode as primary; include Dark Mode variants as supplementary
- Keep callout text minimal and benefit-oriented
- Ensure text meets WCAG AA contrast on all backgrounds

---

## 8. App Store Category

| | Category |
|---|---|
| **Primary** | Health & Fitness |
| **Secondary** | Productivity |

**Rationale:** The app's core value proposition is health (eye care, posture improvement). Secondary category captures users searching for productivity tools to manage screen time.

---

## 9. Age Rating

| | |
|---|---|
| **Rating** | 4+ |
| **Rationale** | No objectionable content, no user-generated content, no web browsing, no in-app purchases, no ads, no tracking |

All App Store age rating questionnaire answers are "No" / "None".

---

## 10. Additional App Store Connect Fields

| Field | Value |
|---|---|
| **Bundle ID** | com.yashasg.eyeposturereminder |
| **SKU** | eye-posture-reminder |
| **Copyright** | © 2026 Yashasg |
| **Support URL** | https://github.com/yashasg/fantastic-octo-fortnight |
| **Marketing URL** | https://github.com/yashasg/fantastic-octo-fortnight |
| **Version** | 0.2.0 |
| **Build** | (CI-assigned via `github.run_number`) |
| **Availability** | All territories |
| **Price** | Free |
| **In-App Purchases** | None |

---

## 11. App Store Submission Checklist

Complete every item before submitting for App Review.

### Legal & Privacy

- [ ] Privacy Policy hosted at a public HTTPS URL (link it in App Store Connect and in-app)
- [ ] EULA supplement with Apple's 7 required clauses added to TERMS.md
- [ ] Privacy Nutrition Labels filled in App Store Connect (see [`docs/PRIVACY_NUTRITION_LABELS.md`](PRIVACY_NUTRITION_LABELS.md))
- [ ] Health/wellness disclaimers included in app description ("not medical advice")

### Entitlements & Info.plist

- [ ] `NSMotionUsageDescription` present in Info.plist with accurate purpose string
- [ ] Focus Status capability enabled on the App ID before using `EyePostureReminder.entitlements` for distribution signing
- [ ] Notification permission usage description accurate

### App Store Connect Configuration

- [ ] Bundle ID finalized: `com.yashasg.eyeposturereminder`
- [ ] Support URL set: `https://github.com/yashasg/fantastic-octo-fortnight`
- [ ] App name, subtitle, keywords, and description finalized (Sections 1–4 above)
- [ ] Age rating questionnaire completed (all answers "No" / "None" → 4+)
- [ ] Primary category: Health & Fitness; Secondary: Productivity
- [ ] Price: Free, all territories

### Assets

- [ ] Screenshots prepared for iPhone 15 Pro (6.1") and iPhone 15 Pro Max (6.7")
- [ ] App icon uploaded (1024×1024, no alpha, no rounded corners)
- [ ] "What's New" text finalized for v1.0

### Pre-Submission Name Search

- [ ] Search App Store for "kshana" and close variants
- [ ] Search USPTO (https://tmsearch.uspto.gov) for similar marks in Class 009/042
- [ ] Google search `"kshana"` in quotes
- [ ] Verify name is accepted in App Store Connect during app setup
- [ ] Check Google Play and Mac App Store for confusingly similar names

**Note:** For a free indie app, the App Store + USPTO knockout search is sufficient. Formal clearance recommended only if monetizing with subscriptions/IAP.

### Final Checks

- [ ] TestFlight beta tested with no critical bugs
- [ ] Build uploaded via Xcode or `xcodebuild` and processed in App Store Connect
- [ ] All App Review rejection risks reviewed (Frank's legal report)
- [ ] Version number set to 1.0 (build number incremented from TestFlight)
