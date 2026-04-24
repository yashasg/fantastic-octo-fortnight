# Skill: Project Roadmapping

**Skill Type:** Planning & Coordination  
**Agent:** Danny (Product Manager)  
**When to Use:** Converting technical implementation plans or product ideas into actionable project roadmaps

---

## Overview

This skill transforms high-level implementation plans into detailed, executable project roadmaps with:
- Phased delivery structure
- Role-specific work items
- Dependency mapping
- Success criteria
- Risk identification
- Open questions

---

## Process

### 1. Input Analysis
- Read technical implementation plan or product brief
- Extract core features, technical stack, and architecture
- Identify existing team structure and roles
- Review any prior team decisions or constraints

### 2. Phase Structuring
- **Always include Phase 0 (Foundation)** unless foundations already exist:
  - Project setup (Xcode, dependencies, folder structure)
  - Architecture scaffolding (models, services, protocols)
  - CI/CD pipeline (build validation, linting, tests)
  - Design system foundation (colors, typography, icons)
  - Test strategy definition
- Map original plan phases to execution phases (MVP → Polish → Advanced)
- Sequence phases based on dependencies (no parallel phases)

### 3. Milestone Definition
- Break each phase into 3-8 milestones
- Each milestone = 1-5 days of work with clear deliverable
- Assign single owner per milestone (accountability)
- Define acceptance criteria (testable/verifiable outcomes)

### 4. Work Item Assignment
- Map work to team roles:
  - **PM:** Acceptance criteria, backlog grooming, stakeholder decisions
  - **UI/UX Designer:** Visual design, design system, mockups
  - **Product Designer:** User research, journey maps, onboarding flows
  - **Architect:** System design, framework selection, ADRs
  - **Developers (UI/Services):** Implementation, unit tests, integration
  - **Tester:** Test plans, manual/automated QA, bug triage
  - **Code Reviewer:** PR review, refactoring, security checks
- Parallelize independent work where possible

### 5. Dependency Mapping
- Create dependency graph showing milestone prerequisites
- Identify critical path (longest chain of dependencies)
- Call out blockers explicitly (permission decisions, technical spikes)

### 6. Success Criteria per Phase
- Define measurable outcomes (feature completeness, test coverage, performance benchmarks)
- Include non-functional requirements (accessibility, battery impact)
- Set quality gates (zero P0 bugs, code review approval)

### 7. Risk & Open Questions
- List technical risks with mitigation strategies
- Document open questions with owners and deadlines
- Categorize by when answers are needed (before Phase X start)

---

## Output Structure

### Roadmap Document (`ROADMAP.md`)
```
1. Executive Summary
2. Team Roster & Responsibilities
3. Phase 0: Foundation
   - Milestones (M0.1, M0.2, ...)
   - Success Criteria
   - Risks & Open Questions
4. Phase 1: MVP
   - Milestones (M1.1, M1.2, ...)
   - Success Criteria
   - Risks & Open Questions
5. Phase 2: Polish
   - (same structure)
6. Phase 3+: Advanced/Optional
   - (same structure)
7. Dependency Map (visual or text-based)
8. Timeline Estimates
9. Open Questions & Decisions Needed
10. Risk Register
11. Success Metrics (Post-Launch)
12. Appendix: Work Item Checklists
```

### Milestone Template
```
#### M1.1: Milestone Name
- **Owner:** Role Name
- **Deliverables:** Bullet list of concrete outputs
- **Dependencies:** Which milestones must complete first
- **Duration:** X days
- **Acceptance Criteria:** Testable conditions for "done"
```

### Decisions Document (`danny-roadmap-decisions.md`)
Capture all scope and priority decisions made during roadmapping:
- Phase structure choices
- Feature inclusions/exclusions
- Technical stack confirmations
- Timeline trade-offs
- Risk acceptances
- Assumptions

---

## Best Practices

### Do:
- ✅ Always add Phase 0 unless foundations provably exist
- ✅ Assign single owner per milestone (no shared ownership)
- ✅ Define acceptance criteria that are testable/verifiable
- ✅ Identify dependencies explicitly (prevents blocking surprises)
- ✅ Log open questions with owners and deadlines
- ✅ Separate required phases from optional phases
- ✅ Include accessibility and performance requirements

### Don't:
- ❌ Skip Phase 0 (causes rework and blockers later)
- ❌ Create milestones > 5 days (break into smaller chunks)
- ❌ Leave acceptance criteria vague ("improve UX" → specify how)
- ❌ Ignore non-functional requirements (testing, accessibility, performance)
- ❌ Defer all hard questions to "later" (prioritize critical unknowns)
- ❌ Assume unlimited team capacity (validate availability)

---

## Example Applications

### Mobile App Development
- iOS/Android apps with native frameworks
- Phase 0: Xcode/Android Studio setup, CI/CD, design system
- Phase 1: Core user flows
- Phase 2: Polish and App Store prep
- Phase 3: Advanced features (widgets, cloud sync)

### Backend API Projects
- Phase 0: Framework setup, DB schema, API contracts, deployment pipeline
- Phase 1: Core endpoints (auth, CRUD)
- Phase 2: Error handling, rate limiting, monitoring
- Phase 3: Advanced features (webhooks, batch operations)

### Internal Tools
- Phase 0: Requirements gathering, tech stack selection, repo setup
- Phase 1: MVP workflows
- Phase 2: User training, documentation
- Phase 3: Integrations, automation

---

## Validation Checklist

Before finalizing roadmap, verify:
- [ ] Every milestone has a single owner
- [ ] Every milestone has concrete deliverables
- [ ] Acceptance criteria are testable
- [ ] Dependencies are mapped (no circular deps)
- [ ] Critical path identified
- [ ] Timeline estimates are realistic (not best-case scenarios)
- [ ] Open questions have owners and deadlines
- [ ] Risks have mitigation strategies
- [ ] Team capacity confirmed
- [ ] Success metrics defined for post-launch

---

## Related Skills

- **Risk Assessment:** Deep-dive into technical risks and mitigation strategies
- **Sprint Planning:** Breaking roadmap milestones into 1-2 week sprints
- **Stakeholder Communication:** Presenting roadmap to non-technical audiences

---

**Last Updated:** 2026-04-24  
**Skill Owner:** Danny (Product Manager)
