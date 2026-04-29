# Privacy Nutrition Labels — App Store Connect Guide

> **Author:** Danny (Product Manager)  
> **Date:** 2026-04-26  
> **Based on:** Frank's Analytics Privacy Update (2026-04-26)  
> **App:** kshana v1.0

---

## Purpose

This document provides step-by-step instructions for filling out Apple's **App Privacy** questionnaire in App Store Connect. It maps every data type the app touches to the correct privacy label answer.

---

## Before You Start

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com).
2. Navigate to **My Apps → kshana → App Privacy**.
3. Click **Get Started** (or **Edit** if previously filled in).
4. Apple will walk through data type categories one by one. Use this guide to answer each.

---

## Data Type Decisions

### Legend

| Answer | Meaning |
|---|---|
| **Not Collected** | The app does not collect or transmit this data type off-device. |
| **Collected** | The data leaves the device and is available to the developer or a third party. Requires further disclosure (linking, tracking, purpose). |

---

### Category-by-Category Answers

#### Contact Info
**Answer: Not Collected**  
The app has no accounts, no email fields, no contact forms.

#### Health & Fitness
**Answer: Not Collected**  
The app provides wellness reminders but does not collect or store health data.

#### Financial Info
**Answer: Not Collected**  
No in-app purchases, no payment processing.

#### Location
**Answer: Not Collected**  
No location services used.

#### Sensitive Info
**Answer: Not Collected**  
No sensitive categories accessed.

#### Contacts
**Answer: Not Collected**  
No address book access.

#### User Content
**Answer: Not Collected**  
No user-generated content features.

#### Browsing History
**Answer: Not Collected**  
No web views or browsing.

#### Search History
**Answer: Not Collected**  
No search functionality.

#### Identifiers
**Answer: Not Collected**  
No user ID, device ID, IDFA, or IDFV collected.

#### Purchases
**Answer: Not Collected**  
App is free with no IAP.

#### Usage Data
**Answer: Not Collected**  
No usage data is transmitted to a developer-operated server or third-party analytics provider. The app writes local `os.Logger` diagnostic events and a capped local App Group IPC event log for shield/fallback/watchdog diagnostics; these remain on device unless the user chooses to share Apple/TestFlight diagnostics.

#### Diagnostics
**Answer: Collected** — see details below.

---

### Diagnostics — Detailed Disclosure

The app uses Apple's **MetricKit** framework. Apple collects diagnostic and performance metrics through its own pipeline and surfaces aggregated reports to the developer in App Store Connect. This must be disclosed.

#### Crash Data

| Field | Answer |
|---|---|
| **Collected?** | Yes |
| **Data type** | Diagnostics → Crash Data |
| **Linked to user?** | No — Not Linked to User |
| **Used for tracking?** | No — Not Used for Tracking |
| **Purpose** | App Functionality |

*Rationale:* MetricKit delivers crash/hang diagnostics through Apple. Developer sees aggregated crash reports, not user-level data. Purpose is App Functionality because crash data is used to fix reliability issues.

#### Performance Data

| Field | Answer |
|---|---|
| **Collected?** | Yes |
| **Data type** | Diagnostics → Performance Data |
| **Linked to user?** | No — Not Linked to User |
| **Used for tracking?** | No — Not Used for Tracking |
| **Purpose** | Analytics |

*Rationale:* MetricKit performance metrics (launch time, memory, CPU, energy, disk I/O) are surfaced as aggregate analytics in App Store Connect. Purpose is Analytics because data is used for product performance insight.

#### Other Diagnostics
**Answer: Not Collected**  
`os.Logger` logs remain on-device in release builds. No custom diagnostic payloads are transmitted.

---

### Data the App Accesses but Does NOT Collect

These data types are accessed or stored locally for App Functionality and are not transmitted off-device by kshana:

| Data | Framework | Why Not Collected |
|---|---|---|
| App preferences / settings | `UserDefaults` | Stored locally in app sandbox. Never transmitted. |
| Motion activity state | `CMMotionActivityManager` | Transient, in-memory only. Used to pause reminders while driving. Never stored or sent. |
| Focus status | `INFocusStatusCenter` | Transient, in-memory only. Used to pause reminders during Focus modes. Never stored or sent. |
| Screen Time / Device activity data (if authorized) | `FamilyControls` / `DeviceActivity` (pending approval) | User-authorized data is used locally for interval scheduling and selected-app shielding. Current builds keep fallback alerts active while entitlement-gated shielding is pending Apple approval (case ID 102881605113). |
| App Group IPC metadata | `UserDefaults(suiteName:)` | Local-only enabled/disabled intent, aggregate app/category selection counts, shield-session timestamps, last access-request timestamp, and capped shield/fallback/watchdog event log. Used so the main app and Screen Time extensions coordinate without a backend. Never transmitted by kshana. |
| Diagnostic logs | `os.Logger` | On-device only in release builds. Sensitive values redacted with `.private`. |

---

## Step-by-Step Walkthrough

1. **"Does your app collect any of the data types listed below?"**  
   → Select **Yes** (because of Diagnostics).

2. **For each non-Diagnostics category** (Contact Info, Health & Fitness, Financial Info, Location, etc.):  
   → Select **No** for each.

3. **For Diagnostics:**  
   → Select **Yes**.  
   → Check **Crash Data** and **Performance Data**.

4. **For Crash Data:**  
   → "Is this data linked to the user's identity?" → **No**  
   → "Is this data used for tracking?" → **No**  
   → Select purpose: **App Functionality**

5. **For Performance Data:**  
   → "Is this data linked to the user's identity?" → **No**  
   → "Is this data used for tracking?" → **No**  
   → Select purpose: **Analytics**

6. **Review and Publish** the privacy label.

---

## ATT (App Tracking Transparency)

**Not required.** MetricKit is Apple-native diagnostics — no IDFA, no cross-app tracking, no third-party data sharing. Adding an ATT prompt would confuse users and may trigger App Review questions.

---

## If Third-Party Analytics Are Added Later

Adding any third-party SDK (Firebase, Mixpanel, Sentry, etc.) **materially changes** the privacy labels. The team must:

1. Re-evaluate every data type category.
2. Likely disclose Identifiers, Usage Data, and additional Diagnostics.
3. Reassess ATT requirements.
4. Update the privacy policy before submission.

See Frank's full checklist in `.squad/decisions/inbox/frank-analytics-privacy-update.md`, Section 5.

---

## Screen Time / Device Activity Features (Pending Approval)

kshana's Screen Time integration is under Apple review (case ID 102881605113). The planned implementation uses local-only App Group metadata and Apple's Screen Time frameworks to coordinate selected-app shielding. It does not use a custom backend, advertising identifier, third-party analytics SDK, or cross-app tracking.

### App Privacy Label Guidance

If Screen Time data and App Group IPC metadata remain local-only as designed, answer **Not Collected** for Screen Time / Device Activity data in App Store Connect because kshana does not transmit this data off device or make it available to the developer outside user-shared Apple diagnostic packages.

If a future release transmits Screen Time, Device Activity, selected-app metadata, IPC event logs, or derived usage analytics to a developer-operated service or third-party provider, this document must be updated before submission and the privacy labels must be reassessed.

### Local Screen Time / IPC Detail

| Local data | Stored? | Transmitted by kshana? | Label impact |
|---|---:|---:|---|
| Aggregate app/category selection counts | Yes, local App Group | No | Not Collected |
| True Interrupt enabled/disabled intent | Yes, local App Group | No | Not Collected |
| Shield-session timestamps and access-request timestamp | Yes, local App Group | No | Not Collected |
| Capped shield/fallback/watchdog IPC event log | Yes, local App Group | No | Not Collected |

**Rationale:** This data is local operational state used for App Functionality. It is not linked to identity, not used for tracking, not sold, and not shared with third parties. Apple may separately process diagnostics, crash data, TestFlight feedback, and App Store analytics under Apple's systems and the user's device/TestFlight sharing settings.

---

## Summary Table

| Data Type | Collected? | Linked? | Tracking? | Purpose |
|---|---|---|---|---|
| UserDefaults / settings | ❌ Not Collected | — | — | — |
| App Group IPC metadata | ❌ Not Collected | — | — | — |
| Motion activity | ❌ Not Collected | — | — | — |
| Focus status | ❌ Not Collected | — | — | — |
| Screen Time (if approved*) | ❌ Not Collected | — | — | — |
| os.Logger logs | ❌ Not Collected | — | — | — |
| MetricKit crash data | ✅ Collected | Not Linked | Not Tracking | App Functionality |
| MetricKit performance data | ✅ Collected | Not Linked | Not Tracking | Analytics |

*Screen Time data and App Group IPC metadata qualify as "Not Collected" only while they remain local-only and are not transmitted by kshana. If a future release exports this data to a developer-operated service or third-party provider, update this guide and App Store Connect before submission.
