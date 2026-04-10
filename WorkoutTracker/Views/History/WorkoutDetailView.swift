import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let workout: Workout
    @AppStorage("useMetric") private var useMetric = true

    @State private var showSaveAsRoutine = false
    @State private var routineName = ""
    @State private var saveConfirmation: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: - Summary card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.date, style: .date)
                                .font(.headline.weight(.bold))
                            Text(workout.date, style: .time)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }

                    HStack(spacing: 20) {
                        statPill(icon: "clock", value: workout.formattedDuration)
                        statPill(icon: "figure.strengthtraining.traditional", value: "\(workout.exercises.count) exercises")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)

                // MARK: - Exercise cards
                ForEach(workout.sortedExercises) { exercise in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(exercise.exerciseTemplate?.name ?? "Exercise")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 16)
                            .padding(.top, 14)

                        if exercise.isCardio {
                            if let entry = exercise.cardioEntries.first {
                                HStack(spacing: 16) {
                                    if entry.durationMinutes > 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock")
                                                .font(.caption2)
                                            Text("\(formatted(entry.durationMinutes)) min")
                                                .font(.subheadline)
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                    if entry.distance > 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                                .font(.caption2)
                                            Text("\(formatted(entry.distance)) \(useMetric ? "km" : "mi")")
                                                .font(.subheadline)
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        } else {
                            VStack(spacing: 0) {
                                ForEach(exercise.sortedSets) { set in
                                    HStack {
                                        Text("Set \(set.setNumber)")
                                            .font(.subheadline)
                                            .foregroundStyle(.tertiary)
                                            .frame(width: 44, alignment: .leading)
                                        Spacer()
                                        if set.weight > 0 {
                                            Text("\(formatted(set.weight)) \(useMetric ? "kg" : "lbs")")
                                                .font(.subheadline.weight(.medium))
                                        }
                                        if set.reps > 0 {
                                            Text("x \(set.reps)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                }
                            }
                        }

                        Spacer().frame(height: 2)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    routineName = defaultRoutineName()
                    showSaveAsRoutine = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.subheadline)
                }
                .disabled(workout.exercises.isEmpty)
            }
        }
        .alert("Save as Routine", isPresented: $showSaveAsRoutine) {
            TextField("Routine name", text: $routineName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { saveAsRoutine() }
        } message: {
            Text("Creates a reusable routine with the same exercises.")
        }
        .alert("Routine Saved",
               isPresented: Binding(get: { saveConfirmation != nil },
                                    set: { if !$0 { saveConfirmation = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveConfirmation ?? "")
        }
    }

    private func statPill(icon: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
    }

    private func defaultRoutineName() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Routine \(formatter.string(from: workout.date))"
    }

    private func saveAsRoutine() {
        let trimmed = routineName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let routine = Routine(name: trimmed)
        modelContext.insert(routine)
        for (index, exercise) in workout.sortedExercises.enumerated() {
            guard let template = exercise.exerciseTemplate else { continue }
            let entry = RoutineExercise(order: index)
            routine.exercises.append(entry)
            entry.exerciseTemplate = template
        }
        try? modelContext.save()
        saveConfirmation = "\"\(trimmed)\" is now in your routines."
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
