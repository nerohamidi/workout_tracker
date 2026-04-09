import SwiftUI
import SwiftData

struct AddExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workout: Workout

    @Query(sort: \ExerciseTemplate.name) private var allExercises: [ExerciseTemplate]
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var multiSelectMode = false
    @State private var selectedExercises: Set<PersistentIdentifier> = []
    @State private var showCreateExercise = false

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

                Section {
                    Button {
                        showCreateExercise = true
                    } label: {
                        Label("Create New Exercise", systemImage: "plus.circle.fill")
                    }
                }

                ForEach(groupedExercises, id: \.0) { group, exercises in
                    Section(group.rawValue) {
                        ForEach(exercises) { exercise in
                            ExerciseRow(
                                exercise: exercise,
                                multiSelectMode: multiSelectMode,
                                isSelected: selectedExercises.contains(exercise.persistentModelID)
                            ) {
                                handleTap(exercise)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle(multiSelectMode ? "Select Exercises" : "Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCreateExercise) {
                AddExerciseForm()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(multiSelectMode ? "Cancel" : "Done") {
                        if multiSelectMode {
                            selectedExercises.removeAll()
                            multiSelectMode = false
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if multiSelectMode {
                        Button("Add (\(selectedExercises.count))") {
                            addSelectedExercises()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedExercises.isEmpty)
                    } else {
                        Button {
                            multiSelectMode = true
                        } label: {
                            Image(systemName: "checklist")
                        }
                    }
                }
            }
        }
    }

    private func handleTap(_ exercise: ExerciseTemplate) {
        if multiSelectMode {
            let id = exercise.persistentModelID
            if selectedExercises.contains(id) {
                selectedExercises.remove(id)
            } else {
                selectedExercises.insert(id)
            }
        } else {
            addExercise(exercise)
            dismiss()
        }
    }

    private func addSelectedExercises() {
        let exercisesToAdd = allExercises.filter { selectedExercises.contains($0.persistentModelID) }
        for exercise in exercisesToAdd {
            addExercise(exercise)
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

private struct ExerciseRow: View {
    let exercise: ExerciseTemplate
    let multiSelectMode: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if multiSelectMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }
                Text(exercise.name)
                    .foregroundStyle(.primary)
                Spacer()
                if exercise.isCustom {
                    Text("Custom")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !multiSelectMode {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.tint)
                }
            }
        }
    }
}
