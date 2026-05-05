@testable import EyePostureReminder
import Foundation
import XCTest

@MainActor
final class SettingsAccessibilityTests: XCTestCase {
    func test_settingsSavedBanner_bodyEvaluates() {
        let described = String(describing: SettingsSavedBanner().body)

        XCTAssertFalse(
            described.isEmpty,
            "SettingsSavedBanner body must evaluate after splitting decorative image from accessible text (#613)."
        )
    }

    func test_settingsSavedBanner_decorativeCheckmarkIsAccessibilityHidden() throws {
        let source = try String(contentsOf: settingsViewSourceURL, encoding: .utf8)
        let bannerSource = try XCTUnwrap(
            source.slice(from: "struct SettingsSavedBanner: View", to: "// MARK: - Snooze"),
            "SettingsSavedBanner source should be present in SettingsView.swift."
        )

        XCTAssertFalse(
            bannerSource.contains("Label("),
            "SettingsSavedBanner must not use Label because its decorative SF Symbol can be exposed to VoiceOver."
        )
        XCTAssertTrue(
            bannerSource.contains("Image(systemName: \"checkmark.circle.fill\")"),
            "SettingsSavedBanner should keep the visual checkmark as an explicit Image."
        )
        XCTAssertTrue(
            bannerSource.contains(".accessibilityHidden(true)"),
            "SettingsSavedBanner checkmark Image must be hidden from VoiceOver."
        )
    }

    private var settingsViewSourceURL: URL {
        repositoryRoot
            .appendingPathComponent("EyePostureReminder")
            .appendingPathComponent("Views")
            .appendingPathComponent("SettingsView.swift")
    }

    private var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            url = url.deletingLastPathComponent()
            if FileManager.default.fileExists(
                atPath: url.appendingPathComponent("Package.swift").path
            ) {
                return url
            }
        }
        preconditionFailure("Cannot locate repo root from \(#filePath)")
    }
}

private extension String {
    func slice(from start: String, to end: String) -> String? {
        guard let startRange = range(of: start) else { return nil }
        let searchRange = startRange.upperBound..<endIndex
        guard let endRange = range(of: end, range: searchRange) else {
            return String(self[startRange.lowerBound...])
        }
        return String(self[startRange.lowerBound..<endRange.lowerBound])
    }
}
