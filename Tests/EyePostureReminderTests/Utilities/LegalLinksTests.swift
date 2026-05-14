import XCTest

@testable import EyePostureReminder

final class LegalLinksTests: XCTestCase {
    func test_hostedPrivacyPolicyURL_pointsToPublicHostedPolicy() throws {
        let url = try XCTUnwrap(LegalLinks.hostedPrivacyPolicyURL)

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "yashasg.github.io")
        XCTAssertEqual(url.path, "/fantastic-octo-fortnight/privacy.html")
    }
}
