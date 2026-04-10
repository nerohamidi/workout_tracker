import SwiftUI

struct SettingsTab: View {
    @AppStorage("useMetric") private var useMetric = true
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dark

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

                Section("About") {
                    LabeledContent("Version", value: "1.9.0")
                    LabeledContent("App", value: "Workout Tracker")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
