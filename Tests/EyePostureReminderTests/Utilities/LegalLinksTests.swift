@testable import EyePostureReminder
import XCTest

final class LegalLinksTests: XCTestCase {
    func test_hostedPrivacyPolicyURL_pointsToPublicRepoPolicy() throws {
        let url = try XCTUnwrap(LegalLinks.hostedPrivacyPolicyURL)

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "github.com")
        XCTAssertEqual(url.path, "/yashasg/fantastic-octo-fortnight/blob/main/docs/legal/PRIVACY.md")
    }
}
