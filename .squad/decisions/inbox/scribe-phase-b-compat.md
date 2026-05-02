# Decision: onChangeCompat Pattern for iOS 16/17 Compatibility

**Date:** 2026-05-02
**By:** yashasg (via Squad Phase B remediation)
**Status:** Established

## What
View+OnChange.swift added — use `onChangeCompat(of:perform:)` instead of raw `.onChange(of:)` modifier for iOS 16/17 compatibility.

`onChangeCompat` uses `if #available(iOS 17)` to dispatch to the new two-arg form on iOS 17+ and the deprecated single-arg form on iOS 16.

## Why
ScreenTime extension build has `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`. iOS 17+ two-arg form is an availability error on iOS 16 target. The compat extension is the canonical fix.

## Implementation
- 22 call sites migrated to `onChangeCompat(of:perform:)` in PR #500
- Extension handles platform version detection transparently
- Eliminates availability warnings while maintaining iOS 16 support
