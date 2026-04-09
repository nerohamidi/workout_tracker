import SwiftUI
import SwiftData

/// Shows a routine's exercises and provides actions to start a workout from it,
/// edit the routine, or delete it.
struct RoutineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var routine: Routine

    @State private var showEditForm = false
    @State private var showDeleteConfirm = false
    @State private var startedWorkout: Workout?

    var body: some View {
        List {
            Section("Exercises") {
                if routine.sortedExercises.isEmpty {
                    Text("No exercises in this routine")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(routine.sortedExercises) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.exerciseTemplate?.name ?? "Exercise")
                                if let category = entry.exerciseTemplate?.category {
                                    Text(category.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if let group = entry.exerciseTemplate?.muscleGroup {
                                Text(group.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    startWorkoutFromRoutine()
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(routine.exercises.isEmpty)
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Routine", systemImage: "trash")
                }
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditForm = true }
            }
        }
        .sheet(isPresented: $showEditForm) {
            RoutineFormView(routine: routine)
        }
        .fullScreenCover(item: $startedWorkout) { workout in
            ActiveWorkoutView(workout: workout)
        }
        .confirmationDialog("Delete \(routine.name)?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(routine)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This routine will be removed. Past workouts started from it are not affected.")
        }
    }

    /// Creates a new in-progress workout populated with the routine's exercises.
    /// Each routine entry becomes a `WorkoutExercise` with one starter set (or
    /// cardio entry, depending on category) — same shape as `AddExerciseSheet`.
    private func startWorkoutFromRoutine() {
        let workout = Workout()
        modelContext.insert(workout)

        for (index, entry) in routine.sortedExercises.enumerated() {
            guard let template = entry.exerciseTemplate else { continue }
            let workoutExercise = WorkoutExercise(order: index)
            workout.exercises.append(workoutExercise)
            workoutExercise.exerciseTemplate = template

            if template.category == .strength {
                workoutExercise.sets.append(ExerciseSet(setNumber: 1))
            } else {
                workoutExercise.cardioEntries.append(CardioEntry())
            }
        }
        try? modelContext.save()
        startedWorkout = workout
    }
}
