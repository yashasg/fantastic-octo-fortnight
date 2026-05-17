import SwiftUI
import UIKit
import XCTest

@testable import EyePostureReminder

/// Smoke tests that instantiate every view the way its `#Preview` block does,
/// then force body evaluation via `UIHostingController.loadViewIfNeeded()`.
/// If a preview compiles and renders without crashing, the view's body is exercised
/// — contributing to code coverage.
@MainActor
final class PreviewTests: XCTestCase {

    // MARK: - Helpers

    /// Wraps a SwiftUI view in a UIHostingController, forces layout, and asserts
    /// the resulting UIView is non-nil.
    private func assertPreviewRenders<V: View>(
        _ view: V,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let hc = UIHostingController(rootView: view)
        hc.loadViewIfNeeded()
        XCTAssertNotNil(hc.view, "UIHostingController.view must not be nil", file: file, line: line)
    }

    // MARK: - HomeView
    // NOTE: HomeView and SettingsView use @AppStorage which crashes in SPM
    // test hosts with "bundleProxyForCurrentProcess is nil". Covered via UI tests.

    // MARK: - OverlayView

    func test_overlayView_eyes_preview() {
        let view = OverlayView(type: .eyes, duration: 20) {}
        assertPreviewRenders(view)
    }

    func test_overlayView_posture_preview() {
        let view = OverlayView(type: .posture, duration: 10) {}
        assertPreviewRenders(view)
    }

    // MARK: - ContentView
    // NOTE: ContentView uses @AppStorage — same bundle proxy crash. Covered via UI tests.

    // MARK: - YinYangEyeView

    func test_yinYangEyeView_preview() {
        let view = YinYangEyeView()
            .padding()
            .background(AppColor.background)
        assertPreviewRenders(view)
    }

    // MARK: - LegalDocumentView

    func test_legalDocumentView_terms_preview() {
        let view = LegalDocumentView(document: .terms)
        assertPreviewRenders(view)
    }

    func test_legalDocumentView_privacy_preview() {
        let view = LegalDocumentView(document: .privacy)
        assertPreviewRenders(view)
    }

    func test_legalDocumentView_disclaimer_preview() {
        let view = LegalDocumentView(document: .disclaimer)
        assertPreviewRenders(view)
    }

    // MARK: - Onboarding

    // NOTE: OnboardingView wraps a TabView whose `OnboardingSetupView` page binds
    // pickers to `@AppStorage(SettingsStore.Keys.*)`. `@AppStorage`'s
    // `UserDefaults(suiteName:)` lookup crashes in the SPM test-host process
    // (`bundleProxyForCurrentProcess is nil`), so the full container body is not
    // rendered here. Individual screens (Welcome, Permission, Setup) are tested
    // individually below. (The legacy `@EnvironmentObject AppCoordinator` /
    // `SettingsStore` graph was removed in #755 Phase C — see
    // `EyePostureReminder/Views/Onboarding/OnboardingView.swift`.)

    func test_onboardingWelcomeView_preview() {
        let view = OnboardingWelcomeView(onNext: {})
        assertPreviewRenders(view)
    }

    func test_onboardingPermissionView_preview() {
        let view = OnboardingPermissionView(onNext: {}, notificationCenter: MockNotificationCenter())
        assertPreviewRenders(view)
    }

    func test_onboardingSetupView_preview() {
        // OnboardingSetupView binds pickers to `@AppStorage(SettingsStore.Keys.*)`,
        // which crashes the SPM test-host process (`bundleProxyForCurrentProcess`
        // is `nil`). Body rendering is skipped; instantiation-only is sufficient
        // here. (Migrated off `@EnvironmentObject SettingsStore` in #755 Phase C.)
        let view = OnboardingSetupView(onGetStarted: {})
        _ = view
    }
}
