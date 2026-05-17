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

1. Validate the `./scripts/build.sh all` works, if not make a p0 issue on gitlab and fix it.
2. If open gitlab issues exist, pick the highest-priority unblocked issue and make code changes in this cycle.
3. For squad work, create branches as `users/squad/<issue_name_fix>`, commit and push changes, then open/update a PR linked with a closing keyword (for example `Closes #123`).
4. Always prune and delete stale worktrees before starting on a new issue
5. Monitor CI/CD for squad PRs, fix failing checks, address comments, and squash merge to `main` when green so linked issues close with the merge.
6. If no open gitlab issues remain, run a parallel sweep, identify and create issues on gitlab, and start the highest priority (p0>p1>p2>p3) issue immediately.
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
