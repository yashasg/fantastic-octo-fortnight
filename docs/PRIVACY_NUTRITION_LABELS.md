# Privacy Nutrition Labels — App Store Connect Guide

> **Author:** Danny (Product Manager)  
> **Date:** 2026-04-26  
> **Based on:** Frank's Analytics Privacy Update (2026-04-26)  
> **App:** Eye & Posture Reminder v1.0

---

## Purpose

This document provides step-by-step instructions for filling out Apple's **App Privacy** questionnaire in App Store Connect. It maps every data type the app touches to the correct privacy label answer.

---

## Before You Start

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com).
2. Navigate to **My Apps → Eye & Posture Reminder → App Privacy**.
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
No custom analytics events, no session tracking, no feature-usage logging.

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

These data types are accessed transiently in memory and are never stored persistently or transmitted off-device:

| Data | Framework | Why Not Collected |
|---|---|---|
| App preferences / settings | `UserDefaults` | Stored locally in app sandbox. Never transmitted. |
| Motion activity state | `CMMotionActivityManager` | Transient, in-memory only. Used to pause reminders while driving. Never stored or sent. |
| Focus status | `INFocusStatusCenter` | Transient, in-memory only. Used to pause reminders during Focus modes. Never stored or sent. |
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

## Summary Table

| Data Type | Collected? | Linked? | Tracking? | Purpose |
|---|---|---|---|---|
| UserDefaults / settings | ❌ Not Collected | — | — | — |
| Motion activity | ❌ Not Collected | — | — | — |
| Focus status | ❌ Not Collected | — | — | — |
| os.Logger logs | ❌ Not Collected | — | — | — |
| MetricKit crash data | ✅ Collected | Not Linked | Not Tracking | App Functionality |
| MetricKit performance data | ✅ Collected | Not Linked | Not Tracking | Analytics |
