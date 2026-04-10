import SwiftUI
import SwiftData

/// Primary tab. Lists the user's saved routines and provides entry points to start
/// a new workout (either empty or from a routine) and to manage routines.
///
/// On appear, automatically resumes any in-progress workout — there should only ever
/// be one at a time, so finishing or discarding it is the only way to start a new one.
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
            List {
                Section("Splits") {
                    if splits.isEmpty {
                        Text("Group routines into a rotation (e.g. PPL).")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(splits) { split in
                            NavigationLink(value: split) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(split.name)
                                    if let next = split.nextRoutine {
                                        Text("Next: \(next.name)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("\(split.routines.count) routine\(split.routines.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    Button {
                        showSplitForm = true
                    } label: {
                        Label("New Split", systemImage: "plus.circle.fill")
                    }
                    .disabled(routines.isEmpty)
                    Button {
                        showAISplitSheet = true
                    } label: {
                        Label("Generate with AI", systemImage: "sparkles")
                    }
                    .disabled(routines.isEmpty)
                }

                Section("Routines") {
                    if routines.isEmpty {
                        Text("No routines yet. Create one to start workouts faster.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(routines) { routine in
                            NavigationLink(value: routine) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(routine.name)
                                    Text("\(routine.exercises.count) exercise\(routine.exercises.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Button {
                        showRoutineForm = true
                    } label: {
                        Label("New Routine", systemImage: "plus.circle.fill")
                    }
                    Button {
                        showAIRoutineSheet = true
                    } label: {
                        Label("Generate with AI", systemImage: "sparkles")
                    }
                }

                Section {
                    Button {
                        startWorkout()
                    } label: {
                        Label("Start Empty Workout", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("Workout")
            .navigationDestination(for: Routine.self) { routine in
                RoutineDetailView(routine: routine)
            }
            .navigationDestination(for: TrainingSplit.self) { split in
                SplitDetailView(split: split)
            }
            .sheet(isPresented: $showRoutineForm) {
                RoutineFormView()
            }
            .sheet(isPresented: $showSplitForm) {
                SplitFormView()
            }
            .sheet(isPresented: $showAIRoutineSheet) {
                AIRoutineSheet()
            }
            .sheet(isPresented: $showAISplitSheet) {
                AISplitSheet()
            }
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

    private func startWorkout() {
        let workout = Workout()
        modelContext.insert(workout)
        activeWorkout = workout
        showActiveWorkout = true
    }
}
