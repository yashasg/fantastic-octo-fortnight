---
updated_at: 2026-04-28T18:57:32.881-07:00
focus_area: TestFlight upload validation. Signed build is iPhone-only for now.
active_issues: []
---

# Current Status

**TestFlight validation is in progress.** Signed export now produces `DerivedData/SignedBuild/Export/kshana.ipa` with manual App Store distribution signing, distribution-safe entitlements, a yin-yang AppIcon asset catalog, and iPhone-only device family metadata.

**Current scope:** kshana does not support iPad at the moment. Keep iPhone portrait-only behavior for TestFlight unless Yashasg explicitly changes this product decision.

**Phase 3 (iCloud sync, widgets, watchOS)** is next when Yashasg decides to proceed. P2 backlog items (DST-aware snooze buttons, AppFont tokens in onboarding, UNUserNotificationCenter injection) will be prioritized for Phase 3 refinement.
