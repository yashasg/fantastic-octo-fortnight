import Foundation
@testable import EyePostureReminder

/// In-memory implementation of `SettingsPersisting` for unit tests.
///
/// Uses a `[String: Any]` dictionary as backing store. No file I/O occurs.
/// Create a fresh instance per test to ensure isolation.
final class MockSettingsPersisting: SettingsPersisting {

    private var storage: [String: Any] = [:]

    // MARK: - SettingsPersisting

    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        storage[key] as? Bool ?? defaultValue
    }

    func set(_ value: Bool, forKey key: String) {
        storage[key] = value
    }

    func double(forKey key: String, defaultValue: Double) -> Double {
        storage[key] as? Double ?? defaultValue
    }

    func set(_ value: Double, forKey key: String) {
        storage[key] = value
    }

    func integer(forKey key: String, defaultValue: Int) -> Int {
        storage[key] as? Int ?? defaultValue
    }

    func set(_ value: Int, forKey key: String) {
        storage[key] = value
    }

    // MARK: - Test Helpers

    /// Returns `true` if a value has been explicitly set for `key`.
    func hasValue(forKey key: String) -> Bool {
        storage[key] != nil
    }

    /// Removes all stored values, simulating a fresh install.
    func clear() {
        storage.removeAll()
    }
}
