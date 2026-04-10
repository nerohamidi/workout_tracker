import SwiftUI
import SwiftData

struct ExercisesTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseTemplate.name) private var exercises: [ExerciseTemplate]
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var showAddForm = false
    @State private var exerciseToDelete: ExerciseTemplate?

    private var filteredExercises: [ExerciseTemplate] {
        exercises.filter { exercise in
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
            ScrollView {
                VStack(spacing: 6) {
                    // Category filter
                    HStack(spacing: 8) {
                        filterChip("All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(ExerciseCategory.allCases, id: \.self) { category in
                            filterChip(category.rawValue, isSelected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    ForEach(groupedExercises, id: \.0) { group, exercises in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.rawValue)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal)
                                .padding(.top, 12)

                            VStack(spacing: 1) {
                                ForEach(exercises) { exercise in
                                    NavigationLink(value: exercise) {
                                        HStack(spacing: 12) {
                                            Text(exercise.name)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            if exercise.isCustom {
                                                Text("Custom")
                                                    .font(.caption2.weight(.medium))
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(Color(.systemGray5))
                                                    .clipShape(Capsule())
                                            }
                                            Image(systemName: "chevron.right")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color(.secondarySystemGroupedBackground))
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        if exercise.isCustom {
                                            Button(role: .destructive) {
                                                exerciseToDelete = exercise
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom)
            }
            .background(Color(.systemGroupedBackground))
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationDestination(for: ExerciseTemplate.self) { template in
                ExerciseDetailView(template: template)
            }
            .navigationTitle("Exercises")
            .toolbar {
                Button { showAddForm = true } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .sheet(isPresented: $showAddForm) {
                AddExerciseForm()
            }
            .alert("Delete \(exerciseToDelete?.name ?? "exercise")?",
                   isPresented: Binding(
                    get: { exerciseToDelete != nil },
                    set: { if !$0 { exerciseToDelete = nil } }
                   )) {
                Button("Cancel", role: .cancel) { exerciseToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let exercise = exerciseToDelete {
                        modelContext.delete(exercise)
                        try? modelContext.save()
                    }
                    exerciseToDelete = nil
                }
            } message: {
                Text("Past workouts will keep their entries but lose the exercise name.")
            }
        }
    }

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
