import SwiftUI

struct SettingsTab: View {
    @AppStorage("useMetric") private var useMetric = true

    var body: some View {
        NavigationStack {
            Form {
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
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("App", value: "Workout Tracker")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
