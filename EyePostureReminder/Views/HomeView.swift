import SwiftUI

struct HomeView: View {

    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: AppCoordinator

    @State private var showSettings = false
    @AppStorage(AppStorageKey.openSettingsOnLaunch) private var openSettingsOnLaunch = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var statusLabel: String {
        if settings.globalEnabled {
            return String(localized: "home.status.active", bundle: .module)
        } else {
            return String(localized: "home.status.paused", bundle: .module)
        }
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            VStack(spacing: AppSpacing.lg) {
                YinYangEyeView()

                // Status copy crossfades as a unit when globalEnabled changes.
                ZStack {
                    VStack(spacing: AppSpacing.sm) {
                        Text("home.title", bundle: .module)
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("home.title")

                        Text(statusLabel)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("home.statusLabel")
                    }
                    .id(settings.globalEnabled)
                    .transition(.opacity)
                }
                .animation(reduceMotion ? nil : AppAnimation.statusCrossfadeCurve, value: settings.globalEnabled)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(Text("home.navTitle", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: AppSymbol.settings)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppColor.primaryRest)
                        .accessibilityLabel(Text("home.settingsButton", bundle: .module))
                        .accessibilityHint(Text("home.settingsButton.hint", bundle: .module))
                }
                .accessibilityIdentifier("home.settingsButton")
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(isPresented: $showSettings)
                    .environmentObject(settings)
                    .environmentObject(coordinator)
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .onAppear {
            if openSettingsOnLaunch {
                openSettingsOnLaunch = false
                showSettings = true
            }
        }
        .onChange(of: openSettingsOnLaunch) { newValue in
            if newValue {
                openSettingsOnLaunch = false
                showSettings = true
            }
        }
    }
}

#Preview {
    let coordinator = AppCoordinator()
    NavigationStack {
        HomeView()
            .environmentObject(coordinator.settings)
            .environmentObject(coordinator)
    }
}
