import ComposableArchitecture
import Foundation

/// Phase-0 stub for the Scheduling feature reducer.
///
/// Follows the stub contract defined by `p0-tca-3` (#666). The lone `start`
/// action is required by `AppFeature.onAppear` (which sends
/// `.scheduling(.start)`) and will be filled in by Phase 1 issue `p0-tca-10`
/// (#673), which adds the long-running scheduling effects.
@Reducer
struct SchedulingFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action: Equatable {
        case start
    }

    var body: some ReducerOf<Self> { EmptyReducer() }
}
