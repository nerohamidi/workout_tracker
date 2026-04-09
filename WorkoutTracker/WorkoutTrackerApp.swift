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

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema mismatch from prior runs — delete the old store and retry
            let url = modelConfiguration.url
            let relatedFiles = [url, url.deletingPathExtension().appendingPathExtension("store-shm"), url.deletingPathExtension().appendingPathExtension("store-wal")]
            for file in relatedFiles {
                try? FileManager.default.removeItem(at: file)
            }
            do {
                container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }

        ExerciseLibrary.seedIfNeeded(modelContext: container.mainContext)
        self.sharedModelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
