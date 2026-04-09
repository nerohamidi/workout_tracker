import Foundation
import SwiftData

@Model
final class ExerciseSet {
    var setNumber: Int
    var reps: Int
    var weight: Double
    var workoutExercise: WorkoutExercise?

    init(setNumber: Int, reps: Int = 0, weight: Double = 0, workoutExercise: WorkoutExercise? = nil) {
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.workoutExercise = workoutExercise
    }
}
