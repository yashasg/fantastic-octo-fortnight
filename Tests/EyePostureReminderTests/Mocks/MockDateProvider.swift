// MockDateProvider.swift

import Foundation

@testable import EyePostureReminder

/// Test double for `DateProviding`.
///
/// Set `now` to any fixed `Date` before the call under test to make
/// time-sensitive assertions deterministic.
final class MockDateProvider: DateProviding {
    var now: Date

    init(now: Date = Date()) {
        self.now = now
    }
}
