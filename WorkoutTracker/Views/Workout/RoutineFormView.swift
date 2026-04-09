import SwiftUI
import SwiftData

/// Create or edit a routine. Reused for both new routines (pass `nil`) and editing
/// an existing one. Exercises are added via a sheet that mirrors `AddExerciseSheet`.
struct RoutineFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Existing routine to edit, or `nil` to create a new one.
    var routine: Routine?

    @State private var name: String = ""
    @State private var notes: String = ""
    /// Working copy of the exercise list, in display order. We hold templates
    /// directly here rather than `RoutineExercise`s so the form can build the
    /// final relationship graph in one go on save.
    @State private var pickedTemplates: [ExerciseTemplate] = []
    @State private var showPicker = false

    private var isEditing: Bool { routine != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Routine name", text: $name)
                }

                Section("Exercises") {
                    if pickedTemplates.isEmpty {
                        Text("No exercises yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(pickedTemplates.enumerated()), id: \.offset) { _, template in
                            HStack {
                                Text(template.name)
                                Spacer()
                                Text(template.muscleGroup.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { offsets in
                            pickedTemplates.remove(atOffsets: offsets)
                        }
                        .onMove { source, dest in
                            pickedTemplates.move(fromOffsets: source, toOffset: dest)
                        }
                    }

                    Button {
                        showPicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Routine" : "New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !pickedTemplates.isEmpty { EditButton() }
                }
            }
            .sheet(isPresented: $showPicker) {
                RoutineExercisePickerSheet { templates in
                    pickedTemplates.append(contentsOf: templates)
                }
            }
            .onAppear(perform: loadIfEditing)
        }
    }

    private func loadIfEditing() {
        guard let routine, pickedTemplates.isEmpty, name.isEmpty else { return }
        name = routine.name
        notes = routine.notes
        pickedTemplates = routine.sortedExercises.compactMap(\.exerciseTemplate)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let routine {
            // Editing: replace exercises in place. SwiftData cascade-deletes the old
            // RoutineExercise records when we drop them from the array.
            routine.name = trimmed
            routine.notes = notes
            for old in routine.exercises {
                modelContext.delete(old)
            }
            routine.exercises.removeAll()
            for (index, template) in pickedTemplates.enumerated() {
                let entry = RoutineExercise(order: index)
                routine.exercises.append(entry)
                entry.exerciseTemplate = template
            }
        } else {
            // Creating: insert the routine first, then build the graph.
            let new = Routine(name: trimmed, notes: notes)
            modelContext.insert(new)
            for (index, template) in pickedTemplates.enumerated() {
                let entry = RoutineExercise(order: index)
                new.exercises.append(entry)
                entry.exerciseTemplate = template
            }
        }
        try? modelContext.save()
        dismiss()
    }
}

/// Lightweight exercise picker for routines. Returns the selected templates to the
/// caller via `onPicked` rather than mutating any model directly.
private struct RoutineExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExerciseTemplate.name) private var allExercises: [ExerciseTemplate]
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var selected: Set<PersistentIdentifier> = []

    let onPicked: ([ExerciseTemplate]) -> Void

    private var filtered: [ExerciseTemplate] {
        allExercises.filter { exercise in
            let matchesSearch = searchText.isEmpty ||
                exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil ||
                exercise.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    private var grouped: [(MuscleGroup, [ExerciseTemplate])] {
        let groups = Dictionary(grouping: filtered, by: \.muscleGroup)
        return MuscleGroup.allCases.compactMap { group in
            guard let exs = groups[group], !exs.isEmpty else { return nil }
            return (group, exs)
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

                ForEach(grouped, id: \.0) { group, exs in
                    Section(group.rawValue) {
                        ForEach(exs) { exercise in
                            Button {
                                let id = exercise.persistentModelID
                                if selected.contains(id) {
                                    selected.remove(id)
                                } else {
                                    selected.insert(id)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selected.contains(exercise.persistentModelID)
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(exercise.persistentModelID)
                                                         ? Color.accentColor : .secondary)
                                    Text(exercise.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if exercise.isCustom {
                                        Text("Custom")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add (\(selected.count))") {
                        let picked = allExercises.filter { selected.contains($0.persistentModelID) }
                        onPicked(picked)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selected.isEmpty)
                }
            }
        }
    }
}
