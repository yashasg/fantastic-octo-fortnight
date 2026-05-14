import ComposableArchitecture
import Foundation

/// Phase-0 stub for the Onboarding feature reducer.
///
/// Follows the empty-stub contract defined by `p0-tca-3` (#666) so Phase 1
/// issue `p0-tca-7` (#670) can replace this file in isolation without merge
/// conflicts against the root `AppFeature` skeleton.
@Reducer
struct OnboardingFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action: Equatable {}

    var body: some ReducerOf<Self> { EmptyReducer() }
}
