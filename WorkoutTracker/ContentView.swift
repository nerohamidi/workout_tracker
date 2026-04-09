import SwiftUI

struct ContentView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dark

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                modernTabView
            } else {
                legacyTabView
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
    }

    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView {
            Tab("Workout", systemImage: "figure.strengthtraining.traditional") {
                WorkoutTab()
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryTab()
            }
            Tab("Exercises", systemImage: "dumbbell") {
                ExercisesTab()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsTab()
            }
        }
    }

    private var legacyTabView: some View {
        TabView {
            WorkoutTab()
                .tabItem {
                    Label("Workout", systemImage: "figure.strengthtraining.traditional")
                }
            HistoryTab()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            ExercisesTab()
                .tabItem {
                    Label("Exercises", systemImage: "dumbbell")
                }
            SettingsTab()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

enum AppearanceMode: String, CaseIterable {
    case dark = "Dark"
    case light = "Light"
    case system = "System"

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}
