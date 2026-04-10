import SwiftUI
import SwiftData

/// Lets the user describe a routine in plain English, asks Gemini to design it with
/// exercises and set schemes, then saves the result as a real `Routine` with
/// `RoutineSet` defaults.
///
/// If Gemini suggests exercises not in the library, they are created as custom
/// `ExerciseTemplate` records automatically.
struct AIRoutineSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @Query(sort: \ExerciseTemplate.name) private var allExercises: [ExerciseTemplate]

    @State private var userPrompt: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPaywall = false

    @State private var generatedName: String = ""
    @State private var resolvedExercises: [ResolvedExercise] = []
    @State private var hasResult = false

    /// Pairs a template (existing or to-be-created) with the AI's suggested sets.
    struct ResolvedExercise: Identifiable {
        let id = UUID()
        var template: ExerciseTemplate?   // nil = will create new on save
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
            .navigationTitle("AI Routine")
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
                                      || resolvedExercises.isEmpty)
                    }
                }
            }
            .alert("Generation Failed", isPresented: errorBinding, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var promptSections: some View {
        Section {
            Text("Describe the routine you want and Gemini will design it with exercises and sets.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }

        Section("Prompt") {
            TextField(
                "e.g. 45-minute push day for hypertrophy",
                text: $userPrompt,
                axis: .vertical
            )
            .lineLimit(3...6)
        }

        if !subscriptionManager.canGenerateAIRoutine {
            Section {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text("AI routine limit reached.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Upgrade") { showPaywall = true }
                        .font(.subheadline.weight(.semibold))
                }
            }
        } else {
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

                Text(subscriptionManager.remainingAIRoutines)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var resultSections: some View {
        Section("Name") {
            TextField("Routine name", text: $generatedName)
        }

        Section("Exercises") {
            if resolvedExercises.isEmpty {
                Text("No exercises generated.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(resolvedExercises) { exercise in
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
                .onDelete { offsets in
                    resolvedExercises.remove(atOffsets: offsets)
                }
                .onMove { source, dest in
                    resolvedExercises.move(fromOffsets: source, toOffset: dest)
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
            let result = try await AIRoutineGenerator.generate(
                userPrompt: trimmed,
                availableExercises: allExercises
            )
            generatedName = result.name
            resolvedExercises = result.exercises.map { genEx in
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
            hasResult = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetForRetry() {
        hasResult = false
        generatedName = ""
        resolvedExercises = []
    }

    private func save() {
        let trimmed = generatedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let routine = Routine(name: trimmed)
        modelContext.insert(routine)

        for (index, resolved) in resolvedExercises.enumerated() {
            // Resolve or create the ExerciseTemplate
            let template: ExerciseTemplate
            if let existing = resolved.template {
                template = existing
            } else {
                let newTemplate = ExerciseTemplate(
                    name: resolved.name,
                    category: resolved.category,
                    muscleGroup: resolved.muscleGroup,
                    isCustom: true
                )
                modelContext.insert(newTemplate)
                template = newTemplate
            }

            let entry = RoutineExercise(order: index)
            routine.exercises.append(entry)
            entry.exerciseTemplate = template

            // Populate default sets
            for (setIdx, setData) in resolved.sets.enumerated() {
                let routineSet = RoutineSet(
                    setNumber: setIdx + 1,
                    reps: setData.reps,
                    weight: setData.weight
                )
                entry.defaultSets.append(routineSet)
            }
        }
        try? modelContext.save()
        subscriptionManager.recordAIRoutineGenerated()
        dismiss()
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
