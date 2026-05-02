import SwiftUI

// MARK: - Backward-compatible onChange helpers (iOS 16+)
//
// The two-argument onChange(of:initial:_:) overload is iOS 17+ only.
// These wrappers use the new form on iOS 17 and fall back to the
// deprecated-but-functional single-arg perform: form on iOS 16.

extension View {
    /// Calls `action` with the new value whenever `value` changes.
    /// Works on iOS 16 and later without deprecation warnings on iOS 17+.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(
        of value: V,
        perform action: @escaping (V) -> Void
    ) -> some View {
        if #available(iOS 17, *) {
            onChange(of: value) { _, newValue in action(newValue) }
        } else {
            onChange(of: value, perform: action)
        }
    }
}
