# Session Log: Data-Driven Settings Spec

**Timestamp:** 2026-04-24T20:19:00Z  
**Agent:** Danny (PM)  
**File:** `.squad/decisions/inbox/danny-data-driven-settings-spec.md`

Spec drafted. Problem: hardcoded Swift defaults require recompile. Solution: bundle `defaults.json`, seed UserDefaults on first launch, let user changes persist.

JSON schema maps to `epr.*` keys. Ownership: Basher (loader/seeding), Linus (UI), Livingston (tests). 9 acceptance criteria defined.
