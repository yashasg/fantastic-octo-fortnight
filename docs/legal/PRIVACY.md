# Privacy Policy

**App:** Eye & Posture Reminder  
**Last Updated:** April 25, 2026  
**Publisher:** Yashasg

---

## Overview

Your privacy matters. This Privacy Policy explains what data Eye & Posture Reminder collects, how it is used, and what is not collected. The short version: **almost nothing is collected, and what is stored never leaves your device.**

---

## 1. What We Collect

Eye & Posture Reminder stores the following data **locally on your device only**, using Apple's `UserDefaults` storage:

- **App settings and preferences** — your configured reminder intervals, break durations, and any other in-app settings you adjust
- **App state** — whether reminders are enabled or disabled

This data exists solely to remember your preferences between sessions. It is stored in the app's sandboxed container on your device.

The App also accesses the following device data **in memory only** — this data is never stored or transmitted:

- **Motion activity data** — the App reads your device's motion activity state (via `CMMotionActivityManager`) to detect when you are driving, so that reminders are automatically paused. This data is read in memory for the sole purpose of pause logic and is discarded immediately; it is never written to disk, sent to any server, or associated with your identity.
- **Focus mode status** — the App reads your device's Focus mode state (e.g., Do Not Disturb, Work, Personal) to pause reminders during active Focus sessions. This information is read in memory and is never stored or transmitted.

---

## 2. What We Do NOT Collect

To be explicit about what does **not** happen:

- **No personal information** — we do not collect your name, email address, phone number, date of birth, or any identifying information
- **No health or biometric data** — we do not collect eye strain data, posture measurements, or any health-related metrics; physical activity (motion) data is accessed transiently in memory to pause reminders while driving and is never stored or transmitted
- **No persistent usage analytics** — we do not transmit usage data to any external service. The App emits structured diagnostic events (session duration, settings changes, reminder interactions) via Apple's `os.Logger` framework. These events are visible in Xcode Instruments and Console.app for development purposes. When using a TestFlight build with "Share App Data" enabled, these events may be included in diagnostic logs shared with the developer. Structured log entries use a two-tier privacy annotation: **categorical labels** (reminder type, dismiss method, pause condition type, and setting key names) are marked `privacy: .public` because they are enumerated system-level labels containing no identifying information; **setting values** (old and new values for any settings changes) are marked `privacy: .private` and are redacted in any exported log. Timing and duration measurements (session lengths, elapsed countdown time, threshold intervals) are marked `privacy: .public` as they are non-identifying operational metrics
- **No location data** — we do not access your GPS or location services
- **No camera or microphone access** — the App does not request access to camera or microphone
- **No device identifiers** — we do not collect device IDs, advertising identifiers (IDFA), or any persistent hardware identifiers
- **No crash reporting** — we do not transmit crash logs or diagnostic data to any external service. The App uses Apple's MetricKit framework (`MXMetricManager`) as a passive subscriber to receive OS-level performance and diagnostic payloads that Apple collects at the system level (memory usage, CPU time, crash signals, hang durations). The App logs these signals locally via `os.Logger` for development diagnostics; no MetricKit data is transmitted to any external service
- **No third-party advertising or analytics SDKs** — there are no third-party data collection libraries in this App
- **No server communication** — the App does not connect to any server, API, or cloud service. It operates entirely offline

---

## 3. Local Storage Only

All data stored by the App lives exclusively in **Apple's `UserDefaults`**, within the App's sandboxed storage on your device.

- This data is not backed up to iCloud (unless your device's iCloud backup is enabled, in which case it may be included in your general device backup — controlled by your iOS settings, not by us)
- This data is deleted when you delete the App from your device
- We have no access to this data — it never leaves your device to reach us

---

## 4. No Third-Party Data Sharing

We do not sell, rent, trade, or share any data with third parties because we do not collect any data that could be shared. There are no advertising partners, data brokers, or analytics vendors associated with this App.

---

## 5. Apple App Store

The App is distributed through the Apple App Store. Apple may collect certain data as part of the download and installation process, governed by [Apple's Privacy Policy](https://www.apple.com/legal/privacy/). Yashasg has no control over or access to data collected by Apple.

---

## 6. Children's Privacy (COPPA)

Eye & Posture Reminder does not knowingly collect personal information from children under the age of 13 (or the applicable age of digital consent in your jurisdiction). Since the App collects no personal information from any user, it presents no unique risk to children's privacy.

If you are a parent or guardian and believe your child has somehow provided personal information through this App, please contact us at support@yashasg.dev. We will promptly address the concern.

---

## 7. Data Security

Because the App stores only non-sensitive preference data locally on your device, the primary security protection is your device's own security (passcode, Face ID, Touch ID). We encourage you to keep your device secure and up to date.

We do not transmit any data over any network, so there is no transmission-related data security risk on our end.

---

## 8. Your Rights

Since we do not collect personal data, most data subject rights (access, deletion, portability) are satisfied by default — there is nothing we hold about you. If you wish to delete all App data, deleting the App from your device will remove all locally stored preferences.

**GDPR (EU/EEA users):** Based on our minimal data practices, we do not act as a data controller for personal data as defined under GDPR. No personal data is collected or processed.

**CCPA (California users):** We do not sell personal information. We do not collect personal information as defined under the CCPA.

---

## 9. Changes to This Privacy Policy

Yashasg may update this Privacy Policy from time to time. When changes are made, the "Last Updated" date at the top will be revised. We encourage you to review this policy periodically. Continued use of the App after changes are posted constitutes your acceptance of the revised policy.

---

## 10. Contact

If you have questions or concerns about this Privacy Policy, contact:

**Yashasg**  
**Email:** support@yashasg.dev

---

*This Privacy Policy was last updated on April 25, 2026.*
