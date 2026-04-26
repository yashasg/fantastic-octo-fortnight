import SwiftUI
import UIKit

/// A `Toggle` replacement that guarantees XCUITest sees a synchronously
/// updated accessibility value after `tap()`.
///
/// **Why this exists:** On iOS 26, SwiftUI's native `Toggle` is a pure-
/// SwiftUI rendering. Its accessibility value (the "1"/"0" string that
/// XCUITest reads) is part of the *rendered* view snapshot and only
/// updates on the next SwiftUI render cycle — AFTER XCUITest has already
/// read the value immediately following `tap()`.  The result is that
/// `XCTAssertNotEqual(before, after)` spuriously fails because both reads
/// return the pre-tap value.
///
/// In UI-test mode this view renders a `UISwitch` (backed by
/// `UIViewRepresentable`) instead of a SwiftUI `Toggle`.  `UISwitch.isOn`
/// updates synchronously as part of the gesture-handler callback — no
/// render cycle needed — so XCUITest always reads the post-tap value
/// correctly.  Crucially, no SwiftUI `Toggle` is present in the view
/// hierarchy (even with `.accessibilityHidden(true)` a Toggle remains in
/// the XCUITest tree with `isHittable=false`, causing `tap()` to fail).
///
/// In production (non-UITest) builds the view is a plain SwiftUI `Toggle`
/// with zero overhead.
struct AccessibleToggle<LabelContent: View>: View {
    @Binding var isOn: Bool
    let tint: Color
    let accessibilityIdentifier: String?
    let accessibilityHint: Text?
    let onChange: ((Bool) -> Void)?
    @ViewBuilder let label: () -> LabelContent

    init(
        isOn: Binding<Bool>,
        tint: Color = .accentColor,
        accessibilityIdentifier: String? = nil,
        accessibilityHint: Text? = nil,
        onChange: ((Bool) -> Void)? = nil,
        @ViewBuilder label: @escaping () -> LabelContent
    ) {
        self._isOn = isOn
        self.tint = tint
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityHint = accessibilityHint
        self.onChange = onChange
        self.label = label
    }

    var body: some View {
        if AppCoordinator.isUITestMode {
            uiTestBody
        } else {
            productionBody
        }
    }

    // MARK: - Production body (standard SwiftUI Toggle)

    private var productionBody: some View {
        Toggle(isOn: $isOn, label: label)
            .tint(tint)
            .onChange(of: isOn) { newValue in onChange?(newValue) }
            .accessibilityModifiers(id: accessibilityIdentifier, hint: accessibilityHint)
    }

    // MARK: - UI-test body (UISwitch only — no SwiftUI Toggle)
    //
    // In UI test mode we render ONLY the UIKitSwitchView alongside the label.
    // A SwiftUI Toggle (even with .accessibilityHidden(true)) remains in the
    // XCUITest accessibility tree and is found by `app.switches.firstMatch`
    // with isHittable=false (because of .allowsHitTesting(false)), causing
    // tap() to fail silently. Removing the Toggle entirely avoids this.

    private var uiTestBody: some View {
        HStack {
            // Label is for visual presentation only; the UISwitch is the
            // sole accessible element for this row.
            label()
                .accessibilityHidden(true)
            Spacer()
            UIKitSwitchView(
                isOn: $isOn,
                tint: UIColor(tint),
                onChange: onChange
            )
            .frame(width: 51, height: 31)
            .accessibilityModifiers(id: accessibilityIdentifier, hint: accessibilityHint)
        }
    }
}

// MARK: - UIKitSwitchView

/// `UIViewRepresentable` wrapper for `UISwitch`.
/// `UISwitch.isOn` updates on the gesture callback — synchronously
/// from XCUITest's point of view — without waiting for a SwiftUI render.
private struct UIKitSwitchView: UIViewRepresentable {
    @Binding var isOn: Bool
    var tint: UIColor
    var onChange: ((Bool) -> Void)?

    func makeUIView(context: Context) -> UISwitch {
        let sw = UISwitch()
        sw.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        return sw
    }

    func updateUIView(_ uiView: UISwitch, context: Context) {
        context.coordinator.parent = self
        uiView.onTintColor = tint
        if uiView.isOn != isOn {
            uiView.setOn(isOn, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject {
        var parent: UIKitSwitchView
        init(parent: UIKitSwitchView) { self.parent = parent }

        @objc func valueChanged(_ sender: UISwitch) {
            parent.isOn = sender.isOn
            parent.onChange?(sender.isOn)
        }
    }
}

// MARK: - View extension helpers

private extension View {
    @ViewBuilder
    func accessibilityModifiers(id: String?, hint: Text?) -> some View {
        if let id, let hint {
            self.accessibilityIdentifier(id).accessibilityHint(hint)
        } else if let id {
            self.accessibilityIdentifier(id)
        } else if let hint {
            self.accessibilityHint(hint)
        } else {
            self
        }
    }
}
