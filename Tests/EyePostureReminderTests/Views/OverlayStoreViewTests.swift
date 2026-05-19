import ComposableArchitecture
import SwiftUI
import UIKit
import XCTest

@testable import EyePostureReminder

/// Coverage for `OverlayView`'s `init(store:)` (TCA) path introduced by #919
/// Phase 1. The legacy closure-based initializer remains exercised by
/// `OverlayAccessibilityTests`, `OverlayGestureTests`, `ViewBodyCoverageTests`
/// and `CoverageBoostTests`; this file targets the new SwiftUI-cover path that
/// `RootView` wires into the `.fullScreenCover` body.
@MainActor
final class OverlayStoreViewTests: XCTestCase {

    // MARK: - Init contract

    func test_storeInit_exposesStoreBackedProperties() {
        let store = Store(
            initialState: OverlayFeature.State(
                type: .eyes,
                duration: 20,
                hapticsEnabled: false,
                pauseMediaEnabled: true
            )
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        let view = OverlayView(store: store)

        XCTAssertEqual(view.type, .eyes)
        XCTAssertEqual(view.duration, 20)
        XCTAssertFalse(view.hapticsEnabled)
    }

    func test_storeInit_postureType_exposesStoreBackedProperties() {
        let store = Store(
            initialState: OverlayFeature.State(
                type: .posture,
                duration: 10,
                hapticsEnabled: true
            )
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        let view = OverlayView(store: store)

        XCTAssertEqual(view.type, .posture)
        XCTAssertEqual(view.duration, 10)
        XCTAssertTrue(view.hapticsEnabled)
    }

    func test_storeInit_typeAccessors_reflectStoreState() {
        let store = Store(
            initialState: OverlayFeature.State(type: .eyes, duration: 20)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        let view = OverlayView(store: store)

        // Store-driven `OverlayView` no longer surfaces the legacy closure
        // accessors (`onDismiss`, `onSettingsTap`, `onAnalyticsEvent`)
        // retired in `#920`; the store-backed property accessors still
        // expose the immutable type / duration / haptics snapshot for the
        // view-body tests.
        XCTAssertEqual(view.type, .eyes)
        XCTAssertEqual(view.duration, 20)
    }

    // MARK: - Body evaluation

    func test_storeInit_bodyEvaluatesWithoutCrash() {
        let store = Store(
            initialState: OverlayFeature.State(type: .eyes, duration: 20)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        let view = OverlayView(store: store)
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
            "Store-driven OverlayView body must evaluate without error")
    }

    func test_storeInit_renderingThroughHostingController_doesNotCrash() {
        let store = Store(
            initialState: OverlayFeature.State(type: .posture, duration: 5)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        let view = OverlayView(store: store)
        let hc = UIHostingController(rootView: view)
        hc.loadViewIfNeeded()
        hc.view.layoutIfNeeded()
        XCTAssertNotNil(hc.view)
    }

    func test_storeInit_zeroDuration_rendersWithoutCrash() {
        let store = Store(
            initialState: OverlayFeature.State(type: .eyes, duration: 0)
        ) {
            OverlayFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        let view = OverlayView(store: store)
        let hc = UIHostingController(rootView: view)
        hc.loadViewIfNeeded()
        XCTAssertNotNil(hc.view)
    }

    // MARK: - RootView fullScreenCover integration

    /// Regression guard for #919 Phase 1: `RootView`'s overlay
    /// `.fullScreenCover` must build `OverlayView(store:)` for the scoped
    /// `OverlayFeature.State`. Constructing the cover body via the same
    /// scoping pattern surfaces any type-mismatch between the canonical
    /// `init(store:)` and the destination's scoped `Store`.
    func test_fullScreenCoverBody_acceptsScopedOverlayStore() {
        let appStore = Store(
            initialState: {
                var state = AppFeature.State()
                state.overlay = OverlayFeature.State(type: .eyes, duration: 20)
                return state
            }()
        ) {
            AppFeature()
        } withDependencies: { TCATestDependencies.applyAllSilentClients(&$0) }

        @Perception.Bindable var bindable = appStore
        let scopedStore = $bindable.scope(state: \.$overlay, action: \.overlay).wrappedValue
        XCTAssertNotNil(scopedStore,
            "AppFeature.overlay must produce a scoped Store while `state.overlay` is non-nil")

        if let scopedStore {
            let view = OverlayView(store: scopedStore)
            let hc = UIHostingController(rootView: view)
            hc.loadViewIfNeeded()
            XCTAssertNotNil(hc.view)
        }
    }
}
