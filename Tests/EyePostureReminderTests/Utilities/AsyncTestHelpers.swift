import XCTest

// MARK: - Deterministic wait helpers (Issue #456)

@MainActor
extension XCTestCase {
    /// Polls `condition` on the main actor (yielding cooperatively) until it returns
    /// `true` or `timeout` expires.
    ///
    /// Use this instead of fixed `Task.sleep` to synchronize with unstructured inner
    /// `Task {}` closures: rather than guessing an arbitrary wall-clock duration, the
    /// wait resolves the moment the expected state is observed.
    ///
    /// - Parameters:
    ///   - timeout: Maximum time to wait before reporting a test failure. Defaults to 1 s.
    ///   - file: Source file for failure reporting (auto-filled by the compiler).
    ///   - line: Source line for failure reporting (auto-filled by the compiler).
    ///   - condition: A synchronous predicate evaluated on the main actor.
    func awaitCondition(
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line,
        _ condition: () -> Bool
    ) async {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() {
            if Date() >= deadline {
                XCTFail("awaitCondition timed out after \(timeout)s", file: file, line: line)
                return
            }
            await Task.yield()
        }
    }
}
