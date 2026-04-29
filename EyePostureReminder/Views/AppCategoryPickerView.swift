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
//   - Accepts `SelectedAppsState` as `@ObservedObject` — no @EnvironmentObject.
//   - Accepts `authorizationStatus` as a plain value — no live FamilyControls import.
//   - Calls injected action closures — no navigation or UIApplication coupling.
// This keeps the view testable via body-description inspection without a SwiftUI host.

import SwiftUI

// MARK: - AppCategoryPickerView

/// Presents the True Interrupt Mode configuration surface.
///
/// Renders one of four states based on `authorizationStatus`:
/// - `.unavailable`   — Entitlement pending; informational banner, CTA disabled.
/// - `.notDetermined` — Pre-permission copy; "Enable Screen Time Access" CTA.
/// - `.denied`        — Re-authorize nudge; "Open Settings" CTA.
/// - `.approved`      — Selection summary; placeholder for FamilyActivityPicker (#201).
struct AppCategoryPickerView: View {
    @ObservedObject var appsState: SelectedAppsState
    let authorizationStatus: ScreenTimeAuthorizationStatus
    /// Called when the user can still request Screen Time authorization.
    let onRequestAuthorization: () -> Void
    /// Called when authorization is denied and iOS Settings is the recovery path.
    var onOpenSettings: () -> Void = {}
    let onDone: () -> Void

    var body: some View {
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
                    .disabled(authorizationStatus == .unavailable)
                    .padding(.horizontal, AppSpacing.xl)
                    .accessibilityIdentifier("appCategoryPicker.primaryButton")

                    // Secondary dismiss
                    Button(action: onDone) {
                        Text("appCategoryPicker.doneButton", bundle: .module)
                    }
                    .buttonStyle(.secondary)
                    .padding(.horizontal, AppSpacing.xl)
                    .accessibilityIdentifier("appCategoryPicker.doneButton")
                }
                .padding()
                .frame(maxWidth: AppLayout.onboardingMaxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle(Text("appCategoryPicker.navTitle", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    func performPrimaryAction() {
        switch authorizationStatus {
        case .denied:
            onOpenSettings()
        case .unavailable, .notDetermined, .approved:
            onRequestAuthorization()
        }
    }

    // MARK: - Dynamic copy helpers

    private var subtitleKey: LocalizedStringKey {
        switch authorizationStatus {
        case .unavailable:   return "appCategoryPicker.subtitle.unavailable"
        case .notDetermined: return "appCategoryPicker.subtitle.notDetermined"
        case .denied:        return "appCategoryPicker.subtitle.denied"
        case .approved:      return "appCategoryPicker.subtitle.approved"
        }
    }

    private var primaryButtonKey: LocalizedStringKey {
        switch authorizationStatus {
        case .unavailable:   return "appCategoryPicker.button.pendingApproval"
        case .notDetermined: return "appCategoryPicker.button.enableAccess"
        case .denied:        return "appCategoryPicker.button.openSettings"
        case .approved:      return "appCategoryPicker.button.selectApps"
        }
    }

    // MARK: - Status-specific card

    @ViewBuilder
    private var statusCard: some View {
        switch authorizationStatus {
        case .unavailable:
            AppCategoryUnavailableBanner()
        case .notDetermined:
            AppCategoryPrePermissionCard()
        case .denied:
            AppCategoryDeniedCard()
        case .approved:
            AppCategoryApprovedCard(metadata: appsState.selectionMetadata)
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
    let metadata: SelectedAppsMetadata

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
                .foregroundStyle(AppColor.textSecondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.lg)
        .wellnessCard(elevated: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appCategoryPicker.approvedCard")
    }

    private var selectionSummary: String {
        var parts: [String] = []
        if metadata.categoryCount > 0 {
            let noun = metadata.categoryCount == 1 ? "category" : "categories"
            parts.append("\(metadata.categoryCount) \(noun)")
        }
        if metadata.appCount > 0 {
            let noun = metadata.appCount == 1 ? "app" : "apps"
            parts.append("\(metadata.appCount) \(noun)")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("Unavailable") {
    AppCategoryPickerView(
        appsState: SelectedAppsState(),
        authorizationStatus: .unavailable,
        onRequestAuthorization: {},
        onDone: {}
    )
}

#Preview("Not Determined") {
    AppCategoryPickerView(
        appsState: SelectedAppsState(),
        authorizationStatus: .notDetermined,
        onRequestAuthorization: {},
        onDone: {}
    )
}
