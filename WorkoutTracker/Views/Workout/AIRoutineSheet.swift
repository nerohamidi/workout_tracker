import SwiftUI
import SwiftData

/// Lets the user describe a routine in plain English, asks Gemini to design it from
/// the existing exercise library, then saves the result as a real `Routine`.
///
/// Flow: prompt entry → loading → preview (editable list) → save. Names returned by
/// Gemini are matched against the library by case-insensitive equality; any name we
/// can't resolve is dropped silently and surfaced to the user as a count.
struct AIRoutineSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ExerciseTemplate.name) private var allExercises: [ExerciseTemplate]

    @State private var userPrompt: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Once Gemini responds and we resolve names → templates, we hold the editable
    /// preview here. The user can rename and reorder before saving.
    @State private var generatedName: String = ""
    @State private var resolvedTemplates: [ExerciseTemplate] = []
    @State private var unresolvedNames: [String] = []
    @State private var hasResult = false

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
                                      || resolvedTemplates.isEmpty)
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
            Text("Describe the routine you want and Gemini will pick exercises from your library.")
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
        Section("Name") {
            TextField("Routine name", text: $generatedName)
        }

        Section("Exercises") {
            if resolvedTemplates.isEmpty {
                Text("Gemini didn't pick any exercises that match your library.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(resolvedTemplates.enumerated()), id: \.offset) { _, template in
                    HStack {
                        Text(template.name)
                        Spacer()
                        Text(template.muscleGroup.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    resolvedTemplates.remove(atOffsets: offsets)
                }
                .onMove { source, dest in
                    resolvedTemplates.move(fromOffsets: source, toOffset: dest)
                }
            }
        }

        if !unresolvedNames.isEmpty {
            Section("Skipped") {
                Text("\(unresolvedNames.count) exercise\(unresolvedNames.count == 1 ? "" : "s") didn't match your library:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(unresolvedNames, id: \.self) { name in
                    Text(name)
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
            let result = try await AIRoutineGenerator.generate(
                userPrompt: trimmed,
                availableExercises: allExercises
            )
            // Resolve names → templates by case-insensitive match. Order is whatever
            // Gemini returned.
            var resolved: [ExerciseTemplate] = []
            var unresolved: [String] = []
            for name in result.exerciseNames {
                if let match = allExercises.first(where: {
                    $0.name.compare(name, options: .caseInsensitive) == .orderedSame
                }) {
                    resolved.append(match)
                } else {
                    unresolved.append(name)
                }
            }
            generatedName = result.name
            resolvedTemplates = resolved
            unresolvedNames = unresolved
            hasResult = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetForRetry() {
        hasResult = false
        generatedName = ""
        resolvedTemplates = []
        unresolvedNames = []
    }

    private func save() {
        let trimmed = generatedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let routine = Routine(name: trimmed)
        modelContext.insert(routine)
        for (index, template) in resolvedTemplates.enumerated() {
            let entry = RoutineExercise(order: index)
            routine.exercises.append(entry)
            entry.exerciseTemplate = template
        }
        try? modelContext.save()
        dismiss()
    }
}
