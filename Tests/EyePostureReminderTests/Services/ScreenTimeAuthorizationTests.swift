@testable import EyePostureReminder
import XCTest

/// Unit tests for the Screen Time authorization abstraction added in #204.
///
/// Tests validate `ScreenTimeAuthorizationNoop`, `ScreenTimeAuthorizationStatus`,
/// and `MockScreenTimeAuthorizationProviding`. None of these tests import or
/// instantiate `FamilyControls` — that framework requires the entitlement from
/// #201 and cannot be exercised in an SPM test host.
@MainActor
final class ScreenTimeAuthorizationTests: XCTestCase {

    // MARK: - ScreenTimeAuthorizationNoop

    func test_noop_authorizationStatus_isUnavailable() {
        let sut = ScreenTimeAuthorizationNoop()
        XCTAssertEqual(sut.authorizationStatus, .unavailable)
    }

    func test_noop_requestAuthorization_returnsUnavailable() async {
        let sut = ScreenTimeAuthorizationNoop()
        let result = await sut.requestAuthorization()
        XCTAssertEqual(result, .unavailable)
    }

    func test_noop_requestAuthorization_doesNotMutateStatus() async {
        let sut = ScreenTimeAuthorizationNoop()
        _ = await sut.requestAuthorization()
        XCTAssertEqual(sut.authorizationStatus, .unavailable)
    }

    // MARK: - ScreenTimeAuthorizationStatus raw values

    func test_status_unavailable_rawValue() {
        XCTAssertEqual(ScreenTimeAuthorizationStatus.unavailable.rawValue, "unavailable")
    }

    func test_status_notDetermined_rawValue() {
        XCTAssertEqual(ScreenTimeAuthorizationStatus.notDetermined.rawValue, "notDetermined")
    }

    func test_status_approved_rawValue() {
        XCTAssertEqual(ScreenTimeAuthorizationStatus.approved.rawValue, "approved")
    }

    func test_status_denied_rawValue() {
        XCTAssertEqual(ScreenTimeAuthorizationStatus.denied.rawValue, "denied")
    }

    func test_status_equality() {
        XCTAssertEqual(ScreenTimeAuthorizationStatus.approved, .approved)
        XCTAssertNotEqual(ScreenTimeAuthorizationStatus.approved, .denied)
    }

    func test_status_allCases_count() {
        XCTAssertEqual(ScreenTimeAuthorizationStatus.allCases.count, 4)
    }

    // MARK: - localizedStatusKey (drives Settings UI copy)

    func test_localizedStatusKey_unavailable() {
        XCTAssertEqual(
            ScreenTimeAuthorizationStatus.unavailable.localizedStatusKey,
            "settings.trueInterrupt.statusRow.unavailable"
        )
    }

    func test_localizedStatusKey_notDetermined() {
        XCTAssertEqual(
            ScreenTimeAuthorizationStatus.notDetermined.localizedStatusKey,
            "settings.trueInterrupt.statusRow.notDetermined"
        )
    }

    func test_localizedStatusKey_approved() {
        XCTAssertEqual(
            ScreenTimeAuthorizationStatus.approved.localizedStatusKey,
            "settings.trueInterrupt.statusRow.approved"
        )
    }

    func test_localizedStatusKey_denied() {
        XCTAssertEqual(
            ScreenTimeAuthorizationStatus.denied.localizedStatusKey,
            "settings.trueInterrupt.statusRow.denied"
        )
    }

    // MARK: - MockScreenTimeAuthorizationProviding

    func test_mock_defaultStatus_isUnavailable() {
        let mock = MockScreenTimeAuthorizationProviding()
        XCTAssertEqual(mock.authorizationStatus, .unavailable)
    }

    func test_mock_stubbedStatus_returnsCustomValue() {
        let mock = MockScreenTimeAuthorizationProviding()
        mock.stubbedStatus = .approved
        XCTAssertEqual(mock.authorizationStatus, .approved)
    }

    func test_mock_requestAuthorization_incrementsCallCount() async {
        let mock = MockScreenTimeAuthorizationProviding()
        XCTAssertEqual(mock.requestAuthorizationCallCount, 0)
        _ = await mock.requestAuthorization()
        XCTAssertEqual(mock.requestAuthorizationCallCount, 1)
        _ = await mock.requestAuthorization()
        XCTAssertEqual(mock.requestAuthorizationCallCount, 2)
    }

    func test_mock_requestAuthorization_returnsStubbedResult() async {
        let mock = MockScreenTimeAuthorizationProviding()
        mock.stubbedRequestResult = .approved
        let result = await mock.requestAuthorization()
        XCTAssertEqual(result, .approved)
    }

    func test_mock_requestAuthorization_mutatesStatus() async {
        let mock = MockScreenTimeAuthorizationProviding()
        mock.stubbedRequestResult = .denied
        _ = await mock.requestAuthorization()
        XCTAssertEqual(mock.authorizationStatus, .denied)
    }

    func test_mock_reset_restoresDefaults() async {
        let mock = MockScreenTimeAuthorizationProviding()
        mock.stubbedStatus = .approved
        mock.stubbedRequestResult = .approved
        _ = await mock.requestAuthorization()
        mock.reset()
        XCTAssertEqual(mock.authorizationStatus, .unavailable)
        XCTAssertEqual(mock.requestAuthorizationCallCount, 0)
    }
}
