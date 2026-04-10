import SwiftUI
import SwiftData

struct AddExerciseForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @Query(filter: #Predicate<ExerciseTemplate> { $0.isCustom })
    private var customExercises: [ExerciseTemplate]

    @State private var name = ""
    @State private var category: ExerciseCategory = .strength
    @State private var muscleGroup: MuscleGroup = .chest
    @State private var showPaywall = false

    private var canAdd: Bool {
        subscriptionManager.canCreateCustomExercise(currentCount: customExercises.count)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !canAdd {
                    Section {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                            Text("Custom exercise limit reached.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Upgrade") { showPaywall = true }
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }

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
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || !canAdd)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
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
