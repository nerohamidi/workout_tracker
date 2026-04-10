import SwiftUI
import SwiftData

struct SplitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var split: TrainingSplit

    @State private var showEditForm = false
    @State private var showDeleteConfirm = false
    @State private var startedWorkout: Workout?

    private var sortedEntries: [SplitRoutine] { split.sortedRoutines }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: - Start next
                if let next = split.nextRoutine {
                    Button {
                        startNextWorkout()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                                .font(.subheadline)
                            Text("Start \(next.name)")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal)
                }

                // MARK: - Rotation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rotation")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)

                    if sortedEntries.isEmpty {
                        Text("No routines in this split")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal)
                    } else {
                        VStack(spacing: 1) {
                            ForEach(Array(sortedEntries.enumerated()), id: \.element.persistentModelID) { index, entry in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.routine?.name ?? "Removed routine")
                                            .font(.subheadline.weight(.medium))
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
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor)
                                            .foregroundStyle(.white)
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
                        split.advance()
                        try? modelContext.save()
                    } label: {
                        HStack {
                            Image(systemName: "forward.fill")
                                .font(.subheadline)
                            Text("Skip to Next")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                    }
                    .buttonStyle(.plain)
                    .disabled(sortedEntries.count < 2)

                    Button {
                        showEditForm = true
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                                .font(.subheadline)
                            Text("Edit Split")
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
                            Text("Delete Split")
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
        .navigationTitle(split.name)
        .navigationBarTitleDisplayMode(.inline)
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
            Text("The routines inside it are not affected.")
        }
    }

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
