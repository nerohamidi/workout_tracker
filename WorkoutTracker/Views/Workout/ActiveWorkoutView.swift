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
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Timer card
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Elapsed")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text(formattedElapsed)
                                .font(.system(.title, design: .monospaced, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(workout.exercises.count)")
                                .font(.title.weight(.bold))
                                .foregroundStyle(Color.accentColor)
                            Text("exercise\(workout.exercises.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal)

                    // MARK: - Exercise sections
                    ForEach(workout.sortedExercises) { exercise in
                        ExerciseCard(workoutExercise: exercise, onDelete: {
                            modelContext.delete(exercise)
                        })
                    }

                    // MARK: - Add exercise
                    Button {
                        showAddExercise = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("Add Exercise")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal)

                    // MARK: - Bottom actions
                    HStack(spacing: 12) {
                        Button {
                            showDiscardAlert = true
                        } label: {
                            Text("Discard")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(.systemGray5))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Button {
                            showFinishAlert = true
                        } label: {
                            Text("Finish Workout")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(workout.exercises.isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Active Workout")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ExerciseTemplate.self) { template in
                ExerciseDetailView(template: template)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showDiscardAlert = true } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
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
        workout.sourceSplit?.advance()
        try? modelContext.save()
        dismiss()
    }

    private func discardWorkout() {
        modelContext.delete(workout)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Exercise Card

struct ExerciseCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutExercise: WorkoutExercise
    var onDelete: () -> Void
    @State private var isSuggesting = false
    @State private var suggestError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(workoutExercise.exerciseTemplate?.name ?? "Exercise")
                    .font(.subheadline.weight(.bold))
                Spacer()
                if let template = workoutExercise.exerciseTemplate {
                    NavigationLink(value: template) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if workoutExercise.isCardio {
                CardioLogView(workoutExercise: workoutExercise)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            } else {
                // PR banner
                if let template = workoutExercise.exerciseTemplate {
                    PersonalRecordsBanner(template: template)
                }

                // Sets
                VStack(spacing: 0) {
                    // Column headers
                    HStack {
                        Text("SET")
                            .frame(width: 36, alignment: .leading)
                        Spacer()
                        Text("WEIGHT")
                            .frame(width: 80)
                        Spacer()
                        Text("REPS")
                            .frame(width: 60)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                    ForEach(workoutExercise.sortedSets) { set in
                        SetRowView(exerciseSet: set)
                    }
                }
                .padding(.bottom, 8)

                // Action buttons
                Divider()
                    .padding(.horizontal, 16)

                HStack(spacing: 0) {
                    Button { addSet() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.caption.weight(.bold))
                            Text("Add Set")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }

                    if workoutExercise.exerciseTemplate != nil {
                        Divider()
                            .frame(height: 20)

                        Button {
                            Task { await suggestSets() }
                        } label: {
                            HStack(spacing: 4) {
                                if isSuggesting {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.caption.weight(.bold))
                                }
                                Text("AI Suggest")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.purple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .disabled(isSuggesting)
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
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
}

// MARK: - Set Row

struct SetRowView: View {
    @Bindable var exerciseSet: ExerciseSet
    @AppStorage("useMetric") private var useMetric = true

    var body: some View {
        HStack {
            Text("\(exerciseSet.setNumber)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .leading)

            Spacer()

            HStack(spacing: 4) {
                TextField("0", value: $exerciseSet.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .frame(width: 56)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(useMetric ? "kg" : "lb")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 80)

            Spacer()

            HStack(spacing: 4) {
                TextField("0", value: $exerciseSet.reps, format: .number)
                    .keyboardType(.numberPad)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .frame(width: 44)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }
}

// MARK: - PR Banner

private struct PersonalRecordsBanner: View {
    let template: ExerciseTemplate
    @AppStorage("useMetric") private var useMetric = true

    private var records: [PersonalRecord] {
        PersonalRecord.records(for: template)
    }

    var body: some View {
        if !records.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text(records.map { "\($0.reps)x\(formatted($0.weight))\(useMetric ? "kg" : "lb")" }
                    .joined(separator: " / "))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.06))
        }
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

// MARK: - Cardio

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
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.accentColor)
        }
    }
}

struct CardioEntryRow: View {
    @Bindable var entry: CardioEntry
    let useMetric: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Duration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    TextField("0", value: $entry.durationMinutes, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.center)
                        .frame(width: 56)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text("min")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            HStack {
                Text("Distance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    TextField("0", value: $entry.distance, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.center)
                        .frame(width: 56)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text(useMetric ? "km" : "mi")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
