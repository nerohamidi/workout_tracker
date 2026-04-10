import SwiftUI
import SwiftData

/// Lets the user describe a full training split in plain English and Gemini generates
/// everything: routines, exercises (creating new ones if needed), and set schemes.
/// No pre-existing routines are required.
struct AISplitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ExerciseTemplate.name) private var allExercises: [ExerciseTemplate]

    @State private var userPrompt: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var generatedName: String = ""
    @State private var resolvedRoutines: [ResolvedRoutine] = []
    @State private var hasResult = false

    /// A routine in the preview, with its resolved exercises.
    struct ResolvedRoutine: Identifiable {
        let id = UUID()
        var name: String
        var exercises: [ResolvedExercise]
    }

    struct ResolvedExercise: Identifiable {
        let id = UUID()
        var template: ExerciseTemplate?
        var name: String
        var category: ExerciseCategory
        var muscleGroup: MuscleGroup
        var sets: [(reps: Int, weight: Double)]
        var isNew: Bool
    }

    var body: some View {
        NavigationStack {
            Form {
                if hasResult {
                    resultSections
                } else {
                    promptSections
                }
            }
            .navigationTitle("AI Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if hasResult {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Save") { save() }
                            .fontWeight(.semibold)
                            .disabled(generatedName.trimmingCharacters(in: .whitespaces).isEmpty
                                      || resolvedRoutines.isEmpty)
                    }
                }
            }
            .alert("Generation Failed", isPresented: errorBinding, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var promptSections: some View {
        Section {
            Text("Describe the split you want and Gemini will generate all routines, exercises, and sets from scratch.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }

        Section("Prompt") {
            TextField(
                "e.g. 6-day PPL split for hypertrophy",
                text: $userPrompt,
                axis: .vertical
            )
            .lineLimit(3...6)
        }

        Section {
            Button {
                Task { await generate() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .padding(.trailing, 4)
                    }
                    Label("Generate", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
            }
            .disabled(isLoading || userPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @ViewBuilder
    private var resultSections: some View {
        Section("Split Name") {
            TextField("Split name", text: $generatedName)
        }

        ForEach(Array(resolvedRoutines.enumerated()), id: \.element.id) { routineIdx, routine in
            Section {
                ForEach(routine.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(exercise.name)
                            Spacer()
                            if exercise.isNew {
                                Text("New")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                            }
                            Text(exercise.muscleGroup.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(exercise.sets.map { "\($0.reps)×\(formatWeight($0.weight))kg" }
                            .joined(separator: "  ·  "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                HStack {
                    Text("\(routineIdx + 1). \(routine.name)")
                    Spacer()
                    Text("\(routine.exercises.count) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Section {
            Button {
                resetForRetry()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
        }
    }

    // MARK: - Actions

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func generate() async {
        let trimmed = userPrompt.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await AISplitGenerator.generate(
                userPrompt: trimmed,
                availableExercises: allExercises
            )
            generatedName = result.name
            resolvedRoutines = result.routines.map { genRoutine in
                let exercises = genRoutine.exercises.map { genEx -> ResolvedExercise in
                    let match = allExercises.first {
                        $0.name.compare(genEx.name, options: .caseInsensitive) == .orderedSame
                    }
                    let category = ExerciseCategory(rawValue: genEx.category) ?? .strength
                    let muscle = MuscleGroup(rawValue: genEx.muscleGroup) ?? .fullBody
                    return ResolvedExercise(
                        template: match,
                        name: match?.name ?? genEx.name,
                        category: match?.category ?? category,
                        muscleGroup: match?.muscleGroup ?? muscle,
                        sets: genEx.sets.map { ($0.reps, $0.weight) },
                        isNew: match == nil
                    )
                }
                return ResolvedRoutine(name: genRoutine.name, exercises: exercises)
            }
            hasResult = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetForRetry() {
        hasResult = false
        generatedName = ""
        resolvedRoutines = []
    }

    private func save() {
        let trimmed = generatedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Track newly created templates so the same new exercise across routines
        // reuses the same template rather than creating duplicates.
        var createdTemplates: [String: ExerciseTemplate] = [:]

        let split = TrainingSplit(name: trimmed)
        modelContext.insert(split)

        for (routineIdx, resolvedRoutine) in resolvedRoutines.enumerated() {
            let routine = Routine(name: resolvedRoutine.name)
            modelContext.insert(routine)

            for (exIdx, resolved) in resolvedRoutine.exercises.enumerated() {
                let template: ExerciseTemplate
                if let existing = resolved.template {
                    template = existing
                } else if let alreadyCreated = createdTemplates[resolved.name.lowercased()] {
                    template = alreadyCreated
                } else {
                    let newTemplate = ExerciseTemplate(
                        name: resolved.name,
                        category: resolved.category,
                        muscleGroup: resolved.muscleGroup,
                        isCustom: true
                    )
                    modelContext.insert(newTemplate)
                    createdTemplates[resolved.name.lowercased()] = newTemplate
                    template = newTemplate
                }

                let entry = RoutineExercise(order: exIdx)
                routine.exercises.append(entry)
                entry.exerciseTemplate = template

                for (setIdx, setData) in resolved.sets.enumerated() {
                    let routineSet = RoutineSet(
                        setNumber: setIdx + 1,
                        reps: setData.reps,
                        weight: setData.weight
                    )
                    entry.defaultSets.append(routineSet)
                }
            }

            let splitEntry = SplitRoutine(order: routineIdx)
            split.routines.append(splitEntry)
            splitEntry.routine = routine
        }

        try? modelContext.save()
        dismiss()
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
