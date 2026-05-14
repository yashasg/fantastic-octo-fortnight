---
name: "squad-file-layout"
description: "Quick reference for canonical .squad/ directory structure and file locations for all squad artifacts (agent histories, decisions, logs, skills, identity, casting, team config)"
domain: "squad-organization, documentation, orchestration"
confidence: "low"
source: "observed — discovered file-path drift (commit 54bf555) where cross-agent history updates were written to .squad/history/{name}-{role}.md instead of canonical .squad/agents/{name}/history.md"
tools: []
---

## Context

The `.squad/` directory contains all team orchestration artifacts, decision records, agent documentation, and operational logs. Each artifact type has a canonical location convention. Violations of these conventions create drift and confusion (e.g., agent histories ended up in `.squad/history/` instead of their canonical location under `.squad/agents/{name}/`).

This skill provides a definitive reference for where every squad artifact belongs.

## Canonical File Locations

### Agent-Owned Files
- **Agent history:** `.squad/agents/{name}/history.md` — Learning log, decisions approved, work summaries, outcomes tracked
- **Agent charter:** `.squad/agents/{name}/charter.md` — Role description, responsibilities, work style, project context

**NEVER:** Use `.squad/history/{name}-{role}.md` for agent histories — this is not canonical and signals drift.

### Decision Records
- **Master decisions file:** `.squad/decisions.md` — Canonical, permanent record of all decisions, merged from inbox
- **Decisions inbox:** `.squad/decisions/inbox/{agent}-{slug}.md` — Temporary: drafts awaiting review, merged into decisions.md, then deleted

**NEVER:** Create `.squad/decisions/decisions.md` or `.squad/decisions/{decision-name}.md` — all decisions live in the single master file.

### Operational Logs

#### Orchestration Logs (Agent Work Sessions)
- **Path:** `.squad/orchestration-log/{ISO-8601-UTC-timestamp}-{agent}.md`
- **Purpose:** Agent-tagged output log, decision consolidation, quality gate results
- **Example:** `.squad/orchestration-log/2026-05-14T06-05-00Z-livingston.md`
- **Format:** Timestamp as `YYYY-MM-DDTHH-mm-ssZ`, agent name (lowercase)

#### Session Logs (User/Scribe Summary Logs)
- **Path:** `.squad/log/{ISO-8601-UTC-timestamp}-{topic}.md`
- **Purpose:** High-level session summary, cross-agent outcome, user-facing notes
- **Example:** `.squad/log/2026-04-27T03-41-00Z-yinyang-implementation.md`
- **Format:** Timestamp as `YYYY-MM-DDTHH-mm-ssZ`, topic slug (lowercase, hyphens)

**Note:** `.squad/history/` directory exists for unrelated one-off log files (e.g., `issue-203-extension-scaffold.md` from April 30). Do NOT use it for agent histories or routine operational logs.

### Skills
- **Path:** `.squad/skills/{skill-name}/SKILL.md`
- **Purpose:** Reusable pattern or technique learned during work, shared across agents
- **Example:** `.squad/skills/external-correspondence-style/SKILL.md`
- **Format:** Skill name as kebab-case, SKILL.md filename (all caps)

### Identity & Team Config
- **Identity Now:** `.squad/identity/now.md` — Current team state snapshot
- **Identity Wisdom:** `.squad/identity/wisdom.md` — Reusable principles and philosophy
- **Team Config:** `.squad/team.md` — Team roster, owner, project context
- **Team Routing:** `.squad/routing.md` — Agent assignments by task type/domain
- **Team Ceremonies:** `.squad/ceremonies.md` — Meeting schedule, rituals, decision gates

### Casting & Configuration
- **Casting Policy:** `.squad/casting/policy.json` — Rules for agent selection/assignment
- **Casting Registry:** `.squad/casting/registry.json` — Current cast assignments
- **Casting History:** `.squad/casting/history.json` — Historical assignments and outcomes

### Templates
- **Skill template:** `.squad/templates/skill.md` — Reference for new skill documentation format
- **Other templates:** `.squad/templates/{artifact-name}.md` — Templates for common artifacts

## Patterns

### ✅ Correct Structure Example
```
.squad/
├── agents/
│   ├── danny/
│   │   ├── charter.md        (Danny's role description)
│   │   └── history.md        (Danny's learning log & work summary)
│   ├── frank/
│   │   ├── charter.md
│   │   └── history.md
│   └── rusty/
│       ├── charter.md
│       └── history.md
├── decisions.md              (Master decisions file)
├── decisions/
│   └── inbox/
│       ├── danny-apple-entitlement-reply.md  (Temp draft)
│       └── frank-copyright-analysis.md        (Temp draft)
├── orchestration-log/
│   ├── 2026-05-14T06-05-00Z-livingston.md
│   └── 2026-04-29T06-15-00Z-saul.md
├── log/
│   ├── 2026-05-14T06-10-00Z-204-no-warning-validation.md
│   └── 2026-04-27T03-41-00Z-yinyang-implementation.md
├── skills/
│   ├── external-correspondence-style/
│   │   └── SKILL.md
│   └── squad-file-layout/
│       └── SKILL.md
├── identity/
│   ├── now.md
│   └── wisdom.md
├── casting/
│   ├── policy.json
│   ├── registry.json
│   └── history.json
├── team.md
├── routing.md
└── ceremonies.md
```

### ❌ Anti-Pattern: File-Path Drift

**Wrong locations (discovered in commit 54bf555):**
```
.squad/history/danny-product.md         ❌ (should be .squad/agents/danny/history.md)
.squad/history/frank-legal.md           ❌ (should be .squad/agents/frank/history.md)
.squad/history/rusty-architecture.md    ❌ (should be .squad/agents/rusty/history.md)
```

**Why this is wrong:**
- `.squad/history/` is not the canonical location for agent histories
- Agent histories are scoped to `.squad/agents/{name}/`, not a global `.squad/history/` directory
- `.squad/history/` exists for *unrelated one-off logs* (e.g., `issue-203-extension-scaffold.md`), not routine agent documentation
- This drift breaks discoverability — agents looking for their own history won't find it in the canonical location

## Anti-Patterns

- ❌ **Agent history in `.squad/history/{name}-{role}.md`** — Use `.squad/agents/{name}/history.md` instead
- ❌ **Multiple decision files scattered** (e.g., `.squad/decisions/apple-reply.md`, `.squad/decisions/copyright.md`) — All decisions belong in `.squad/decisions.md`; use inbox for drafts
- ❌ **Decision subdirectories for decisions** (e.g., `.squad/decisions/api-design/routing.md`) — Don't create subdirectories under decisions; use a flat master file with section headers
- ❌ **Operational logs without timestamps** — Always include ISO 8601 UTC timestamp in log file names
- ❌ **Agent-specific logs mixed with session logs** — Orchestration logs are agent-tagged (`.squad/orchestration-log/{ts}-{agent}.md`); session/sprint logs are scribe-owned (`.squad/log/{ts}-{topic}.md`)
- ❌ **Skills without the SKILL.md filename** — Use exactly `.squad/skills/{skill-name}/SKILL.md`, not `.squad/skills/{skill-name}/skill.md` or `.squad/skills/{skill-name}.md`

## Resolution Strategy

**When resolving a squad artifact path:**
1. Identify the artifact type (history, decision, log, skill, config, etc.)
2. Check this reference for the canonical location
3. If you find an artifact in the wrong location, treat it as drift and relocate it
4. Report the drift pattern as a learning to prevent future occurrences

## Notes

**Confidence: Low.** This is the first comprehensive observation of file-path structure conventions after discovering drift in commit 54bf555. The reference above captures the intended structure, but patterns may evolve as more drift is discovered and patterns solidify.

**Validated:** Identified and corrected drift on 2026-05-14:
- Found three cross-agent history files in `.squad/history/` (wrong location)
- Moved content to `.squad/agents/{name}/history.md` (canonical location)
- Deleted drift files

**Next:** Monitor for future drift. If no new violations occur after 5+ sessions of routine work, increase confidence to medium.
