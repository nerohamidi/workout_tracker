import SwiftUI
import SwiftData

struct ExercisesTab: View {
    @Query(sort: \ExerciseTemplate.name) private var exercises: [ExerciseTemplate]
    @State private var searchText = ""
    @State private var selectedCategory: ExerciseCategory?
    @State private var showAddForm = false

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

                ForEach(groupedExercises, id: \.0) { group, exercises in
                    Section(group.rawValue) {
                        ForEach(exercises) { exercise in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(exercise.name)
                                    Text(exercise.category.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if exercise.isCustom {
                                    Text("Custom")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.fill)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Exercises")
            .toolbar {
                Button {
                    showAddForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddForm) {
                AddExerciseForm()
            }
        }
    }
}
