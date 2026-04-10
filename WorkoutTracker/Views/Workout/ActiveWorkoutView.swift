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
            .navigationDestination(for: ExerciseTemplate.self) { template in
                ExerciseDetailView(template: template)
            }
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
        // If this workout was started from a split, advance the rotation so the next
        // visit to the split detail view shows the following routine as "Next".
        workout.sourceSplit?.advance()
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
    @State private var isSuggesting = false
    @State private var suggestError: String?

    var body: some View {
        Section {
            if workoutExercise.isCardio {
                CardioLogView(workoutExercise: workoutExercise)
            } else {
                // Show past PRs as a target. `PersonalRecord.records(for:)` excludes
                // in-progress workouts, so the current session never appears here —
                // these are strictly historical maxes the user is trying to beat.
                if let template = workoutExercise.exerciseTemplate {
                    PersonalRecordsBanner(template: template)
                }

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

                if workoutExercise.exerciseTemplate != nil {
                    Button {
                        Task { await suggestSets() }
                    } label: {
                        HStack {
                            if isSuggesting {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Label("Suggest Sets with AI", systemImage: "sparkles")
                                .font(.subheadline)
                        }
                    }
                    .disabled(isSuggesting)
                }
            }
        } header: {
            HStack {
                Text(workoutExercise.exerciseTemplate?.name ?? "Exercise")
                Spacer()
                if let template = workoutExercise.exerciseTemplate {
                    NavigationLink(value: template) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("View history and progression")
                }
            }
        }
        .alert("Couldn't Suggest Sets", isPresented: Binding(
            get: { suggestError != nil },
            set: { if !$0 { suggestError = nil } }
        ), presenting: suggestError) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }

    private func addSet() {
        let nextNumber = (workoutExercise.sets.map(\.setNumber).max() ?? 0) + 1
        let set = ExerciseSet(setNumber: nextNumber, workoutExercise: workoutExercise)
        modelContext.insert(set)
    }

    /// Ask Gemini for a set scheme based on the user's PR history for this exercise
    /// and append the suggestions as new ExerciseSet rows. Existing sets are kept —
    /// the suggestions are added on top so the user can compare or remove them.
    private func suggestSets() async {
        guard let template = workoutExercise.exerciseTemplate else { return }
        isSuggesting = true
        defer { isSuggesting = false }
        do {
            let result = try await AISetSuggester.suggest(for: template)
            var nextNumber = (workoutExercise.sets.map(\.setNumber).max() ?? 0) + 1
            for suggestion in result.sets {
                let set = ExerciseSet(setNumber: nextNumber, workoutExercise: workoutExercise)
                set.reps = suggestion.reps
                set.weight = suggestion.weight
                modelContext.insert(set)
                nextNumber += 1
            }
        } catch {
            suggestError = error.localizedDescription
        }
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

/// Compact read-only banner that lists the user's existing PRs for an exercise as a
/// reference target during an active workout. Renders nothing if there are no PRs yet
/// (so the first-ever workout for an exercise stays uncluttered).
private struct PersonalRecordsBanner: View {
    let template: ExerciseTemplate
    @AppStorage("useMetric") private var useMetric = true

    private var records: [PersonalRecord] {
        PersonalRecord.records(for: template)
    }

    var body: some View {
        if !records.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personal Records")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(records.map { "\($0.reps)×\(formatted($0.weight))\(useMetric ? "kg" : "lb")" }
                        .joined(separator: "  ·  "))
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
            }
            .listRowBackground(Color.orange.opacity(0.08))
        }
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
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
