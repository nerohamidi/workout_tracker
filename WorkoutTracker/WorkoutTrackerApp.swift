import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    let sharedModelContainer: ModelContainer

    init() {
        let schema = Schema([
            ExerciseTemplate.self,
            Workout.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            CardioEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            ExerciseLibrary.seedIfNeeded(modelContext: container.mainContext)
            self.sharedModelContainer = container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
