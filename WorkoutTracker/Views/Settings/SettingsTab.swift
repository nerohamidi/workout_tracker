import SwiftUI

struct SettingsTab: View {
    @AppStorage("useMetric") private var useMetric = true
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dark
    /// User-supplied Gemini API key. Empty string means "use the build-time default
    /// from `Secrets.swift`". `GeminiClient.apiKey` reads from this exact key.
    @AppStorage("geminiAPIKeyOverride") private var geminiAPIKeyOverride = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Units") {
                    Picker("Weight", selection: $useMetric) {
                        Text("kg").tag(true)
                        Text("lbs").tag(false)
                    }
                    .pickerStyle(.segmented)

                    Text(useMetric ? "Distance in km" : "Distance in mi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Gemini API Key") {
                    SecureField("Paste API key (optional)", text: $geminiAPIKeyOverride)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Used by AI features. Leave blank to use the built-in key. Get one at aistudio.google.com.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: "2.0.0")
                    LabeledContent("App", value: "Workout Tracker")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
