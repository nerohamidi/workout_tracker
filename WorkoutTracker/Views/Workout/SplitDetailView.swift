import SwiftUI
import SwiftData

/// Shows a split's routines in rotation order, highlights which one is up next,
/// and provides actions to start the next workout, edit the split, or delete it.
///
/// Starting a workout from here stamps the new `Workout` with `sourceSplit = self`,
/// which is what `ActiveWorkoutView` uses on Finish to advance the rotation.
struct SplitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var split: TrainingSplit

    @State private var showEditForm = false
    @State private var showDeleteConfirm = false
    @State private var startedWorkout: Workout?

    private var sortedEntries: [SplitRoutine] { split.sortedRoutines }

    var body: some View {
        List {
            Section("Rotation") {
                if sortedEntries.isEmpty {
                    Text("No routines in this split")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(sortedEntries.enumerated()), id: \.element.persistentModelID) { index, entry in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.routine?.name ?? "Removed routine")
                                    .foregroundStyle(entry.routine == nil ? .secondary : .primary)
                                if let routine = entry.routine {
                                    Text("\(routine.exercises.count) exercise\(routine.exercises.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if index == split.currentIndex {
                                Text("Next")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    startNextWorkout()
                } label: {
                    if let next = split.nextRoutine {
                        Label("Start \(next.name)", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Start Workout", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(split.nextRoutine == nil)
            }

            Section {
                Button {
                    split.advance()
                    try? modelContext.save()
                } label: {
                    Label("Skip to Next", systemImage: "forward.fill")
                }
                .disabled(sortedEntries.count < 2)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Split", systemImage: "trash")
                }
            }
        }
        .navigationTitle(split.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditForm = true }
            }
        }
        .sheet(isPresented: $showEditForm) {
            SplitFormView(split: split)
        }
        .fullScreenCover(item: $startedWorkout) { workout in
            ActiveWorkoutView(workout: workout)
        }
        .confirmationDialog("Delete \(split.name)?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(split)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This split will be removed. The routines inside it are not affected.")
        }
    }

    /// Builds a fresh workout from the split's current routine, mirroring
    /// `RoutineDetailView.startWorkoutFromRoutine` but additionally stamping
    /// `sourceSplit` so the rotation can advance on Finish.
    private func startNextWorkout() {
        guard let routine = split.nextRoutine else { return }

        let workout = Workout()
        modelContext.insert(workout)
        workout.sourceSplit = split

        for (index, entry) in routine.sortedExercises.enumerated() {
            guard let template = entry.exerciseTemplate else { continue }
            let workoutExercise = WorkoutExercise(order: index)
            workout.exercises.append(workoutExercise)
            workoutExercise.exerciseTemplate = template

            if template.category == .strength {
                let defaults = entry.sortedDefaultSets
                if defaults.isEmpty {
                    workoutExercise.sets.append(ExerciseSet(setNumber: 1))
                } else {
                    for ds in defaults {
                        workoutExercise.sets.append(
                            ExerciseSet(setNumber: ds.setNumber, reps: ds.reps, weight: ds.weight)
                        )
                    }
                }
            } else {
                workoutExercise.cardioEntries.append(CardioEntry())
            }
        }
        try? modelContext.save()
        startedWorkout = workout
    }
}
