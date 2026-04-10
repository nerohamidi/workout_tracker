import SwiftUI
import SwiftData

struct WorkoutTab: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeWorkout: Workout?
    @State private var showActiveWorkout = false
    @State private var showRoutineForm = false
    @State private var showSplitForm = false
    @State private var showAIRoutineSheet = false
    @State private var showAISplitSheet = false

    @Query(sort: \Workout.date, order: .reverse)
    private var allWorkouts: [Workout]

    @Query(sort: \Routine.dateCreated, order: .reverse)
    private var routines: [Routine]

    @Query(sort: \TrainingSplit.dateCreated, order: .reverse)
    private var splits: [TrainingSplit]

    private var inProgressWorkout: Workout? {
        allWorkouts.first { !$0.isCompleted }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    startButton
                    splitsSection
                    routinesSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Workout")
            .navigationDestination(for: Routine.self) { routine in
                RoutineDetailView(routine: routine)
            }
            .navigationDestination(for: TrainingSplit.self) { split in
                SplitDetailView(split: split)
            }
            .sheet(isPresented: $showRoutineForm) { RoutineFormView() }
            .sheet(isPresented: $showSplitForm) { SplitFormView() }
            .sheet(isPresented: $showAIRoutineSheet) { AIRoutineSheet() }
            .sheet(isPresented: $showAISplitSheet) { AISplitSheet() }
            .fullScreenCover(isPresented: $showActiveWorkout) {
                if let workout = activeWorkout {
                    ActiveWorkoutView(workout: workout)
                }
            }
            .onAppear {
                if let existing = inProgressWorkout {
                    activeWorkout = existing
                    showActiveWorkout = true
                }
            }
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            startWorkout()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                Text("Start Workout")
                    .font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal)
    }

    // MARK: - Splits Section

    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Splits")
                    .font(.headline.weight(.bold))
                Spacer()
                Button { showAISplitSheet = true } label: {
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button { showSplitForm = true } label: {
                    Image(systemName: "plus")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .disabled(routines.isEmpty)
            }
            .padding(.horizontal)

            if splits.isEmpty {
                emptyCard("Group routines into a rotation")
            } else {
                VStack(spacing: 1) {
                    ForEach(splits) { split in
                        NavigationLink(value: split) {
                            SplitRowContent(split: split)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Routines Section

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Routines")
                    .font(.headline.weight(.bold))
                Spacer()
                Button { showAIRoutineSheet = true } label: {
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button { showRoutineForm = true } label: {
                    Image(systemName: "plus")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            if routines.isEmpty {
                emptyCard("Create a routine to start workouts faster")
            } else {
                VStack(spacing: 1) {
                    ForEach(routines) { routine in
                        NavigationLink(value: routine) {
                            RoutineRowContent(routine: routine)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helpers

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal)
    }

    private func startWorkout() {
        let workout = Workout()
        modelContext.insert(workout)
        activeWorkout = workout
        showActiveWorkout = true
    }
}

// MARK: - Row Views (extracted to help the type checker)

private struct SplitRowContent: View {
    let split: TrainingSplit

    var body: some View {
        HStack(spacing: 14) {
            iconSquare(systemName: "arrow.triangle.2.circlepath", color: .accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(split.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                subtitle
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var subtitle: some View {
        if let next = split.nextRoutine {
            Text("Next: \(next.name)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            let count = split.routines.count
            Text("\(count) routine\(count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RoutineRowContent: View {
    let routine: Routine

    var body: some View {
        HStack(spacing: 14) {
            iconSquare(systemName: "list.bullet", color: .purple)
            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                let count = routine.exercises.count
                Text("\(count) exercise\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private func iconSquare(systemName: String, color: Color) -> some View {
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(color.opacity(0.12))
        .frame(width: 40, height: 40)
        .overlay {
            Image(systemName: systemName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
        }
}
