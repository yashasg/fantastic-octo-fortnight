import SwiftUI
import UIKit

// MARK: - ViewModel Box

/// @StateObject container that gives SwiftUI-managed lifecycle to SettingsViewModel.
/// Using @StateObject (instead of @State) ensures SwiftUI preserves the reference
/// across view re-renders and parent view updates.
private final class SettingsViewModelBox: ObservableObject {
    var inner: SettingsViewModel?
}

struct SettingsView: View {

    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: AppCoordinator

    // SettingsViewModel handles scheduling side-effects only.
    // Stored in a @StateObject container so SwiftUI properly manages the class lifecycle.
    @StateObject private var vmBox = SettingsViewModelBox()

    private var viewModel: SettingsViewModel? { vmBox.inner }

    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            // MARK: Master toggle
            Section {
                Toggle(isOn: $settings.globalEnabled) {
                    Text("settings.masterToggle", bundle: .module)
                }
                    .tint(AppColor.reminderBlue)
                    .onChange(of: settings.globalEnabled) { _ in
                        viewModel?.globalToggleChanged()
                    }
                    .accessibilityHint(Text("settings.masterToggle.hint", bundle: .module))
            } footer: {
                if settings.globalEnabled {
                    Text("settings.masterToggle.footer", bundle: .module)
                        .font(AppFont.caption)
                } else {
                    Text("settings.pausedBanner", bundle: .module)
                        .font(AppFont.caption)
                }
            }

            // MARK: Per-type sections (only shown when master is on)
            if settings.globalEnabled {
                Section {
                    ReminderRowView(
                        type: .eyes,
                        isEnabled: $settings.eyesEnabled,
                        interval: $settings.eyesInterval,
                        breakDuration: $settings.eyesBreakDuration
                    ) {
                        viewModel?.reminderSettingChanged(for: .eyes)
                    }
                } header: {
                    Text("settings.section.eyes", bundle: .module)
                } footer: {
                    if settings.eyesEnabled {
                        Text("settings.reminder.section.footer", bundle: .module)
                            .font(AppFont.caption)
                    }
                }

                Section {
                    ReminderRowView(
                        type: .posture,
                        isEnabled: $settings.postureEnabled,
                        interval: $settings.postureInterval,
                        breakDuration: $settings.postureBreakDuration
                    ) {
                        viewModel?.reminderSettingChanged(for: .posture)
                    }
                } header: {
                    Text("settings.section.posture", bundle: .module)
                } footer: {
                    if settings.postureEnabled {
                        Text("settings.reminder.section.footer", bundle: .module)
                            .font(AppFont.caption)
                    }
                }
            }

            // MARK: Snooze (only meaningful when reminders are globally enabled)
            if settings.globalEnabled {
                SettingsSnoozeSection(viewModel: viewModel, reduceMotion: reduceMotion)
            }

            // MARK: Preferences
            Section {
                Toggle(isOn: $settings.hapticsEnabled) {
                    Text("settings.hapticFeedback", bundle: .module)
                }
                    .tint(AppColor.reminderBlue)
                    .accessibilityHint(Text("settings.hapticFeedback.hint", bundle: .module))
            } header: {
                Text("settings.section.preferences", bundle: .module)
            }

            // MARK: Smart Pause
            Section {
                Toggle(isOn: $settings.pauseDuringFocus) {
                    Label(
                        String(localized: "settings.smartPause.pauseDuringFocus", bundle: .module),
                        systemImage: "moon.fill"
                    )
                }
                .tint(AppColor.reminderBlue)
                .accessibilityHint(Text("settings.smartPause.pauseDuringFocus.hint", bundle: .module))
                .accessibilityIdentifier("settings.smartPause.pauseDuringFocus")
                .onChange(of: settings.pauseDuringFocus) { newValue in
                    // Route through ViewModel so the analytics setter fires.
                    viewModel?.pauseDuringFocus = newValue
                }

                Toggle(isOn: $settings.pauseWhileDriving) {
                    Label(
                        String(localized: "settings.smartPause.pauseWhileDriving", bundle: .module),
                        systemImage: "car.fill"
                    )
                }
                .tint(AppColor.reminderBlue)
                .accessibilityHint(Text("settings.smartPause.pauseWhileDriving.hint", bundle: .module))
                .accessibilityIdentifier("settings.smartPause.pauseWhileDriving")
                .onChange(of: settings.pauseWhileDriving) { newValue in
                    // Route through ViewModel so the analytics setter fires.
                    viewModel?.pauseWhileDriving = newValue
                }
            } header: {
                Text("settings.section.smartPause", bundle: .module)
            } footer: {
                Text("settings.smartPause.footer", bundle: .module)
                    .font(AppFont.caption)
            }

            // MARK: Notification permission warning
            if coordinator.notificationAuthStatus == .denied {
                Section {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: AppSymbol.warning)
                            .foregroundStyle(AppColor.warningOrange)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("settings.notifications.disabledTitle", bundle: .module)
                                .font(AppFont.bodyEmphasized)
                            Text("settings.notifications.disabledBody", bundle: .module)
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                    .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("settings.notifications.disabledLabel", bundle: .module))

                    Button(
                        action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        },
                        label: { Text("settings.notifications.openSettings", bundle: .module) }
                    )
                    .font(AppFont.body)
                    .accessibilityHint(Text("settings.notifications.openSettings.hint", bundle: .module))
                }
            }

            // MARK: Legal
            Section {
                Button(action: { showTerms = true },
                       label: { Text("settings.legal.terms", bundle: .module) })
                .font(AppFont.body)
                .accessibilityHint(Text("settings.legal.terms.hint", bundle: .module))
                .accessibilityIdentifier("settings.legal.terms")

                Button(action: { showPrivacy = true },
                       label: { Text("settings.legal.privacy", bundle: .module) })
                .font(AppFont.body)
                .accessibilityHint(Text("settings.legal.privacy.hint", bundle: .module))
                .accessibilityIdentifier("settings.legal.privacy")
            } header: {
                Text("settings.section.legal", bundle: .module)
            }

            // MARK: Advanced
            Section {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Text("settings.resetToDefaults", bundle: .module)
                }
                .font(AppFont.body)
                .accessibilityHint(Text("settings.resetToDefaults.hint", bundle: .module))
                .accessibilityIdentifier("settings.resetToDefaults")
            } header: {
                Text("settings.section.advanced", bundle: .module)
            }
            .confirmationDialog(
                Text("settings.resetToDefaults.confirmTitle", bundle: .module),
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    settings.resetToDefaults()
                } label: {
                    Text("settings.resetToDefaults.confirmAction", bundle: .module)
                }
                Button(role: .cancel) {
                    showResetConfirm = false
                } label: {
                    Text("settings.resetToDefaults.cancel", bundle: .module)
                }
            } message: {
                Text("settings.resetToDefaults.confirmMessage", bundle: .module)
            }

            // MARK: About — feedback + version
            Section {
                Button {
                    // itms-beta:// opens TestFlight when installed.
                    // For users who installed from the App Store, fall back to the
                    // TestFlight website so the tap is never a silent no-op.
                    if let url = URL(string: "itms-beta://") {
                        UIApplication.shared.open(url, options: [:]) { success in
                            if !success, let fallback = URL(string: "https://testflight.apple.com") {
                                UIApplication.shared.open(fallback)
                            }
                        }
                    }
                } label: {
                    Text("settings.feedback.sendFeedback", bundle: .module)
                }
                .font(AppFont.body)
                .accessibilityHint(Text("settings.feedback.sendFeedback.hint", bundle: .module))
                .accessibilityIdentifier("settings.feedback.sendFeedback")
            } header: {
                Text("settings.section.about", bundle: .module)
            } footer: {
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
                let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
                Text(
                    String(
                        format: String(localized: "settings.about.versionFormat", bundle: .module),
                        version,
                        build
                    )
                )
                .font(AppFont.caption)
            }
        }
        .navigationTitle(Text("settings.navTitle", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(String(localized: "settings.doneButton", bundle: .module)) {
                    isPresented = false
                }
                .fontWeight(.semibold)
                .accessibilityHint(Text("settings.doneButton.hint", bundle: .module))
                .accessibilityIdentifier("settings.doneButton")
            }
        }
        .sheet(isPresented: $showTerms) {
            LegalDocumentView(document: .terms)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalDocumentView(document: .privacy)
        }
        .onAppear {
            if vmBox.inner == nil {
                vmBox.inner = SettingsViewModel(
                    settings: settings,
                    scheduler: coordinator
                )
            }
        }
        .task {
            await coordinator.refreshAuthStatus()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(isPresented: .constant(true))
            .environmentObject(SettingsStore())
            .environmentObject(AppCoordinator())
    }
}
