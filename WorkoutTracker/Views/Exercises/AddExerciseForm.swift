import SwiftUI
import SwiftData

struct AddExerciseForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: ExerciseCategory = .strength
    @State private var muscleGroup: MuscleGroup = .chest

    var body: some View {
        NavigationStack {
            Form {
                TextField("Exercise Name", text: $name)

                Picker("Category", selection: $category) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .onChange(of: category) { _, newValue in
                    if newValue == .cardio {
                        muscleGroup = .cardio
                    } else if muscleGroup == .cardio {
                        muscleGroup = .chest
                    }
                }

                if category == .strength {
                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(MuscleGroup.allCases.filter { $0 != .cardio }, id: \.self) { group in
                            Text(group.rawValue).tag(group)
                        }
                    }
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let template = ExerciseTemplate(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            muscleGroup: category == .cardio ? .cardio : muscleGroup,
            isCustom: true
        )
        modelContext.insert(template)
        dismiss()
    }
}
