# Tess Font Decision — Phase 1C (#161)

**Decision:** Use **Nunito** as the app typography family.

## Rationale

Nunito is the best fit for the Restful Grove direction from parent plan #158: rounded, soft, friendly, and wellness-oriented without becoming childish. DM Sans was the safest neutral option, Plus Jakarta Sans was more premium/product-led, and SF was lowest overhead, but Nunito adds the clearest emotional lift for a calm reminder app.

## Implementation

- Added OFL-licensed Nunito variable font files from the Google Fonts GitHub repo to `EyePostureReminder/Resources/Fonts/`.
- Kept `Package.swift` processing `EyePostureReminder/Resources`, which includes the new font files.
- Added `AppTypography` tokens in `DesignSystem.swift` using SwiftUI `.custom(..., relativeTo:)` so Dynamic Type is preserved.
- Kept fixed monospaced system typography for countdown digits because it is decorative, accessibility-labelled, and intentionally non-scaling.
- Registered bundled fonts programmatically at app startup via `CTFontManagerRegisterGraphicsFont`.
- Kept `AppFont` as a compatibility alias to avoid broad view churn while moving the canonical decision to `AppTypography`.

## Accessibility

All text tokens except the existing countdown token use Dynamic Type-relative SwiftUI custom fonts. The countdown remains a documented fixed-size decorative exception with VoiceOver labels.
