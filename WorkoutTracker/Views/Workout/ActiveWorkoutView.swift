import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: Workout
    @State private var showAddExercise = false
    @State private var showFinishAlert = false
    @State private var showDiscardAlert = false
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label(formattedElapsed, systemImage: "clock")
                            .font(.headline)
                            .monospacedDigit()
                        Spacer()
                        Text("\(workout.exercises.count) exercise\(workout.exercises.count == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(workout.sortedExercises) { exercise in
                    ExerciseSection(workoutExercise: exercise)
                }
                .onDelete(perform: deleteExercises)

                Section {
                    Button {
                        showAddExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Active Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        showDiscardAlert = true
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        showFinishAlert = true
                    }
                    .fontWeight(.semibold)
                    .disabled(workout.exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showAddExercise) {
                AddExerciseSheet(workout: workout)
            }
            .alert("Finish Workout?", isPresented: $showFinishAlert) {
                Button("Finish", role: .destructive) { finishWorkout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Save this workout to your history.")
            }
            .alert("Discard Workout?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) { discardWorkout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This workout will not be saved.")
            }
            .onAppear { startTimer() }
            .onDisappear { stopTimer() }
        }
    }

    private var formattedElapsed: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func finishWorkout() {
        workout.durationSeconds = elapsedSeconds
        workout.isCompleted = true
        try? modelContext.save()
        dismiss()
    }

    private func discardWorkout() {
        modelContext.delete(workout)
        try? modelContext.save()
        dismiss()
    }

    private func deleteExercises(at offsets: IndexSet) {
        let sorted = workout.sortedExercises
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

struct ExerciseSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutExercise: WorkoutExercise

    var body: some View {
        Section(header: Text(workoutExercise.exerciseTemplate?.name ?? "Exercise")) {
            if workoutExercise.isCardio {
                CardioLogView(workoutExercise: workoutExercise)
            } else {
                ForEach(workoutExercise.sortedSets) { set in
                    SetRowView(exerciseSet: set)
                }
                .onDelete(perform: deleteSets)

                Button {
                    addSet()
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.subheadline)
                }
            }
        }
    }

    private func addSet() {
        let nextNumber = (workoutExercise.sets.map(\.setNumber).max() ?? 0) + 1
        let set = ExerciseSet(setNumber: nextNumber, workoutExercise: workoutExercise)
        modelContext.insert(set)
    }

    private func deleteSets(at offsets: IndexSet) {
        let sorted = workoutExercise.sortedSets
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

struct SetRowView: View {
    @Bindable var exerciseSet: ExerciseSet
    @AppStorage("useMetric") private var useMetric = true

    var body: some View {
        HStack {
            Text("Set \(exerciseSet.setNumber)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            HStack(spacing: 4) {
                TextField("0", value: $exerciseSet.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Text(useMetric ? "kg" : "lbs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                TextField("0", value: $exerciseSet.reps, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                Text("reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CardioLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutExercise: WorkoutExercise
    @AppStorage("useMetric") private var useMetric = true

    var entry: CardioEntry? {
        workoutExercise.cardioEntries.first
    }

    var body: some View {
        if let entry = entry {
            CardioEntryRow(entry: entry, useMetric: useMetric)
        } else {
            Button("Log Cardio") {
                let entry = CardioEntry(workoutExercise: workoutExercise)
                modelContext.insert(entry)
            }
        }
    }
}

struct CardioEntryRow: View {
    @Bindable var entry: CardioEntry
    let useMetric: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Duration")
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    TextField("0", value: $entry.durationMinutes, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Text("min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Distance")
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    TextField("0", value: $entry.distance, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Text(useMetric ? "km" : "mi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
