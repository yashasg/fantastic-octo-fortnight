# Decision: Overlay readiness anchor for UI tests

- **Date:** 2026-05-02
- **Owner:** Linus (iOS UI)
- **Context:** Overlay UI tests were flaky when readiness depended only on `overlay.doneButton` hittability during launch/animation transitions.
- **Decision:** Add a dedicated overlay root accessibility identifier (`overlay.root`) and update UI test readiness helper to gate on root existence first, then button hittability with remaining timeout budget.
- **Why:** This reduces race sensitivity without inflating global timeouts and keeps wait logic deterministic across normal and dark-mode overlay flows.
