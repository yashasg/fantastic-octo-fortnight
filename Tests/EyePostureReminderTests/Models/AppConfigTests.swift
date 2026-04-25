@testable import EyePostureReminder
import XCTest

// Tests for `AppConfig` — the data-driven default configuration loaded from `defaults.json`.
//
// Tests cover:
// - Hardcoded fallback values (used when JSON is absent or corrupt)
// - Codable decoding from JSON strings (core schema correctness)
// - `AppConfig.load(from:)` — happy path, missing file, corrupt file
// - Range validation (intervals > 0, durations > 0)
// - Forward compatibility (unknown keys in JSON are ignored)
// - Partial JSON (missing required keys fail gracefully via fallback)
// - Concurrent access safety
//
// **Bundle injection pattern:** `AppConfig.load(from:)` accepts a `Bundle`
// parameter so tests can inject a fixture bundle without touching `Bundle.main`.
// swiftlint:disable:next type_body_length
final class AppConfigTests: XCTestCase { // swiftlint:disable:this type_body_length

    // MARK: - Helpers

    /// The test resource bundle (contains Fixtures/defaults.json at build time).
    ///
    /// ⚠️ Do NOT use `Bundle.module` here. `@testable import EyePostureReminder` causes
    /// the production module's `Bundle.module` accessor to shadow the test target's
    /// generated accessor. Locate the test resource bundle explicitly via the xctest
    /// bundle URL to avoid the ambiguity.
    private var testBundle: Bundle {
        let xctest = Bundle(for: AppConfigTests.self)
        let subBundleName = "EyePostureReminder_EyePostureReminderTests"
        let url = xctest.bundleURL.appendingPathComponent(subBundleName + ".bundle")
        return Bundle(url: url) ?? xctest
    }

    /// Returns an `AppConfig` decoded from a JSON string literal. Asserts non-nil.
    private func decode(_ json: String, file: StaticString = #file, line: UInt = #line) -> AppConfig? {
        guard let data = json.data(using: .utf8) else {
            XCTFail("Failed to encode JSON string as UTF-8", file: file, line: line)
            return nil
        }
        return try? JSONDecoder().decode(AppConfig.self, from: data)
    }

    /// Minimal valid JSON matching the current schema.
    private let validJSONString = """
    {
      "defaults": {
        "eyeInterval": 1200,
        "eyeBreakDuration": 20,
        "postureInterval": 1800,
        "postureBreakDuration": 10
      },
      "features": {
        "globalEnabledDefault": true,
        "maxSnoozeCount": 3
      }
    }
    """

    // MARK: - AppConfig.fallback: Hardcoded Safety Net

    func test_fallback_eyeInterval_is1200() {
        XCTAssertEqual(
            AppConfig.fallback.defaults.eyeInterval,
            1200,
            "Fallback eye interval must be 1200s (20-min rule)")
    }

    func test_fallback_eyeBreakDuration_is20() {
        XCTAssertEqual(
            AppConfig.fallback.defaults.eyeBreakDuration,
            20,
            "Fallback eye break must be 20s (20-20-20 rule)")
    }

    func test_fallback_postureInterval_is1800() {
        XCTAssertEqual(
            AppConfig.fallback.defaults.postureInterval,
            1800,
            "Fallback posture interval must be 1800s (30 min)")
    }

    func test_fallback_postureBreakDuration_is10() {
        XCTAssertEqual(
            AppConfig.fallback.defaults.postureBreakDuration,
            10,
            "Fallback posture break must be 10s")
    }

    func test_fallback_globalEnabledDefault_isTrue() {
        XCTAssertTrue(
            AppConfig.fallback.features.globalEnabledDefault,
            "Fallback globalEnabledDefault must be true (app on by default)")
    }

    func test_fallback_maxSnoozeCount_is3() {
        XCTAssertEqual(
            AppConfig.fallback.features.maxSnoozeCount,
            3,
            "Fallback maxSnoozeCount must be 3")
    }

    // MARK: - Fallback: Range Validation

    func test_fallback_eyeInterval_isPositive() {
        XCTAssertGreaterThan(
            AppConfig.fallback.defaults.eyeInterval,
            0,
            "Eye interval must be > 0 seconds")
    }

    func test_fallback_eyeBreakDuration_isPositive() {
        XCTAssertGreaterThan(
            AppConfig.fallback.defaults.eyeBreakDuration,
            0,
            "Eye break duration must be > 0 seconds")
    }

    func test_fallback_postureInterval_isPositive() {
        XCTAssertGreaterThan(
            AppConfig.fallback.defaults.postureInterval,
            0,
            "Posture interval must be > 0 seconds")
    }

    func test_fallback_postureBreakDuration_isPositive() {
        XCTAssertGreaterThan(
            AppConfig.fallback.defaults.postureBreakDuration,
            0,
            "Posture break duration must be > 0 seconds")
    }

    func test_fallback_maxSnoozeCount_isPositive() {
        XCTAssertGreaterThan(
            AppConfig.fallback.features.maxSnoozeCount,
            0,
            "maxSnoozeCount must be > 0")
    }

    // MARK: - Codable: Valid JSON Decoding

    func test_decode_validJSON_returnsNonNil() {
        XCTAssertNotNil(decode(validJSONString), "Valid JSON must decode successfully")
    }

    func test_decode_validJSON_eyeInterval() {
        let config = decode(validJSONString)
        XCTAssertEqual(config?.defaults.eyeInterval, 1200)
    }

    func test_decode_validJSON_eyeBreakDuration() {
        let config = decode(validJSONString)
        XCTAssertEqual(config?.defaults.eyeBreakDuration, 20)
    }

    func test_decode_validJSON_postureInterval() {
        let config = decode(validJSONString)
        XCTAssertEqual(config?.defaults.postureInterval, 1800)
    }

    func test_decode_validJSON_postureBreakDuration() {
        let config = decode(validJSONString)
        XCTAssertEqual(config?.defaults.postureBreakDuration, 10)
    }

    func test_decode_validJSON_globalEnabledDefault() {
        let config = decode(validJSONString)
        XCTAssertEqual(config?.features.globalEnabledDefault, true)
    }

    func test_decode_validJSON_maxSnoozeCount() {
        let config = decode(validJSONString)
        XCTAssertEqual(config?.features.maxSnoozeCount, 3)
    }

    // MARK: - Codable: Forward Compatibility (extra unknown keys)

    func test_decode_extraUnknownKeys_doesNotFail() {
        // Forward-compatible: future versions of defaults.json may add new keys.
        // The decoder must not throw on unknown fields.
        let jsonWithExtras = """
        {
          "defaults": {
            "eyeInterval": 1200,
            "eyeBreakDuration": 20,
            "postureInterval": 1800,
            "postureBreakDuration": 10,
            "futureNewField": "hello"
          },
          "features": {
            "globalEnabledDefault": true,
            "maxSnoozeCount": 3,
            "anotherFutureFlag": true
          },
          "topLevelNewKey": 99
        }
        """
        // JSONDecoder ignores unknown keys by default — this must not return nil
        let config = decode(jsonWithExtras)
        XCTAssertNotNil(config, "Extra unknown keys in JSON must be ignored (forward compatibility)")
    }

    func test_decode_extraUnknownKeys_knownValuesStillCorrect() {
        let jsonWithExtras = """
        {
          "defaults": {
            "eyeInterval": 600,
            "eyeBreakDuration": 30,
            "postureInterval": 900,
            "postureBreakDuration": 15,
            "unknownKey": 42
          },
          "features": {
            "globalEnabledDefault": false,
            "maxSnoozeCount": 5,
            "unknownFlag": true
          }
        }
        """
        let config = decode(jsonWithExtras)
        XCTAssertEqual(
            config?.defaults.eyeInterval,
            600,
            "Known values must still decode correctly when extra keys are present")
        XCTAssertEqual(config?.features.globalEnabledDefault, false)
    }

    // MARK: - Codable: Missing Required Keys (partial load)

    func test_decode_missingDefaultsSection_fails() throws {
        // Without the "defaults" key, AppConfig.Defaults cannot be constructed.
        let json = """
        {
          "features": { "globalEnabledDefault": true, "maxSnoozeCount": 3 }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        XCTAssertThrowsError(
            try JSONDecoder().decode(AppConfig.self, from: data),
            "JSON missing 'defaults' section must throw DecodingError"
        )
    }

    func test_decode_missingFeaturesSection_fails() throws {
        let json = """
        {
          "defaults": {
            "eyeInterval": 1200, "eyeBreakDuration": 20,
            "postureInterval": 1800, "postureBreakDuration": 10
          }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        XCTAssertThrowsError(
            try JSONDecoder().decode(AppConfig.self, from: data),
            "JSON missing 'features' section must throw DecodingError"
        )
    }

    func test_decode_missingEyeInterval_fails() throws {
        let json = """
        {
          "defaults": {
            "eyeBreakDuration": 20,
            "postureInterval": 1800,
            "postureBreakDuration": 10
          },
          "features": { "globalEnabledDefault": true, "maxSnoozeCount": 3 }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        XCTAssertThrowsError(
            try JSONDecoder().decode(AppConfig.self, from: data),
            "JSON missing 'eyeInterval' must throw DecodingError"
        )
    }

    // MARK: - Codable: Corrupt / Malformed JSON

    func test_decode_corruptJSON_throws() {
        let data = Data("not-valid-json{{{{".utf8)
        XCTAssertThrowsError(
            try JSONDecoder().decode(AppConfig.self, from: data),
            "Malformed JSON must throw a decoding error"
        )
    }

    func test_decode_emptyJSON_throws() {
        let data = Data("{}".utf8)
        XCTAssertThrowsError(
            try JSONDecoder().decode(AppConfig.self, from: data),
            "Empty JSON object must throw DecodingError (required keys missing)"
        )
    }

    func test_decode_wrongTypes_throws() throws {
        // eyeInterval is a String instead of Double
        let json = """
        {
          "defaults": {
            "eyeInterval": "not-a-number",
            "eyeBreakDuration": 20,
            "postureInterval": 1800,
            "postureBreakDuration": 10
          },
          "features": { "globalEnabledDefault": true, "maxSnoozeCount": 3 }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        XCTAssertThrowsError(
            try JSONDecoder().decode(AppConfig.self, from: data),
            "Wrong value types in JSON must throw DecodingError"
        )
    }

    // MARK: - AppConfig.load(): File-based Loading

    func test_load_missingFile_returnsFallback() {
        // The test runner bundle does NOT contain defaults.json — simulates missing resource.
        // NOTE: If this test fails, it means the test bundle unexpectedly has a defaults.json.
        //
        // We use a fresh Bundle constructed from the test class's path; the Fixtures/defaults.json
        // IS accessible to the test bundle, so we use a different sentinel: pass a bundle whose
        // URL we know won't contain defaults.json (the xctest framework bundle itself).
        let xcTestFrameworkBundle = Bundle(for: XCTestCase.self)
        let config = AppConfig.load(from: xcTestFrameworkBundle)
        XCTAssertEqual(
            config.defaults.eyeInterval,
            AppConfig.fallback.defaults.eyeInterval,
            "Missing defaults.json must return fallback eyeInterval")
        XCTAssertEqual(
            config.defaults.postureInterval,
            AppConfig.fallback.defaults.postureInterval,
            "Missing defaults.json must return fallback postureInterval")
        XCTAssertEqual(
            config.features.globalEnabledDefault,
            AppConfig.fallback.features.globalEnabledDefault,
            "Missing defaults.json must return fallback globalEnabledDefault")
    }

    func test_load_missingFile_doesNotCrash() {
        // Smoke test: load() must never throw or crash when file is absent.
        let xcTestFrameworkBundle = Bundle(for: XCTestCase.self)
        let config = AppConfig.load(from: xcTestFrameworkBundle)
        XCTAssertNotNil(config, "load() must always return a non-nil AppConfig")
    }

    func test_load_fromTestBundle_withFixtureFile_decodesCorrectly() {
        // The test bundle has Fixtures/defaults.json with test-specific values:
        //   eyeInterval: 900, eyeBreakDuration: 15, postureInterval: 2700,
        //   postureBreakDuration: 20, globalEnabledDefault: true, maxSnoozeCount: 5
        let config = AppConfig.load(from: testBundle)
        XCTAssertEqual(
            config.defaults.eyeInterval,
            900,
            "Fixture file must decode eyeInterval as 900 (test value, differs from fallback 1200)")
        XCTAssertEqual(config.defaults.eyeBreakDuration, 15)
        XCTAssertEqual(config.defaults.postureInterval, 2700)
        XCTAssertEqual(config.defaults.postureBreakDuration, 20)
        XCTAssertTrue(config.features.globalEnabledDefault)
        XCTAssertEqual(config.features.maxSnoozeCount, 5)
    }

    func test_load_fromTestBundle_allIntervals_arePositive() {
        let config = AppConfig.load(from: testBundle)
        XCTAssertGreaterThan(
            config.defaults.eyeInterval,
            0,
            "Loaded eyeInterval must be > 0")
        XCTAssertGreaterThan(
            config.defaults.eyeBreakDuration,
            0,
            "Loaded eyeBreakDuration must be > 0")
        XCTAssertGreaterThan(
            config.defaults.postureInterval,
            0,
            "Loaded postureInterval must be > 0")
        XCTAssertGreaterThan(
            config.defaults.postureBreakDuration,
            0,
            "Loaded postureBreakDuration must be > 0")
    }

    func test_load_fromTestBundle_doesNotReturnFallbackValues() {
        // Fixture file has test-specific values (900, 15, 2700, 20) ≠ fallback (1200, 20, 1800, 10).
        // If this test fails, the test bundle isn't loading the fixture — the fallback fired instead.
        let config = AppConfig.load(from: testBundle)
        XCTAssertNotEqual(
            config.defaults.eyeInterval,
            AppConfig.fallback.defaults.eyeInterval,
            "Test fixture must load distinct values — if equal, the file may not be bundled")
    }

    // MARK: - Concurrent Access

    func test_load_concurrentAccess_doesNotCrash() {
        // `AppConfig.load()` reads a static bundle file; concurrent reads must not race.
        let expectation = expectation(description: "All concurrent loads complete")
        expectation.expectedFulfillmentCount = 20

        let queue = DispatchQueue(label: "com.test.appconfig.concurrent", attributes: .concurrent)
        for _ in 0..<20 {
            queue.async {
                let config = AppConfig.load(from: self.testBundle)
                XCTAssertGreaterThan(config.defaults.eyeInterval, 0)
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5)
    }

    func test_load_concurrentAccess_returnsConsistentValues() {
        // All concurrent loads of the same bundle must return identical values.
        let expectedInterval = AppConfig.load(from: testBundle).defaults.eyeInterval
        let expectation = expectation(description: "All loads match")
        expectation.expectedFulfillmentCount = 10

        let queue = DispatchQueue(label: "com.test.appconfig.consistent", attributes: .concurrent)
        for _ in 0..<10 {
            queue.async {
                let config = AppConfig.load(from: self.testBundle)
                XCTAssertEqual(
                    config.defaults.eyeInterval,
                    expectedInterval,
                    "Concurrent loads must return consistent eyeInterval values")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5)
    }

    // MARK: - AppConfig.Defaults: Expected Keys Audit

    func test_defaults_hasEyeInterval() {
        // Structural: AppConfig.Defaults must expose eyeInterval (epr.eyes.interval mapping)
        XCTAssertNotNil(
            AppConfig.fallback.defaults.eyeInterval as TimeInterval?,
            "eyeInterval must be a non-nil TimeInterval on AppConfig.Defaults"
        )
    }

    func test_defaults_hasEyeBreakDuration() {
        XCTAssertNotNil(
            AppConfig.fallback.defaults.eyeBreakDuration as TimeInterval?,
            "eyeBreakDuration must be a non-nil TimeInterval on AppConfig.Defaults"
        )
    }

    func test_defaults_hasPostureInterval() {
        XCTAssertNotNil(
            AppConfig.fallback.defaults.postureInterval as TimeInterval?,
            "postureInterval must be a non-nil TimeInterval on AppConfig.Defaults"
        )
    }

    func test_defaults_hasPostureBreakDuration() {
        XCTAssertNotNil(
            AppConfig.fallback.defaults.postureBreakDuration as TimeInterval?,
            "postureBreakDuration must be a non-nil TimeInterval on AppConfig.Defaults"
        )
    }

    func test_features_hasGlobalEnabledDefault() {
        // Bool is non-optional; verify the property is accessible and has a defined value.
        let value = AppConfig.fallback.features.globalEnabledDefault
        XCTAssertNotNil(value as Bool?, "globalEnabledDefault must be a Bool on AppConfig.Features")
    }

    func test_features_hasMaxSnoozeCount() {
        XCTAssertGreaterThanOrEqual(
            AppConfig.fallback.features.maxSnoozeCount,
            0,
            "maxSnoozeCount must be an Int on AppConfig.Features"
        )
    }
}
