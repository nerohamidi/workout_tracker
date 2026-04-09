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
        List {
            Section("Summary") {
                LabeledContent("Date", value: workout.date, format: .dateTime.month().day().year())
                LabeledContent("Duration", value: workout.formattedDuration)
                LabeledContent("Exercises", value: "\(workout.exercises.count)")
                if !workout.notes.isEmpty {
                    LabeledContent("Notes", value: workout.notes)
                }
            }

            ForEach(workout.sortedExercises) { exercise in
                Section(exercise.exerciseTemplate?.name ?? "Exercise") {
                    if exercise.isCardio {
                        if let entry = exercise.cardioEntries.first {
                            if entry.durationMinutes > 0 {
                                LabeledContent("Duration", value: "\(formatted(entry.durationMinutes)) min")
                            }
                            if entry.distance > 0 {
                                LabeledContent("Distance", value: "\(formatted(entry.distance)) \(useMetric ? "km" : "mi")")
                            }
                        }
                    } else {
                        ForEach(exercise.sortedSets) { set in
                            HStack {
                                Text("Set \(set.setNumber)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if set.weight > 0 {
                                    Text("\(formatted(set.weight)) \(useMetric ? "kg" : "lbs")")
                                }
                                if set.reps > 0 {
                                    Text("× \(set.reps) reps")
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    routineName = defaultRoutineName()
                    showSaveAsRoutine = true
                } label: {
                    Label("Save as Routine", systemImage: "square.and.arrow.down")
                }
                .disabled(workout.exercises.isEmpty)
            }
        }
        .alert("Save as Routine", isPresented: $showSaveAsRoutine) {
            TextField("Routine name", text: $routineName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { saveAsRoutine() }
        } message: {
            Text("Creates a reusable routine with the same exercises as this workout.")
        }
        .alert("Routine Saved",
               isPresented: Binding(get: { saveConfirmation != nil },
                                    set: { if !$0 { saveConfirmation = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveConfirmation ?? "")
        }
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
