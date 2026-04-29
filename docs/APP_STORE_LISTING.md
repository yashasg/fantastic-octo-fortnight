# kshana — App Store Listing

> **Author:** Danny (Product Manager)  
> **Date:** 2026-04-24  
> **Version:** v0.1.0-beta (TestFlight)  
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

---

## 3. Description

Set your timing. Let kshana gently nudge you to take healthier eye and posture breaks — without accounts, ads, or a custom backend.

kshana uses local screen-time tracking and backup reminder alerts to suggest eye breaks (20-20-20 rule) and posture checks at customizable intervals. When you choose to take a break, a calm break screen guides you with a countdown timer. True Interrupt Mode, which will shield selected apps during breaks, is prepared but remains gated by Apple's Screen Time entitlement approval.

**Key features:**
- Custom eye break and posture check timing
- Eye break reminders (20-20-20 rule) and posture check reminders at customizable intervals
- Backup local alerts while Screen Time shielding is unavailable
- Screen Time Shield-based True Interrupt Mode once Apple entitlement approval is complete
- Calm break screen with countdown timer and haptic feedback
- Snooze options (5 min, 1 hour, rest of day)
- Works quietly in the background—Smart Pause during Focus Mode and CarPlay
- Battery-friendly—native iOS scheduling, no background timers
- Privacy-first — no accounts, no ads, no tracking, and no custom analytics backend

Built for people who spend hours at a screen and want control over their break habits. Download now and build healthier screen time habits on your terms.

*(148 words)*

---

## 4. Keywords

```
eye health,posture,20-20-20,screen break,reminder,timer,wellness,eye strain,ergonomic,rest
```

*(96 characters — within 100-char limit)*

**Keyword strategy notes:**
- Prioritized high-intent terms: "eye health", "screen break", "reminder"
- Included the well-known "20-20-20" rule for discoverability
- "eye strain" captures pain-point searchers
- "ergonomic" and "wellness" broaden reach into health-conscious audiences
- Excluded words already in app name/subtitle (Apple indexes those separately)

---

## 5. What's New (v0.1.0-beta)

```
Welcome to the first TestFlight beta of kshana!

• Eye break reminders using the 20-20-20 rule
• Posture check reminders at customizable intervals
• Full-screen overlay with countdown timer
• Customizable intervals (10–60 min) and break durations (10–60 s)
• Haptic feedback on overlay appearance and dismissal
• Snooze support (5 min, 15 min, or rest of day)
• Battery-efficient background scheduling
• VoiceOver and Dynamic Type accessibility support

We'd love your feedback! Please report any issues via TestFlight.
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
- True Interrupt setup state is stored locally in the App Group container so the main app and Screen Time extensions can coordinate. This includes the enabled/disabled intent, aggregate app/category selection counts, active shield-session timestamps, and a capped operational event log for shield/fallback diagnostics.
- Motion activity and Focus status are accessed transiently in memory to pause reminders — they are never stored or transmitted.
- Current builds use backup local alerts while Screen Time shielding remains entitlement-gated. Screen Time Shielding and app/category selection are not promised as active App Store functionality until Apple approval is complete and the feature is released.
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
| 5 | **Snooze Options** | Overlay or settings showing snooze choices (5 min / 15 min / rest of day) | "Snooze when you need to — no guilt" |

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
| **Version** | 0.1.0 |
| **Build** | 1 |
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
