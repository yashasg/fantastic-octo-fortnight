# Contributing to kshana

Thank you for contributing to **kshana** (Eye & Posture Wellness). This guide
covers the local setup, style requirements, and pull-request expectations that
keep the codebase shippable.

---

## 1. Quickstart

```bash
git clone https://github.com/yashasg/fantastic-octo-fortnight.git
cd fantastic-octo-fortnight

# Required tools (macOS):
brew install xcodegen swiftlint

# Build, lint, and test in one shot:
./scripts/build.sh all
```

All build, lint, test, and packaging commands are standardized through
[`scripts/build.sh`](scripts/build.sh). Use it instead of invoking
`xcodebuild` directly so local and CI behavior stay aligned.

---

## 2. Coding Style

### 2.1 Canonical style guide

Swift code in this repository follows the
[**Google Swift Style Guide**](docs/google_swift_coding_style.md) (vendored in
`docs/`). When the Google guide is silent, follow Apple's
[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).

The canonical guide governs:

- **Source file structure** — one primary type per file, `import` ordering.
- **Column limit** — 100 characters (URLs and `import` lines exempt). See the
  deviation note in §2.3 below.
- **Optional types** — prefer `Optional` over implicitly unwrapped optionals
  (IUOs). New IUOs must be justified in a code comment.
- **Access levels** — declare the narrowest access level that compiles
  (`private` → `fileprivate` → `internal` → `public`).
- **Documentation** — every `public` API gets a Google-format doc comment with
  a single-sentence summary, plus `- Parameter`, `- Returns`, and `- Throws`
  tags as applicable.

### 2.2 SwiftLint (machine-enforced subset)

SwiftLint is the automated guard for the rules above. The configuration lives
in [`.swiftlint.yml`](.swiftlint.yml) and is run with `--strict`, so warnings
are treated as failures.

**You must run the lint locally before pushing**:

```bash
./scripts/build.sh lint
```

The same command runs in CI before any build or test step, so any violation
will block the pull request.

### 2.3 Known deviations from Google Swift Style

These deviations are intentional and tracked:

| Rule | Repo setting | Google value | Tracking issue |
| --- | --- | --- | --- |
| `line_length` warning | 120 chars | 100 chars | [#650](https://github.com/yashasg/fantastic-octo-fortnight/issues/650) |
| `function_body_length` | disabled | enabled | SwiftUI view bodies |
| `large_tuple` | disabled | enabled | SwiftUI preview signatures |
| `opening_brace` | disabled | enabled | SwiftUI DSL trailing closures |

When a deviation is removed, update both `.swiftlint.yml` and this table in the
same PR.

### 2.4 Formatting

This repository does not currently run `swift-format` in CI. SwiftLint covers
the patterns we enforce; formatter integration is tracked in
[#651](https://github.com/yashasg/fantastic-octo-fortnight/issues/651) under
the optional-enhancement section. If you choose to run `swift-format` locally,
configure it to the Google profile and limit changes to files you are already
modifying so unrelated formatting churn does not contaminate the diff.

---

## 3. Local Verification Before Pushing

Run the same gates CI runs:

```bash
./scripts/build.sh lint     # SwiftLint --strict
./scripts/build.sh build    # xcodebuild build for iOS Simulator
./scripts/build.sh test     # Unit tests (must remain at ≥ 80% line coverage)
```

Or, equivalently:

```bash
./scripts/build.sh all      # build → lint → test
```

UI tests run in CI as separate sharded jobs and are not required locally for
every change, but you should run the relevant shard with
`./scripts/build.sh uitest --only-testing <Target>/<Class>` when touching UI
flows.

---

## 4. Pull Requests

- **Branch naming.** Use `users/squad/<issue-name>` for squad work,
  `fix/<short-slug>` for bug fixes, `feature/<short-slug>` for features.
- **Closing keyword.** Reference the issue with a closing keyword in the PR
  body (for example `Closes #123`) so the issue closes automatically when the
  PR merges to `main`.
- **Squash merge.** PRs land via squash merge to keep `main` linear.
- **Green checks required.** All CI checks must be green before merge:
  Build & Test, the lint step (added in #651), and the UI Test shards.
- **One topic per PR.** Avoid mixing unrelated refactors with feature work or
  bug fixes — it makes review and revert harder.

---

## 5. Documentation

- **Public API** gets a Google-format doc comment (see §2.1).
- **Architecture changes** must update `ARCHITECTURE.md` in the same PR.
- **User-visible behavior changes** must update `CHANGELOG.md` and, if the
  flow is documented, `UX_FLOWS.md` or the relevant doc in `docs/`.

---

## 6. Filing Issues

- Use the issue templates in `.github/ISSUE_TEMPLATE/` when available.
- Add a `priority:p0`/`p1`/`p2`/`p3` label so the squad loop can pick the
  highest-priority unblocked work first.
- For privacy/legal/security reports, follow the private contact path
  documented in [`docs/legal/PRIVACY.md`](docs/legal/PRIVACY.md) instead of
  filing a public issue.
