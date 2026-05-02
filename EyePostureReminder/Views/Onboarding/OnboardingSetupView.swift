// OnboardingSetupView.swift
// kshana
//
// Onboarding Screen 3 — Reminder Schedule Setup.
// Users choose their eye break and posture check windows before getting started.
// Selections bind directly to SettingsStore so Settings shows the same values later.

import SwiftUI

struct OnboardingSetupView: View {
    let onGetStarted: () -> Void
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: AppSpacing.xl)

                // Headline + subheadline
                VStack(spacing: AppSpacing.sm) {
                    Text("onboarding.setup.title", bundle: .module)
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("onboarding.setup.subtitle", bundle: .module)
                        .font(AppFont.bodyEmphasized)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Interactive reminder picker cards
                VStack(spacing: AppSpacing.md) {
                    OnboardingReminderPickerCard(
                        icon: AppSymbol.eyeBreak,
                        color: AppColor.primaryRest,
                        title: String(localized: "onboarding.setup.eyeBreaks.title", bundle: .module),
                        typeID: "eyes",
                        intervalKey: .eyesInterval,
                        durationKey: .eyesBreakDuration,
                        interval: $settings.eyesInterval,
                        breakDuration: $settings.eyesBreakDuration
                    )
                    OnboardingReminderPickerCard(
                        icon: AppSymbol.postureCheck,
                        color: AppColor.secondaryCalm,
                        title: String(localized: "onboarding.setup.postureChecks.title", bundle: .module),
                        typeID: "posture",
                        intervalKey: .postureInterval,
                        durationKey: .postureBreakDuration,
                        interval: $settings.postureInterval,
                        breakDuration: $settings.postureBreakDuration
                    )
                }
                .padding(.horizontal, AppSpacing.md)

                // Reassurance: these choices are saved and can be changed later
                Text("onboarding.setup.changeInSettings", bundle: .module)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.sm)
                    .accessibilityIdentifier("onboarding.setup.changeInSettings")

                Spacer(minLength: AppSpacing.lg)

                // Primary CTA
                Button(action: onGetStarted) {
                    Text("onboarding.setup.getStartedButton", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .padding(.horizontal, AppSpacing.xl)
                .accessibilityLabel(Text("onboarding.setup.getStartedButton", bundle: .module))
                .accessibilityHint(Text("onboarding.setup.getStartedButton.hint", bundle: .module))
                .accessibilityIdentifier("onboarding.setup.getStartedButton")
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: AppLayout.onboardingMaxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(AppColor.background.ignoresSafeArea())
        .calmingEntrance()
    }
}

// MARK: - Onboarding Reminder Picker Card

/// Interactive card for picking an interval and break duration during onboarding.
/// Binds directly to SettingsStore so the values persist and appear in Settings later.
private struct OnboardingReminderPickerCard: View {
    let icon: String
    let color: Color
    let title: String
    /// Stable, localisation-safe identifier used for accessibility identifiers (e.g. "eyes", "posture").
    let typeID: String
    let intervalKey: AnalyticsEvent.SettingKey
    let durationKey: AnalyticsEvent.SettingKey
    @Binding var interval: TimeInterval
    @Binding var breakDuration: TimeInterval
    @State private var prevInterval: TimeInterval = .zero
    @State private var prevBreakDuration: TimeInterval = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {

            // Card header: icon + type title
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .symbolRenderingMode(.hierarchical)
                    .font(AppFont.reminderCardIcon)
                    .foregroundStyle(color)
                    .frame(width: AppLayout.decorativeIconFrame, height: AppLayout.decorativeIconFrame)
                    .background(
                        RoundedRectangle(cornerRadius: AppLayout.radiusSmall, style: .continuous)
                            .fill(AppColor.surfaceTint)
                    )
                    .accessibilityHidden(true)
                Text(title)
                    .font(AppFont.bodyEmphasized)
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
            }

            Divider()

            // Interval picker — how often the reminder fires
            Picker(String(localized: "onboarding.setup.picker.every", bundle: .module), selection: $interval) {
                ForEach(SettingsViewModel.intervalOptions, id: \.self) { seconds in
                    Text(SettingsViewModel.labelForInterval(seconds)).tag(seconds)
                }
            }
            .accessibilityIdentifier("onboarding.\(typeID).intervalPicker")
            .accessibilityHint(
                String(
                    format: String(localized: "settings.reminder.intervalPicker.hint", bundle: .module),
                    title
                )
            )
            .onChange(of: interval) { _, newValue in
                AnalyticsLogger.log(.settingChanged(
                    setting: intervalKey,
                    oldValue: String(prevInterval),
                    newValue: String(newValue)
                ))
                prevInterval = newValue
            }

            // Break duration picker — how long each break lasts
            Picker(String(localized: "onboarding.setup.picker.breakFor", bundle: .module), selection: $breakDuration) {
                ForEach(SettingsViewModel.breakDurationOptions, id: \.self) { seconds in
                    Text(SettingsViewModel.labelForBreakDuration(seconds)).tag(seconds)
                }
            }
            .accessibilityIdentifier("onboarding.\(typeID).durationPicker")
            .accessibilityHint(
                String(
                    format: String(localized: "settings.reminder.durationPicker.hint", bundle: .module),
                    title
                )
            )
            .onChange(of: breakDuration) { _, newValue in
                AnalyticsLogger.log(.settingChanged(
                    setting: durationKey,
                    oldValue: String(prevBreakDuration),
                    newValue: String(newValue)
                ))
                prevBreakDuration = newValue
            }
        }
        .onAppear {
            prevInterval = interval
            prevBreakDuration = breakDuration
        }
        .padding(AppSpacing.lg)
        .wellnessCard(elevated: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(cardAccessibilityLabel)
    }

    private var cardAccessibilityLabel: String {
        String(
            format: String(localized: "onboarding.setup.card.label", bundle: .module),
            title,
            SettingsViewModel.labelForInterval(interval),
            SettingsViewModel.labelForBreakDuration(breakDuration)
        )
    }
}

#Preview {
    OnboardingSetupView(onGetStarted: {})
        .environmentObject(SettingsStore())
}
