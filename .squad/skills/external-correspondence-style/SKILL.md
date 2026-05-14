---
name: "external-correspondence-style"
description: "Compose external correspondence (support replies, customer emails, appeals) in plain prose—no markdown formatting, no labeled section headers, natural human voice"
domain: "communication, customer-facing work"
confidence: "low"
source: "observed — Apple Developer Support reply v1 rejected for sounding AI-generated due to markdown formatting"
tools: []
---

## Context

External correspondence (Apple Developer Support replies, customer support emails, GitHub issue comments to outsiders, marketing correspondence, App Store appeals, etc.) read as LLM-generated when formatted with markdown syntax and labeled section headers. Real humans don't organize their thoughts into structured sections with `**bold headers**` and bullet points. Indie developers write conversationally, with natural paragraphs, varied sentence length, contractions, and a single human voice.

Markdown syntax (e.g., `**bold**`, `- bullets`, numbered lists) renders as literal asterisks and dashes in most email clients and web forms (Apple Developer Support portal, Gmail, Outlook, Zendesk, etc.). This creates a jarring reading experience and signals "this was written by an AI generator."

## Patterns

### ❌ Anti-Pattern: Markdown-Heavy Structure (v1)

```
Subject: RE: Family Controls Entitlement Request

Dear Johnny,

Thank you for the follow-up on case 102881605113. I'm happy to clarify the business need for the FamilyControls, DeviceActivity, and ManagedSettings entitlements for kshana.

**What kshana is:**
kshana is a privacy-first iOS wellness app that delivers gentle, configurable reminders for healthy screen breaks (e.g., the 20-20-20 eye-rest rule). It aligns with Apple's Digital Wellbeing positioning — no tracking, no ads, no account required.

**Why these entitlements are required:**
The core product promise is "enforceable break-time boundaries." With FamilyControls, DeviceActivity, and ManagedSettings, kshana shields selected apps during user-initiated breaks — the app cannot be opened until the break completes. Without these APIs, kshana degrades to local notifications and an in-app overlay, which users can dismiss instantly. These entitlements are the only Apple-sanctioned path to true app shielding on iOS. The feature is not optional — it is the primary value proposition.

**Distribution impact:**
kshana is currently in TestFlight validation with a signed iPhone build. App Store launch is gated on True Interrupt Mode. Any entitlement delay would directly impact our App Store submission timeline and go-to-market window.

If you need any additional information — technical architecture, app privacy summary, demo video, or design specifications — I'm happy to provide it. Please reference case 102881605113 in any follow-up.

Thank you for your time and consideration.

Best regards,
Yashas
```

**Problem:** Labeled sections (`**What kshana is:**`, `**Why these entitlements are required:**`) read as obviously LLM-generated. Formal tone ("I'm happy to clarify", "I'm happy to provide") sounds bot-written. Parallel structure (four labeled blocks) lacks human conversational rhythm.

### ✅ Pattern: Plain Prose, Natural Voice (v2)

```
Subject: RE: Family Controls / Device Activity / Managed Settings Entitlement Request

Hi Johnny,

Thanks for following up on case 102881605113. I wanted to clarify the business need for the FamilyControls, DeviceActivity, and ManagedSettings entitlements for kshana.

kshana is a privacy-first iOS wellness app built around the 20-20-20 rule for healthy screen breaks. It's designed to sit alongside Apple's Digital Wellbeing positioning — no tracking, no ads, no account required. The core feature is simple: during a user-initiated break, kshana shields selected apps so they can't be opened until the break completes. That's the primary value proposition, not a nice-to-have.

Without these entitlements, the app falls back to local notifications and an in-app overlay that users can dismiss instantly. That defeats the whole purpose. These are the only sanctioned APIs available on iOS to enforce actual app boundaries during breaks, so they're not optional from a product standpoint.

Right now we're in TestFlight validation with a signed build ready. App Store launch is gated on this entitlement approval, so any delay directly impacts our go-to-market timing and user acquisition credibility as a genuine Digital Wellbeing tool.

If you need more detail — technical architecture, privacy summary, a demo video, design specs — I can send that over. Just reference case 102881605113 in any follow-up.

Thanks for your time.

Best,
Yashas
```

**Strengths:**
- No markdown formatting (no `**bold**`, no section headers)
- Natural flowing paragraphs that weave the same facts without structural markers
- Conversational opening: "Thanks for following up" instead of "Dear Johnny, Thank you for the follow-up"
- Human phrasing: "I can send that over" instead of "I'm happy to provide"
- Contractions (`can't`, `it's`) reinforce solo indie dev voice
- Varied sentence length (short: "That defeats the whole purpose." mixed with longer constructions)
- Shorter overall (165 words vs. 230), respects reader time
- Single human voice throughout; sounds authentically typed

## Anti-Patterns

- ❌ **Markdown section headers** (`**What is:**`, `**Why this matters:**`) — reads as LLM-generated
- ❌ **Bullet-point lists** — don't render correctly in email; use natural paragraph flow instead
- ❌ **Formal greeting/closing** ("Dear Sir/Madam", "Thank you for your time and consideration") — indie dev voice is casual ("Hi Johnny", "Thanks for your time")
- ❌ **Perfect parallel structure** — four equally-weighted sections with identical length feel scripted; humans vary paragraph length
- ❌ **Overly formal phrases** ("I'm delighted to provide", "I'm happy to clarify") — sounds bot-generated; use "I can send that over" instead
- ❌ **Numbered lists without context** — "Here are the 3 reasons:" followed by (1) (2) (3); just fold into narrative paragraphs
- ❌ **All-caps emphasis** (`NOT optional`, `CRITICAL`) — comes across as shouting; use varied punctuation or rephrasing instead

## Examples

### Example 1: Apple Developer Support Reply (Above)

See "Plain Prose, Natural Voice (v2)" section above.

### Example 2: Customer Support Email

**❌ Wrong:**
```
Subject: Re: Issue #42 — Overlay Not Dismissing

Hi User,

Thank you for reporting this issue. Here are the steps we're taking to resolve it:

**What we found:**
The overlay dismiss gesture is triggered by downward swipe, but the code was checking for `height > 0` (downward) instead of `height < 0` (upward).

**How we're fixing it:**
- Update gesture condition to `value.translation.height < 0`
- Test with iOS 16+ simulator
- Push fix to next release

**Timeline:**
Expected fix in v0.2.1 (ETA: May 21, 2026).

Best regards,
Yashas
```

**✅ Right:**
```
Subject: Re: Issue #42 — Overlay Not Dismissing

Hey, thanks for the report. I found the bug — the overlay dismiss gesture was looking for downward swipe (`height > 0`) when it should check for upward swipe (`height < 0`). I've fixed that in the next release, which should ship by May 21. I'll send you a TestFlight link as soon as it's ready to test.

Thanks,
Yashas
```

### Example 3: GitHub Issue Comment to External Party

**❌ Wrong:**
```
Thank you for the detailed issue report. Our team has identified the root cause:

**Root Cause Analysis:**
The OverlayView timer callback was using `DispatchQueue.main.async`, which deferred callback execution by ~16ms. In rapid-succession user interactions, this caused race conditions.

**Proposed Solution:**
We are replacing `DispatchQueue.main.async` with `MainActor.assumeIsolated` to synchronously run the callback on the main thread.

**Expected Resolution Timeline:**
- PR: May 14
- v0.3.0 release: May 28

We appreciate your patience.

Best regards,
The kshana Team
```

**✅ Right:**
```
Thanks for the detailed report. I traced the bug to the overlay timer callback — it was using `DispatchQueue.main.async`, which delayed execution by ~16ms and created a race condition with rapid user taps. I'm replacing it with `MainActor.assumeIsolated` to run synchronously on the main thread instead. Fix should be in the next release by May 28. I'll tag you when it's ready for testing.

Cheers,
Yashas
```

## When to Apply This Skill

- **Always:** Apple Developer Support replies (entitlements, TestFlight review holds, App Store appeals)
- **Always:** Customer support email (Zendesk, Help Scout, etc.)
- **Always:** GitHub issue comments to external contributors or reporters
- **Always:** Marketing or user-facing communication outside the codebase
- **Never needed:** Internal engineering docs, PR descriptions, architecture decision records (those are *inside* the codebase and can use markdown)

## Notes

**Confidence: Low.** This pattern was observed from a single user feedback session (Yashasg rejected v1 Apple reply for "sounding AI-generated"). First instance of applying this to external correspondence. If multiple future instances confirm the pattern, increase confidence to Medium.

**Future work:** If team generates more external correspondence (customer support emails, App Store appeals, TestFlight feedback replies), validate that plain-prose style works consistently and update this skill accordingly.
