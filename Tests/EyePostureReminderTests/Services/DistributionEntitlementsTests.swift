import Foundation
import XCTest

final class DistributionEntitlementsTests: XCTestCase {
    func test_mainAppDistributionEntitlements_includeFocusStatusCapability() throws {
        let plistURL = repositoryRoot
            .appendingPathComponent("EyePostureReminder")
            .appendingPathComponent("EyePostureReminder.Distribution.entitlements")

        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(
            plist["com.apple.developer.focus-status"] as? Bool,
            true,
            "Distribution entitlements must include com.apple.developer.focus-status " +
                "so Focus pause works in TestFlight/App Store builds."
        )
    }

    private var repositoryRoot: URL {
        // Walk up from this source file until Package.swift is found.
        // This avoids hardcoded depth assumptions that break in worktrees
        // or any non-standard execution context (fixes #458).
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            url = url.deletingLastPathComponent()
            if FileManager.default.fileExists(
                atPath: url.appendingPathComponent("Package.swift").path
            ) {
                return url
            }
        }
        preconditionFailure(
            "Cannot locate repo root from \(#filePath): " +
            "no Package.swift found in any ancestor directory."
        )
    }
}
