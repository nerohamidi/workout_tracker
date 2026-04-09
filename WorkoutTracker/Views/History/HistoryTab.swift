import SwiftUI
import SwiftData

struct HistoryTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { $0.isCompleted },
           sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Completed workouts will appear here.")
                    )
                } else {
                    List {
                        ForEach(workouts) { workout in
                            NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                                WorkoutRowView(workout: workout)
                            }
                        }
                        .onDelete(perform: deleteWorkouts)
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private func deleteWorkouts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
    }
}

struct WorkoutRowView: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.date, style: .date)
                .font(.headline)
            HStack(spacing: 12) {
                Label(workout.formattedDuration, systemImage: "clock")
                Label("\(workout.exercises.count) exercise\(workout.exercises.count == 1 ? "" : "s")", systemImage: "figure.strengthtraining.traditional")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !workout.exercises.isEmpty {
                Text(workout.sortedExercises.compactMap { $0.exerciseTemplate?.name }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
