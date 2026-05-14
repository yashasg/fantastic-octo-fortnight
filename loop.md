---
configured: true
interval: 5
timeout: 30
description: "My squad work loop"
---

# Squad Work Loop

> ⚠️ Set `configured: true` in the frontmatter above to activate this loop.
> Run with: `squad loop`

## What to do each cycle

1. Validate the `./scripts/build.sh all` works, if not make a p0 issue on github and fix it.
2. If open GitHub issues exist, pick the highest-priority unblocked issue and make code changes in this cycle.
3. For squad work, create branches as `users/squad/<issue_name_fix>`, commit and push changes, then open/update a PR linked with a closing keyword (for example `Closes #123`).
4. Always prune and delete stale worktrees before starting on a new issue
5. Monitor CI/CD for squad PRs, fix failing checks, address comments, and squash merge to `main` when green so linked issues close with the merge.
6. If no open GitHub issues remain, run a parallel sweep, identify and create issues on github, and start the highest priority (p0>p1>p2>p3) issue immediately.
7. work on multiple issues whenever agents are unlikely to step into each others changes.
8. Maintain clean code, use docs/google_swift_coding_style.md. Always look to remove/delete stale code and files.
9. After completing work, output:
	- blockers
	- risky changes
	- top 3 next actions
	- action evidence (`commit SHA` and/or `PR #` and/or `issue #`, or blocker logs)

## Monitoring (optional)

Optional command:

```bash
squad loop
```

## Personality (optional)

Be concise and architecture-first. Use bullets, cite file paths, and separate
facts from recommendations.

## Tips

- Keep reports under 12 lines.
- Prefer root-cause fixes over local patches.
- Don’t propose architecture changes unless drift is proven.
h cycle

Describe what your squad should do every time the loop wakes up. Be specific —
the more context you give, the better your squad performs.

Examples:
- Check for new messages in a Teams channel and summarize action items
- Review recent pull requests and flag anything needing attention
- Run a health check on staging and report anomalies
- Scan the inbox for anything that needs a response today

<!-- Replace this section with your actual loop instructions. -->

## Monitoring (optional)

If you want your squad to watch external channels, enable monitor capabilities:

```bash
squad loop --monitor-email --monitor-teams
```

## Personality (optional)

If your squad has a specific voice or style, describe it here so each cycle
stays consistent.

Example: "Be concise. Use bullet points. Flag blockers clearly."

## Tips

- **Be specific.** Vague prompts produce vague results.
- **Set boundaries.** Tell the squad what NOT to do (e.g., "Don't send messages to anyone but me").
- **Start small.** Begin with one task per cycle, then expand.
- **Use frontmatter.** `interval` controls how often the loop runs. `timeout` caps each cycle.
