import SwiftUI

struct HomeView: View {

    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var coordinator: AppCoordinator

    @State private var showSettings = false
    @AppStorage("openSettingsOnLaunch") private var openSettingsOnLaunch = false

    private var statusLabel: String {
        if settings.globalEnabled {
            return String(localized: "home.status.active", bundle: .module)
        } else {
            return String(localized: "home.status.paused", bundle: .module)
        }
    }

    private var statusIcon: String {
        settings.globalEnabled ? AppSymbol.eyeBreak : "moon.zzz.fill"
    }

    private var statusColor: Color {
        settings.globalEnabled ? AppColor.reminderBlue : .secondary
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: statusIcon)
                .resizable()
                .scaledToFit()
                .frame(width: AppLayout.overlayIconSize, height: AppLayout.overlayIconSize)
                .foregroundStyle(statusColor)
                .accessibilityHidden(true)
                .accessibilityIdentifier("home.statusIcon")

            VStack(spacing: AppSpacing.sm) {
                Text("home.title", bundle: .module)
                    .font(AppFont.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("home.title")

                Text(statusLabel)
                    .font(AppFont.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("home.statusLabel")
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
        .navigationTitle(Text("home.navTitle", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: AppSymbol.settings)
                        .accessibilityLabel(Text("home.settingsButton", bundle: .module))
                        .accessibilityHint(Text("home.settingsButton.hint", bundle: .module))
                }
                .accessibilityIdentifier("home.settingsButton")
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .environmentObject(settings)
                    .environmentObject(coordinator)
            }
        }
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
        .accessibilityElement(children: .contain)
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
