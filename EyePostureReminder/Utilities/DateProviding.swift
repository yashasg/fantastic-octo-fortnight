// DateProviding.swift

import Foundation

// MARK: - DateProviding

/// Abstracts `Date()` wall-clock reads for testability.
///
/// Inject `SystemDateProvider` in production (the default). Inject a
/// `MockDateProvider` in unit tests to control the current time precisely
/// without sleeping or using approximate-delta assertions.
protocol DateProviding {
    /// The current wall-clock date.
    var now: Date { get }
}

// MARK: - SystemDateProvider

/// Production implementation — delegates directly to `Date()`.
struct SystemDateProvider: DateProviding {
    var now: Date { Date() }
}
