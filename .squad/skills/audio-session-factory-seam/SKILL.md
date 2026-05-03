---
name: "audio-session-factory-seam"
description: "Inject AVAudioSession via protocol + factory seam for deterministic service tests"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when a service reads `AVAudioSession.sharedInstance()` directly in runtime methods.

## Pattern
- Define a narrow `AudioSessionControlling` protocol with only used APIs.
- Make `AVAudioSession` conform directly.
- Inject `audioSession: AudioSessionControlling? = nil` plus `makeAudioSession` fallback.
- Resolve once in `init` (`audioSession ?? makeAudioSession()`), then reuse.
- For detector-style services, allow an optional state-provider closure override; default it to a helper that reads the resolved injected/factory audio session.
- Add focused tests for real behavior calls and seam tests for fallback-used/injected-bypass.

## Anti-Patterns
- Calling `AVAudioSession.sharedInstance()` inside each service method.
- Writing no-crash-only tests that cannot verify category/activation semantics.
