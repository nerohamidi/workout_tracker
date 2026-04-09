import SwiftUI
import SwiftData

struct AddExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workout: Workout

    @Query(sort: \ExerciseTemplate.name) private var allExercises: [ExerciseTemplate]
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?

    private var filteredExercises: [ExerciseTemplate] {
        allExercises.filter { exercise in
            let matchesSearch = searchText.isEmpty ||
                exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil ||
                exercise.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    private var groupedExercises: [(MuscleGroup, [ExerciseTemplate])] {
        let grouped = Dictionary(grouping: filteredExercises, by: \.muscleGroup)
        return MuscleGroup.allCases.compactMap { group in
            guard let exercises = grouped[group], !exercises.isEmpty else { return nil }
            return (group, exercises)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag(nil as ExerciseCategory?)
                    ForEach(ExerciseCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category as ExerciseCategory?)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.horizontal)

                ForEach(groupedExercises, id: \.0) { group, exercises in
                    Section(group.rawValue) {
                        ForEach(exercises) { exercise in
                            ExerciseRowButton(exercise: exercise) {
                                addExercise(exercise)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addExercise(_ template: ExerciseTemplate) {
        let nextOrder = (workout.exercises.map(\.order).max() ?? -1) + 1
        let workoutExercise = WorkoutExercise(
            order: nextOrder,
            exerciseTemplate: template,
            workout: workout
        )
        modelContext.insert(workoutExercise)

        if template.category == .strength {
            let firstSet = ExerciseSet(setNumber: 1, workoutExercise: workoutExercise)
            modelContext.insert(firstSet)
        } else {
            let cardioEntry = CardioEntry(workoutExercise: workoutExercise)
            modelContext.insert(cardioEntry)
        }
    }
}

private struct ExerciseRowButton: View {
    let exercise: ExerciseTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(exercise.name)
                    .foregroundStyle(.primary)
                Spacer()
                if exercise.isCustom {
                    Text("Custom")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "plus.circle")
                    .foregroundStyle(.tint)
            }
        }
    }
}
