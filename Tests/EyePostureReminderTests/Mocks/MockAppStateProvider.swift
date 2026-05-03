@testable import EyePostureReminder
import UIKit

/// In-memory stub of `AppStateProviding` for unit tests.
///
/// Returns a fixed `UIApplication.State` supplied at creation time. Create a
/// new instance per test to ensure isolation.
final class MockAppStateProvider: AppStateProviding {

    private let _applicationState: UIApplication.State

    init(state: UIApplication.State) {
        _applicationState = state
    }

    var applicationState: UIApplication.State { _applicationState }
}
