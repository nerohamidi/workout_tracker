import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @AppStorage("useMetric") private var useMetric = true

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
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
