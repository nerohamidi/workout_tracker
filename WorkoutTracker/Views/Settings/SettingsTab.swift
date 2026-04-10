import SwiftUI

struct SettingsTab: View {
    @AppStorage("useMetric") private var useMetric = true
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dark
    @AppStorage("geminiAPIKeyOverride") private var geminiAPIKeyOverride = ""
    @AppStorage("geminiModel") private var geminiModel: GeminiModel = .flashLite
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Current Plan
                    planCard

                    // MARK: - Appearance
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("Appearance")
                            HStack(spacing: 8) {
                                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                    toggleButton(mode.rawValue, isSelected: appearanceMode == mode) {
                                        appearanceMode = mode
                                    }
                                }
                            }
                        }
                    }

                    // MARK: - Units
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("Units")
                            HStack(spacing: 8) {
                                toggleButton("kg / km", isSelected: useMetric) { useMetric = true }
                                toggleButton("lbs / mi", isSelected: !useMetric) { useMetric = false }
                            }
                        }
                    }

                    // MARK: - Gemini AI
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("Gemini AI")

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Model")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    ForEach(GeminiModel.allCases, id: \.self) { model in
                                        modelButton(for: model)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("API Key")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                SecureField("API key (optional)", text: $geminiAPIKeyOverride)
                                    .font(.subheadline)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(12)
                                    .background(Color(.systemGray5))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                Text("Leave blank to use the built-in key.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    // MARK: - About
                    settingsCard {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Version")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("2.3.0")
                                    .font(.subheadline.weight(.medium))
                            }
                            Divider()
                            HStack {
                                Text("App")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Workout Tracker")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Plan Card

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscriptionManager.currentPlan.displayName)
                        .font(.headline.weight(.bold))
                    Text(subscriptionManager.currentPlan.priceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if subscriptionManager.currentPlan != .pro {
                    Button {
                        showPaywall = true
                    } label: {
                        Text("Upgrade")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }

            Divider()

            // Usage
            HStack(spacing: 16) {
                usagePill(label: "AI Routines", value: subscriptionManager.remainingAIRoutines)
                usagePill(label: "AI Splits", value: subscriptionManager.remainingAISplits)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func usagePill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Model Button

    @ViewBuilder
    private func modelButton(for model: GeminiModel) -> some View {
        let available = subscriptionManager.currentPlan.availableModels.contains(model)
        let isSelected = geminiModel == model && available
        let bg: Color = isSelected ? Color.accentColor : Color(.systemGray5)
        let fg: Color = isSelected ? .white : (available ? .primary : Color(.tertiaryLabel))

        Button {
            if available { geminiModel = model }
            else { showPaywall = true }
        } label: {
            HStack(spacing: 4) {
                Text(model.displayName)
                    .font(.caption.weight(.semibold))
                if !available {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func toggleButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
