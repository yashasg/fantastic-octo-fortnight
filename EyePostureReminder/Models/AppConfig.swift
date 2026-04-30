import Foundation
import os

/// Decoded representation of `defaults.json` bundled with the app.
///
/// Provides production defaults for reminder intervals and feature flags.
/// Always prefer `AppConfig.load()` over hardcoded Swift values; changing
/// the JSON changes first-launch behaviour without a recompile.
struct AppConfig: Codable {

    struct Defaults: Codable {
        let eyeInterval: TimeInterval
        let eyeBreakDuration: TimeInterval
        let postureInterval: TimeInterval
        let postureBreakDuration: TimeInterval
    }

    struct Features: Codable {
        let globalEnabledDefault: Bool
        let maxSnoozeCount: Int
    }

    let defaults: Defaults
    let features: Features
}

// MARK: - Hardcoded Fallback

extension AppConfig {
    /// Used when `defaults.json` is missing or corrupt.
    static let fallback = AppConfig(
        defaults: Defaults(
            eyeInterval: 1200,
            eyeBreakDuration: 20,
            postureInterval: 1800,
            postureBreakDuration: 10
        ),
        features: Features(
            globalEnabledDefault: true,
            maxSnoozeCount: 2
        )
    )
}

// MARK: - Loading

extension AppConfig {
    // Cached result for `Bundle.main` — disk I/O + JSON decode happens at most once
    // per app session. Tests that need a custom bundle bypass this cache via the
    // `bundle` parameter (identity check: `bundle === Bundle.main`).
    private static let _mainBundleLoaded: AppConfig = _performLoad(from: .main)

    /// Loads `defaults.json` from `bundle`. Falls back to `AppConfig.fallback`
    /// if the file is absent or cannot be decoded.
    ///
    /// - Parameter bundle: The bundle to search; defaults to `Bundle.main`.
    ///   Inject a test bundle in unit tests.
    static func load(from bundle: Bundle = .main) -> AppConfig {
        // Return cached result for the common production path.
        if bundle === Bundle.main { return _mainBundleLoaded }
        return _performLoad(from: bundle)
    }

    private static func _performLoad(from bundle: Bundle) -> AppConfig {
        guard let url = bundle.url(forResource: "defaults", withExtension: "json") else {
            Logger.settings.warning("AppConfig: defaults.json not found in bundle — using hardcoded fallback")
            return .fallback
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            Logger.settings.error("AppConfig: failed to decode defaults.json (\(error)) — using hardcoded fallback")
            return .fallback
        }
    }
}
