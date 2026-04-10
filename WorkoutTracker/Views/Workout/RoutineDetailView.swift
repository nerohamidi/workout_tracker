import SwiftUI
import SwiftData

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var routine: Routine

    @State private var showEditForm = false
    @State private var showDeleteConfirm = false
    @State private var startedWorkout: Workout?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: - Start button
                Button {
                    startWorkoutFromRoutine()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.subheadline)
                        Text("Start Workout")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(routine.exercises.isEmpty)
                .padding(.horizontal)

                // MARK: - Exercises
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exercises")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)

                    if routine.sortedExercises.isEmpty {
                        Text("No exercises in this routine")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal)
                    } else {
                        VStack(spacing: 1) {
                            ForEach(Array(routine.sortedExercises.enumerated()), id: \.element.persistentModelID) { index, entry in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.exerciseTemplate?.name ?? "Exercise")
                                            .font(.subheadline.weight(.medium))
                                        if !entry.sortedDefaultSets.isEmpty {
                                            Text(entry.sortedDefaultSets
                                                .map { "\($0.reps)x\(formatWeight($0.weight))kg" }
                                                .joined(separator: " / "))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if let group = entry.exerciseTemplate?.muscleGroup {
                                        Text(group.rawValue)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color(.systemGray5))
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.secondarySystemGroupedBackground))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal)
                    }
                }

                // MARK: - Actions
                VStack(spacing: 1) {
                    Button {
                        showEditForm = true
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                                .font(.subheadline)
                            Text("Edit Routine")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .font(.subheadline)
                            Text("Delete Routine")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                    }
                    .buttonStyle(.plain)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
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
            Text("This routine will be removed. Past workouts are not affected.")
        }
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private func startWorkoutFromRoutine() {
        let workout = Workout()
        modelContext.insert(workout)

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
