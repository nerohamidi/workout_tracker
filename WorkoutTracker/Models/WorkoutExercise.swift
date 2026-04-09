import Foundation
import SwiftData

@Model
final class WorkoutExercise {
    var order: Int
    var exerciseTemplate: ExerciseTemplate?
    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workoutExercise)
    var sets: [ExerciseSet] = []

    @Relationship(deleteRule: .cascade, inverse: \CardioEntry.workoutExercise)
    var cardioEntries: [CardioEntry] = []

    var sortedSets: [ExerciseSet] {
        sets.sorted { $0.setNumber < $1.setNumber }
    }

    var isCardio: Bool {
        exerciseTemplate?.category == .cardio
    }

    init(order: Int, exerciseTemplate: ExerciseTemplate? = nil, workout: Workout? = nil) {
        self.order = order
        self.exerciseTemplate = exerciseTemplate
        self.workout = workout
    }
}
