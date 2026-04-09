import SwiftUI
import SwiftData

struct WorkoutTab: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeWorkout: Workout?
    @State private var showActiveWorkout = false

    @Query(sort: \Workout.date, order: .reverse)
    private var allWorkouts: [Workout]

    private var inProgressWorkout: Workout? {
        allWorkouts.first { !$0.isCompleted }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("Ready to work out?")
                    .font(.title2)
                    .fontWeight(.semibold)

                Button {
                    startWorkout()
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Workout")
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
