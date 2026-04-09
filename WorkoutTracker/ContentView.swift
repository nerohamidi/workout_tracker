import SwiftUI

struct ContentView: View {
    var body: some View {
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
