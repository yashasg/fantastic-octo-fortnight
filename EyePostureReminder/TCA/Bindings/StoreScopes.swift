import ComposableArchitecture

/// Shared `Store.scope(...)` helpers used by more than one Phase-1 feature
/// view.
///
/// Phase 0 (`p0-tca-4` / #667) deliberately leaves this file empty: its
/// presence gives Phase 1 issues (#668–#673) a single agreed-upon location
/// for shared scopes so they do not invent new files that collide. As Phase
/// 1 lands, helpers belonging to multiple features (e.g. presentation
/// scopes, derived view-state projections) should be added here rather than
/// in any individual feature view file.
enum StoreScopes {}
