// AppCategoryPickerView.swift
// kshana
//
// Setup surface for True Interrupt Mode app/category selection.
//
// Pre-entitlement state (#201 pending): presents informational copy and a
// disabled CTA. `FamilyActivityPicker` from `FamilyControls` cannot be
// compiled into an SPM-only target without the entitlement and an Xcode project
// with extension targets. This view provides the correct integration boundary and
// will host the real picker once #201 is resolved.
//
// View boundary contract:
//   - Driven by a `StoreOf<AppCategoryPickerFeature>` (TCA Phase 1 reducer).
//   - `onSelectApps` remains an injected closure: the `FamilyActivityPicker`
//     invocation is parent-owned and not modeled in the Phase-1 reducer
//     (extending it is deferred to #678 / Phase 2 of the TCA migration).
//   - Done dismisses via `@Environment(\.dismiss)` after dispatching
//     `.doneTapped` to the store, so the parent reducer can clear its
//     destination once `RootView` takes ownership of presentation
//     (Phase 7 of #702).

import ComposableArchitecture
import ScreenTimeExtensionShared
import SwiftUI

// MARK: - AppCategoryPickerView

/// Presents the True Interrupt Mode configuration surface.
///
/// Renders one of four states based on `store.authorizationStatus`:
/// - `.unavailable`   — Entitlement pending; informational banner, CTA disabled.
/// - `.notDetermined` — Pre-permission copy; "Enable Screen Time Access" CTA.
/// - `.denied`        — Re-authorize nudge; "Open Settings" CTA.
/// - `.approved`      — Selection summary; placeholder for FamilyActivityPicker (#201).
struct AppCategoryPickerView: View {
    @Perception.Bindable var store: StoreOf<AppCategoryPickerFeature>
    /// Called when authorization is approved and the FamilyActivityPicker can be
    /// presented. Remains a closure because the picker invocation is parent-owned
    /// and not modeled in the Phase-1 reducer (#678 will fold it into the store).
    var onSelectApps: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer(minLength: AppSpacing.xl)

                        // Hero icon
                        Image(systemName: AppSymbol.trueInterrupt)
                            .font(AppFont.trueInterruptIcon)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AppColor.primaryRest)
                            .frame(
                                width: AppLayout.onboardingIllustrationSize,
                                height: AppLayout.onboardingIllustrationSize
                            )
                            .background(Circle().fill(AppColor.surfaceTint))
                            .accessibilityHidden(true)

                        // Title + context subtitle
                        VStack(spacing: AppSpacing.sm) {
                            Text("appCategoryPicker.title", bundle: .module)
                                .font(AppFont.headline)
                                .foregroundStyle(AppColor.textPrimary)
                                .multilineTextAlignment(.center)
                            Text(subtitleKey, bundle: .module)
                                .font(AppFont.body)
                                .foregroundStyle(AppColor.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        // Status-specific information card
                        statusCard
                            .padding(.horizontal, AppSpacing.md)

                        Spacer(minLength: AppSpacing.lg)

                        // Primary CTA
                        Button(action: performPrimaryAction) {
                            Text(primaryButtonKey, bundle: .module)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.primary)
                        .disabled(store.authorizationStatus == .unavailable)
                        .padding(.horizontal, AppSpacing.xl)
                        .accessibilityIdentifier("appCategoryPicker.primaryButton")
                        .accessibilityHint(Text(primaryButtonHintKey, bundle: .module))

                        // Secondary dismiss
                        Button(action: performDoneAction) {
                            Text("appCategoryPicker.doneButton", bundle: .module)
                        }
                        .buttonStyle(.secondary)
                        .padding(.horizontal, AppSpacing.xl)
                        .accessibilityIdentifier("appCategoryPicker.doneButton")
                        .accessibilityHint(
                            Text("appCategoryPicker.doneButton.hint", bundle: .module)
                        )
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: AppLayout.onboardingMaxContentWidth)
                    .frame(maxWidth: .infinity)
                }
                .background(AppColor.background.ignoresSafeArea())
                .navigationTitle(Text("appCategoryPicker.navTitle", bundle: .module))
                .navigationBarTitleDisplayMode(.inline)
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    func performPrimaryAction() {
        switch store.authorizationStatus {
        case .unavailable:
            return
        case .notDetermined:
            store.send(.requestAuthorizationTapped)
        case .denied:
            store.send(.openSettingsTapped)
        case .approved:
            onSelectApps()
        }
    }

    /// Dispatches `.doneTapped` for parent-side dismissal logic and dismisses the
    /// presentation via SwiftUI environment so sheet bindings reset cleanly during
    /// the transitional period before `RootView` owns the destination scope.
    func performDoneAction() {
        store.send(.doneTapped)
        dismiss()
    }

    // MARK: - Dynamic copy helpers

    private var subtitleKey: LocalizedStringKey {
        switch store.authorizationStatus {
        case .unavailable:   return "appCategoryPicker.subtitle.unavailable"
        case .notDetermined: return "appCategoryPicker.subtitle.notDetermined"
        case .denied:        return "appCategoryPicker.subtitle.denied"
        case .approved:      return "appCategoryPicker.subtitle.approved"
        }
    }

    private var primaryButtonKey: LocalizedStringKey {
        switch store.authorizationStatus {
        case .unavailable:   return "appCategoryPicker.button.pendingApproval"
        case .notDetermined: return "appCategoryPicker.button.enableAccess"
        case .denied:        return "appCategoryPicker.button.openSettings"
        case .approved:      return "appCategoryPicker.button.selectApps"
        }
    }

    private var primaryButtonHintKey: LocalizedStringKey {
        Self.primaryButtonHintKey(for: store.authorizationStatus)
    }

    /// Maps `authorizationStatus` to the localized accessibility hint key for the primary CTA.
    ///
    /// Exposed at type-level so unit tests can verify the mapping without instantiating the view.
    static func primaryButtonHintKey(
        for status: ScreenTimeAuthorizationStatus
    ) -> LocalizedStringKey {
        switch status {
        case .unavailable:   return "appCategoryPicker.button.pendingApproval.hint"
        case .notDetermined: return "appCategoryPicker.button.enableAccess.hint"
        case .denied:        return "appCategoryPicker.button.openSettings.hint"
        case .approved:      return "appCategoryPicker.button.selectApps.hint"
        }
    }

    // MARK: - Status-specific card

    @ViewBuilder
    private var statusCard: some View {
        switch store.authorizationStatus {
        case .unavailable:
            AppCategoryUnavailableBanner()
        case .notDetermined:
            AppCategoryPrePermissionCard()
        case .denied:
            AppCategoryDeniedCard()
        case .approved:
            AppCategoryApprovedCard(metadata: store.selection)
        }
    }
}

// MARK: - Unavailable banner

/// Shown when the FamilyControls entitlement has not been provisioned (#201 pending).
struct AppCategoryUnavailableBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: AppSymbol.warning)
                .foregroundStyle(AppColor.accentWarm)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("appCategoryPicker.unavailable.title", bundle: .module)
                    .font(AppFont.bodyEmphasized)
                    .foregroundStyle(AppColor.textPrimary)
                Text("appCategoryPicker.unavailable.body", bundle: .module)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(AppSpacing.lg)
        .wellnessCard(elevated: false)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appCategoryPicker.unavailableBanner")
    }
}

// MARK: - Pre-permission card

/// Shown when authorization has not yet been requested.
struct AppCategoryPrePermissionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("appCategoryPicker.prePermission.title", bundle: .module)
                .font(AppFont.bodyEmphasized)
                .foregroundStyle(AppColor.textPrimary)
            Text("appCategoryPicker.prePermission.body", bundle: .module)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(AppSpacing.lg)
        .wellnessCard(elevated: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appCategoryPicker.prePermissionCard")
    }
}

// MARK: - Denied card

/// Shown when the user has denied Screen Time access.
struct AppCategoryDeniedCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("appCategoryPicker.denied.title", bundle: .module)
                .font(AppFont.bodyEmphasized)
                .foregroundStyle(AppColor.textPrimary)
            Text("appCategoryPicker.denied.body", bundle: .module)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(AppSpacing.lg)
        .wellnessCard(elevated: false)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appCategoryPicker.deniedCard")
    }
}

// MARK: - Approved placeholder card

/// Placeholder for `FamilyActivityPicker` when authorization is approved.
/// The real picker (from `FamilyControls`) will be embedded here once #201
/// and the Xcode project migration are complete.
struct AppCategoryApprovedCard: View {
    let metadata: AppGroupSelectionSnapshot

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            if metadata.isEmpty {
                Text("appCategoryPicker.approved.noSelection", bundle: .module)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(selectionSummary)
                    .font(AppFont.bodyEmphasized)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
            }
            // Placeholder note — remove when FamilyActivityPicker is embedded.
            Text("appCategoryPicker.approved.pickerPlaceholder", bundle: .module)
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.lg)
        .wellnessCard(elevated: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appCategoryPicker.approvedCard")
    }

    private var selectionSummary: String {
        AppCategorySelectionSummary.text(for: metadata)
    }
}

enum AppCategorySelectionSummary {
    static func text(for metadata: AppGroupSelectionSnapshot, bundle: Bundle = .module) -> String {
        var parts: [String] = []
        if metadata.categoryCount > 0 {
            parts.append(localizedCount(
                key: "appCategoryPicker.approved.categoryCount",
                count: metadata.categoryCount,
                bundle: bundle
            ))
        }
        if metadata.appCount > 0 {
            parts.append(localizedCount(
                key: "appCategoryPicker.approved.appCount",
                count: metadata.appCount,
                bundle: bundle
            ))
        }
        return ListFormatter.localizedString(byJoining: parts)
    }

    private static func localizedCount(key: String, count: Int, bundle: Bundle) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(key, bundle: bundle, comment: ""),
            count
        )
    }
}

#Preview("Unavailable") {
    AppCategoryPickerView(
        store: Store(
            initialState: AppCategoryPickerFeature.State(authorizationStatus: .unavailable)
        ) { AppCategoryPickerFeature() }
    )
}

#Preview("Not Determined") {
    AppCategoryPickerView(
        store: Store(
            initialState: AppCategoryPickerFeature.State(authorizationStatus: .notDetermined)
        ) { AppCategoryPickerFeature() }
    )
}
