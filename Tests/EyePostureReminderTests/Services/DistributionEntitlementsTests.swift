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
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // EyePostureReminderTests
            .deletingLastPathComponent() // Tests
    }
}
