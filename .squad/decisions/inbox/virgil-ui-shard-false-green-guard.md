# Virgil Decision — UI shard false-green guard

- **Date:** 2026-05-02
- **Decision:** `scripts/build.sh uitest` now validates each successful `xcodebuild test-without-building` attempt against the produced `.xcresult` before declaring success.
- **Why:** We observed shard behavior (notably Overlays + Dark Mode) where command output/exit could appear green while result-bundle truth still indicates failure. Exit-code-only gating is insufficient.
- **Implementation:** Added `xcresult_attempt_passed()` and wired retry loop so success requires both command exit `0` and xcresult status/failure-summary consistency.
- **Impact:** Eliminates false-green UI shard outcomes without inflating global timeout budgets; targeted retry behavior is preserved.
