import ComposableArchitecture
import Foundation

/// Phase-0 stub for the App-Category-Picker feature reducer.
///
/// Follows the empty-stub contract defined by `p0-tca-3` (#666) so Phase 1
/// issue `p0-tca-9` (#672) can replace this file in isolation without merge
/// conflicts against the root `AppFeature` skeleton.
@Reducer
struct AppCategoryPickerFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action: Equatable {}

    var body: some ReducerOf<Self> { EmptyReducer() }
}
