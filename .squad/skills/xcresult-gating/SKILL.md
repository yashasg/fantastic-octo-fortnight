# Skill: xcresult Truth Gating for iOS CI

**Pattern:** Treat `.xcresult` as source of truth for pass/fail, even when `xcodebuild` exits `0`.

## Use when
- UI tests are flaky and occasionally report contradictory console/pass signals.
- CI sharding/retry logic can accidentally mark success from incomplete or inconsistent attempts.

## Rule
An attempt passes **only if all are true**:
1. `xcodebuild` exits `0`
2. Result bundle exists and is parseable by `xcresulttool`
3. `actionResult.status` is success/succeeded
4. `testFailureSummaries` is empty

## Why it works
This blocks false-green outcomes caused by stream/log ambiguity, truncated bundles, or status aggregation mismatches.

## Time impact
Neutral to better: keep targeted retries by failed identifiers; do not raise blanket timeouts.
