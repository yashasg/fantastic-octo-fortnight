---
name: "swift-coding-standards"
description: "Understand kshana's enforced vs. conventional coding standards and what to audit when reviewing code"
domain: "code-review, quality-gates"
confidence: "medium"
source: "observed (2026-05-14 audit); validated by full-codebase Google Swift Style audit (Issue #646)"
---

## Context

The kshana iOS project practices strong conventions but has asymmetric enforcement. Developers using the build script locally catch lint violations; CI-only workflows skip linting. This skill documents what is actually enforced, what is conventional, and where the gaps are.

Use this skill when:
- Reviewing PRs to understand which standards are gated (will block merge) vs. aspirational
- Auditing code quality to distinguish true regressions from style inconsistencies
- Recommending enforcement improvements or tooling changes
- Onboarding new contributors on team coding practices

## Patterns

### Enforced Standards (build/CI failure)

**Compiler warnings as errors:**
- `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` (build.sh line 61)
- `GCC_TREAT_WARNINGS_AS_ERRORS=YES` (build.sh line 62)
- Any Swift or C compiler warning fails xcodebuild
- Checked on every push to main; PR CI will catch it

**Code coverage threshold:**
- 80% minimum line coverage enforced (ci.yml:184)
- If coverage drops below 80%, CI build fails
- Coverage is checked after test pass to prevent asymmetric gates (coverage gate runs even if earlier tests fail)

**Test execution:**
- All unit tests must pass (test scheme)
- All UI tests must pass (sharded across 5 parallel jobs)
- Failure of any test blocks PR merge

**Distribution entitlements guardrail:**
- CI rejects commits adding `com.apple.developer.family-controls` to distribution entitlements before issue #201 approved
- Prevents accidental archive uploads that App Store Connect would reject

### Conventional Standards (practiced but not CI-blocking)

**SwiftLint rules:**
- Configured in `.swiftlint.yml` with 30+ opt-in rules (force_unwrapping, line_length: error: 160, etc.)
- Locally invoked via `./scripts/build.sh lint --strict` (fails if any violation found)
- NOT run in CI — developers must run locally
- Violations caught by disciplined developers, missed by CI-only workflows

**Architecture & Design Patterns:**
- `@MainActor` isolation on all UI-bound types (AppCoordinator, SettingsViewModel, Views)
- Protocol-driven dependency injection (NotificationScheduling, OverlayPresenting, ReminderScheduling)
- Design system tokens (AppColor.*, AppFont.*, AppSymbol.*) instead of hardcoded values
- Zero force unwraps in production code (guarded optional handling only)

**Code Organization:**
- MARK comments for section organization (// MARK: - Display Properties, etc.)
- Consistent file structure (Models/, ViewModels/, Views/, Services/, Utilities/, App/)
- One primary type per file (except +Conformance extensions)
- Comprehensive doc comments on all public APIs

**Async Safety:**
- All Task closures in class types capture `[weak self]` (team rule; enforced via code review since #115)
- MainActor isolation prevents thread-safety issues
- No retain cycles (verified in audits)

**Testing Patterns:**
- BDD-style test naming: `test_When_Condition_Then_Expectation`
- Comprehensive mocks in Tests/Mocks/ directory
- Zero force unwraps in test code
- Tests verify both happy path and error cases

### Aspirational Standards (documented but not applied)

**Google Swift Style Guide:**
- Exists in docs/google_swift_coding_style.md (clipping from https://google.github.io/swift/)
- **STATUS (2026-05-14):** Now the **canonical standard** — team has adopted it for all new work.
- Full-codebase audit completed across 53 files, 9,164 LOC. GitHub issue #646 tracks remediation findings and baseline.
- **Audit Summary:** 7 HIGH violations, 29+ MEDIUM, 13 LOW. App + Models scope achieved perfect compliance. Services + Utilities exceptionally strong (zero force unwraps). Views + ViewModels require targeted line-wrapping and one access-control fix.
- **Confidence bump rationale:** Pattern drafted → full-codebase audit executed by parallel agents → findings validated → adoption decision formalized. High confidence in assessment.
- Integration: SwiftLint should be added to CI to enforce compliance going forward (currently optional/local-only). Flagged for follow-up; NOT decided yet.

## Examples

**Where to verify enforced standards:**
- ci.yml lines 61–62, 184–187: warnings-as-errors, coverage threshold
- build.sh line 14 (lint target): local SwiftLint invocation
- ReminderType.swift lines 13–38: MARK organization, protocol-driven design, no hardcoded colors
- SettingsViewModel.swift line 15: @MainActor on observable

**Where SwiftLint is NOT gated (gap):**
- ci.yml: SwiftLint is cached (lines 108–111) but never invoked
- Developers can bypass linting by pushing directly without running build.sh locally

**What code-review enforces:**
- history.md #115 fix: [weak self] pattern in Task closures
- decisions.md Wave 3: @MainActor isolation, DI protocol injection
- decisions.md Restful Grove: design token usage over hardcoded colors

## Anti-Patterns

- Committing code that triggers compiler warnings (will fail CI)
- Using hardcoded colors/fonts instead of AppColor.*/AppFont.* tokens
- Force unwrapping optionals in production code
- Capturing `self` strongly in Task closures without checking if it's safe
- Skipping documentation on public APIs
- Using `UNUserNotificationCenter.current()` directly instead of injecting NotificationScheduling protocol
- Creating large files without MARK section breaks

## Known Gaps

1. **SwiftLint not in CI pipeline:** Linting is optional (developer discipline only). Recommendation: Add `./scripts/build.sh lint` as CI step before build+test.
2. **No pre-commit hooks:** Developers can push without running lint locally. Recommendation: Optional pre-commit hook template in scripts/; document requirement in CONTRIBUTING.md.
3. **Google style guide disconnect:** Aspirational but not actionable. Recommendation: Create team style guide documenting actual practices + SwiftLint config, or deprecate Google guide as reference-only.

## References

- .swiftlint.yml: SwiftLint rule configuration (line 50–108)
- scripts/build.sh: lint, build, test, all targets
- .github/workflows/ci.yml: CI pipeline and enforcement gates
- .squad/decisions.md: Team decisions on DI, @MainActor, design tokens, @Published patterns
- .squad/agents/saul/history.md: Code review audit findings
