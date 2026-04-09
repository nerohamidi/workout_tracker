import SwiftUI
import SwiftData

/// Create or edit a training split. Reused for both new splits (pass `nil`) and
/// editing an existing one. Lets the user pick routines from the library, reorder
/// them, and remove them — same shape as `RoutineFormView`.
struct SplitFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Existing split to edit, or `nil` to create a new one.
    var split: TrainingSplit?

    @State private var name: String = ""
    /// Working copy of the routine list, in display order. We hold `Routine` references
    /// directly so the form can build the final relationship graph in one go on save.
    @State private var pickedRoutines: [Routine] = []
    @State private var showPicker = false

    private var isEditing: Bool { split != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Split name", text: $name)
                }

                Section("Routines") {
                    if pickedRoutines.isEmpty {
                        Text("No routines yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(pickedRoutines.enumerated()), id: \.offset) { _, routine in
                            HStack {
                                Text(routine.name)
                                Spacer()
                                Text("\(routine.exercises.count) exercise\(routine.exercises.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { offsets in
                            pickedRoutines.remove(atOffsets: offsets)
                        }
                        .onMove { source, dest in
                            pickedRoutines.move(fromOffsets: source, toOffset: dest)
                        }
                    }

                    Button {
                        showPicker = true
                    } label: {
                        Label("Add Routine", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Split" : "New Split")
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
                    if !pickedRoutines.isEmpty { EditButton() }
                }
            }
            .sheet(isPresented: $showPicker) {
                SplitRoutinePickerSheet(alreadyPicked: pickedRoutines) { routines in
                    pickedRoutines.append(contentsOf: routines)
                }
            }
            .onAppear(perform: loadIfEditing)
        }
    }

    private func loadIfEditing() {
        guard let split, pickedRoutines.isEmpty, name.isEmpty else { return }
        name = split.name
        pickedRoutines = split.sortedRoutines.compactMap(\.routine)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let split {
            // Editing: replace entries in place. SwiftData cascade-deletes the old
            // SplitRoutine records when we drop them from the array.
            split.name = trimmed
            for old in split.routines {
                modelContext.delete(old)
            }
            split.routines.removeAll()
            for (index, routine) in pickedRoutines.enumerated() {
                let entry = SplitRoutine(order: index)
                split.routines.append(entry)
                entry.routine = routine
            }
            // Clamp currentIndex into the new range so editing doesn't break the rotation.
            if pickedRoutines.isEmpty {
                split.currentIndex = 0
            } else if split.currentIndex >= pickedRoutines.count {
                split.currentIndex = 0
            }
        } else {
            let new = TrainingSplit(name: trimmed)
            modelContext.insert(new)
            for (index, routine) in pickedRoutines.enumerated() {
                let entry = SplitRoutine(order: index)
                new.routines.append(entry)
                entry.routine = routine
            }
        }
        try? modelContext.save()
        dismiss()
    }
}

/// Lightweight routine picker for splits. Returns the selected routines to the caller
/// via `onPicked` rather than mutating any model directly. Allows duplicate picks
/// across separate add operations (e.g. PPL twice a week becomes Push, Pull, Legs,
/// Push, Pull, Legs), but hides routines already in the working copy from the current
/// picker session for clarity.
private struct SplitRoutinePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.dateCreated, order: .reverse) private var allRoutines: [Routine]
    @State private var selected: Set<PersistentIdentifier> = []

    let alreadyPicked: [Routine]
    let onPicked: ([Routine]) -> Void

    var body: some View {
        NavigationStack {
            List {
                if allRoutines.isEmpty {
                    Text("No routines yet. Create a routine first.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allRoutines) { routine in
                        Button {
                            let id = routine.persistentModelID
                            if selected.contains(id) {
                                selected.remove(id)
                            } else {
                                selected.insert(id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selected.contains(routine.persistentModelID)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(routine.persistentModelID)
                                                     ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(routine.name)
                                        .foregroundStyle(.primary)
                                    Text("\(routine.exercises.count) exercise\(routine.exercises.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Routines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add (\(selected.count))") {
                        let picked = allRoutines.filter { selected.contains($0.persistentModelID) }
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
