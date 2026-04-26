# Privacy Policy

**App:** Eye & Posture Reminder  
**Last Updated:** April 26, 2026  
**Publisher:** Yashasg

---

## Overview

Your privacy matters. Eye & Posture Reminder is designed to be privacy-preserving: your app settings stay on your device, motion and Focus information are used only transiently for reminder pause logic, and the App does not use advertising, tracking, user accounts, or third-party analytics SDKs.

The App does use Apple's built-in diagnostics and analytics tools, including MetricKit and App Store Connect analytics, to understand aggregate app performance, reliability, crashes, hangs, launch times, memory use, and similar technical metrics. These reports are processed through Apple's systems and are provided to the developer in aggregated or diagnostic form. They are not used to identify you, track you across apps or websites, build advertising profiles, or sell data.

---

## 1. What We Collect or Access

Eye & Posture Reminder stores the following data **locally on your device only**, using Apple's `UserDefaults` storage:

- **App settings and preferences** — your configured reminder intervals, break durations, and any other in-app settings you adjust
- **App state** — whether reminders are enabled or disabled

This data exists solely to remember your preferences between sessions. It is stored in the app's sandboxed container on your device.

The App also accesses the following device data **in memory only** — this data is never stored or transmitted by the App:

- **Motion activity data** — the App reads your device's motion activity state (via `CMMotionActivityManager`) to detect when you are driving, so that reminders are automatically paused. This data is read in memory for the sole purpose of pause logic and is discarded immediately; it is never written to disk, sent to any server, or associated with your identity.
- **Focus mode status** — the App reads your device's Focus mode state (e.g., Do Not Disturb, Work, Personal) to pause reminders during active Focus sessions. This information is read in memory and is never stored or transmitted by the App.

The App uses Apple's built-in diagnostics and analytics systems:

- **MetricKit and App Store Connect analytics** — Apple may process aggregate diagnostics, crash data, hang data, launch time, memory use, CPU use, energy use, disk use, and similar performance metrics. The developer may receive these reports through Apple's systems in aggregate or diagnostic form.
- **Local diagnostic logs** — the App uses Apple's `os.Logger` framework for on-device diagnostic logging. These logs normally remain on your device. In release builds, values that could be sensitive are marked private/redacted. If you choose to share diagnostics with Apple or a TestFlight developer, some diagnostic logs may be included according to Apple's diagnostic-sharing settings.

---

## 2. What We Do NOT Collect or Do

To be explicit about what does **not** happen:

- **No personal information** — we do not collect your name, email address, phone number, date of birth, or other directly identifying information
- **No health or biometric data** — we do not collect eye strain data, posture measurements, or any health-related metrics; physical activity (motion) data is accessed transiently in memory to pause reminders while driving and is never stored or transmitted by the App
- **No location data** — we do not access your GPS or location services
- **No camera or microphone access** — the App does not request access to camera or microphone
- **No device identifiers for tracking** — we do not collect the advertising identifier (IDFA) or use persistent identifiers to track you across apps or websites
- **No user accounts** — the App does not require registration, login, or account creation
- **No third-party advertising or analytics SDKs** — there are no Firebase, Mixpanel, advertising SDK, data broker, or third-party data collection libraries in this App
- **No custom analytics backend** — the App does not send custom analytics events to a developer-operated server or cloud service
- **No sale of data** — we do not sell, rent, trade, or share your data with data brokers or advertising partners
- **No tracking** — we do not track you across apps or websites, build advertising profiles, or use data for targeted advertising

---

## 3. Local Storage

All preference data stored by the App lives in **Apple's `UserDefaults`**, within the App's sandboxed storage on your device.

- This preference data is not intentionally uploaded by the App
- This preference data may be included in your general device backup if your iOS backup settings allow it; that backup is controlled by your iOS settings, not by us
- This preference data is deleted when you delete the App from your device
- We have no direct access to your locally stored preferences

---

## 4. Apple Diagnostics and Analytics

The App uses Apple's built-in diagnostics and analytics tools, including MetricKit and App Store Connect analytics, to help understand app reliability and performance at an aggregate or diagnostic level.

These Apple-native reports may include technical information such as crash signals, hang diagnostics, launch times, memory use, CPU use, energy use, disk use, and similar operational metrics. They are processed through Apple's systems and made available to the developer in aggregated or diagnostic form.

These reports are used only to improve app stability, reliability, and performance. They are **not** used to identify you, track you across apps or websites, build advertising profiles, sell data, or support targeted advertising.

---

## 5. Local Logging

The App uses Apple's `os.Logger` framework for diagnostic logging. These logs normally remain on your device.

Structured log entries use privacy annotations. Categorical labels, such as reminder type, dismiss method, pause condition type, and setting key names, may be marked public because they are enumerated operational labels and do not identify you. Values that could be sensitive, such as old and new setting values, are marked private/redacted in exported logs.

If you choose to share diagnostics with Apple, or if you use a TestFlight build and choose to share app diagnostics with the developer, some diagnostic logs may be included according to Apple's diagnostic-sharing settings.

---

## 6. No Third-Party Data Sharing

We do not sell, rent, trade, or share your data with third-party advertisers, analytics vendors, data brokers, or similar third parties. There are no advertising partners, data brokers, or third-party analytics vendors associated with this App.

Apple may process App Store, diagnostics, crash, and performance information through its own systems, as described in [Apple's Privacy Policy](https://www.apple.com/legal/privacy/) and your Apple device settings.

---

## 7. Apple App Store

The App is distributed through the Apple App Store. Apple may collect certain data as part of the download, installation, diagnostics, crash reporting, analytics, and App Store operation process, governed by [Apple's Privacy Policy](https://www.apple.com/legal/privacy/). Yashasg does not control Apple's data practices.

---

## 8. Children's Privacy (COPPA)

Eye & Posture Reminder does not knowingly collect personal information from children under the age of 13 (or the applicable age of digital consent in your jurisdiction). The App does not require accounts, direct identifiers, advertising identifiers, or third-party tracking.

If you are a parent or guardian and believe your child has somehow provided personal information through this App, please contact us at support@yashasg.dev. We will promptly address the concern.

---

## 9. Data Security

Because the App stores only non-sensitive preference data locally on your device, the primary security protection is your device's own security (passcode, Face ID, Touch ID). We encourage you to keep your device secure and up to date.

The App does not transmit local preferences, motion activity data, or Focus status to a developer server. Apple-native diagnostics and analytics are processed through Apple's systems and are subject to Apple's security and privacy practices.

---

## 10. Your Rights

We do not maintain user accounts or a user-level database about you. If you wish to delete App preferences stored on your device, deleting the App from your device will remove locally stored preferences.

**GDPR (EU/EEA users):** Based on the App's minimal data practices, Yashasg does not maintain a user-level profile or account database for access, deletion, or portability requests. Apple-native diagnostics and App Store data are handled through Apple's systems and your Apple privacy settings.

**CCPA (California users):** We do not sell or share personal information for cross-context behavioral advertising. We do not use the App to track you across apps or websites.

---

## 11. Changes to This Privacy Policy

Yashasg may update this Privacy Policy from time to time. When changes are made, the "Last Updated" date at the top will be revised. We encourage you to review this policy periodically. Continued use of the App after changes are posted constitutes your acceptance of the revised policy.

---

## 12. Contact

If you have questions or concerns about this Privacy Policy, contact:

**Yashasg**  
**Email:** support@yashasg.dev

---

*This Privacy Policy was last updated on April 26, 2026.*
