import SwiftUI

struct SettingsTab: View {
    @AppStorage("useMetric") private var useMetric = true
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dark
    @AppStorage("geminiAPIKeyOverride") private var geminiAPIKeyOverride = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Appearance
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Appearance")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            HStack(spacing: 8) {
                                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                    Button {
                                        appearanceMode = mode
                                    } label: {
                                        Text(mode.rawValue)
                                            .font(.subheadline.weight(.medium))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(appearanceMode == mode ? Color.accentColor : Color(.systemGray5))
                                            .foregroundStyle(appearanceMode == mode ? .white : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // MARK: - Units
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Units")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            HStack(spacing: 8) {
                                unitButton("kg / km", isSelected: useMetric) { useMetric = true }
                                unitButton("lbs / mi", isSelected: !useMetric) { useMetric = false }
                            }
                        }
                    }

                    // MARK: - Gemini
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Gemini API")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

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

                    // MARK: - About
                    settingsCard {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Version")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("2.2.0")
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
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func unitButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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
