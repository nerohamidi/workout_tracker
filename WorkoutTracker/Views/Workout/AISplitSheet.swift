import SwiftUI
import SwiftData

/// Lets the user describe a training split in plain English and asks Gemini to compose
/// a rotation from existing routines. Mirrors `AIRoutineSheet`'s prompt → loading →
/// preview → save flow.
struct AISplitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Routine.dateCreated, order: .reverse) private var allRoutines: [Routine]

    @State private var userPrompt: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var generatedName: String = ""
    @State private var resolvedRoutines: [Routine] = []
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
            if allRoutines.isEmpty {
                Text("Create some routines first — Gemini composes a split out of them.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Describe the split you want and Gemini will arrange your routines into a rotation.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Prompt") {
            TextField(
                "e.g. 4-day upper/lower for strength",
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
            .disabled(isLoading
                      || allRoutines.isEmpty
                      || userPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @ViewBuilder
    private var resultSections: some View {
        Section("Name") {
            TextField("Split name", text: $generatedName)
        }

        Section("Rotation") {
            if resolvedRoutines.isEmpty {
                Text("Gemini didn't pick any routines that match yours.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(resolvedRoutines.enumerated()), id: \.offset) { index, routine in
                    HStack {
                        Text("\(index + 1).")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(routine.name)
                        Spacer()
                        Text("\(routine.exercises.count) ex")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    resolvedRoutines.remove(atOffsets: offsets)
                }
                .onMove { source, dest in
                    resolvedRoutines.move(fromOffsets: source, toOffset: dest)
                }
            }
        }

        if !unresolvedNames.isEmpty {
            Section("Skipped") {
                Text("\(unresolvedNames.count) routine\(unresolvedNames.count == 1 ? "" : "s") didn't match yours:")
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
            let result = try await AISplitGenerator.generate(
                userPrompt: trimmed,
                availableRoutines: allRoutines
            )
            // Resolve names → routines. Allow duplicates (Gemini may put the same
            // routine in multiple slots — that's the whole point of e.g. PPL twice).
            var resolved: [Routine] = []
            var unresolved: [String] = []
            for name in result.routineNames {
                if let match = allRoutines.first(where: {
                    $0.name.compare(name, options: .caseInsensitive) == .orderedSame
                }) {
                    resolved.append(match)
                } else {
                    unresolved.append(name)
                }
            }
            generatedName = result.name
            resolvedRoutines = resolved
            unresolvedNames = unresolved
            hasResult = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetForRetry() {
        hasResult = false
        generatedName = ""
        resolvedRoutines = []
        unresolvedNames = []
    }

    private func save() {
        let trimmed = generatedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let split = TrainingSplit(name: trimmed)
        modelContext.insert(split)
        for (index, routine) in resolvedRoutines.enumerated() {
            let entry = SplitRoutine(order: index)
            split.routines.append(entry)
            entry.routine = routine
        }
        try? modelContext.save()
        dismiss()
    }
}
