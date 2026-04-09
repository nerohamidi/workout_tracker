import Foundation
import SwiftData

/// A single strength set: weight × reps. Belongs to a `WorkoutExercise`.
///
/// `setNumber` is 1-indexed and assigned by `ExerciseSection.addSet` based on the
/// current max set number for the exercise.
@Model
final class ExerciseSet {
    /// 1-indexed position within the parent exercise. Used by `WorkoutExercise.sortedSets`.
    var setNumber: Int

    /// Number of repetitions performed. Defaults to 0 (unlogged).
    var reps: Int

    /// Weight lifted, in the user's selected unit (kg or lbs). Defaults to 0 (unlogged).
    /// Unit conversion is purely a display concern — values are stored as-entered.
    var weight: Double

    /// Back-reference to the parent exercise.
    var workoutExercise: WorkoutExercise?

    init(setNumber: Int, reps: Int = 0, weight: Double = 0, workoutExercise: WorkoutExercise? = nil) {
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.workoutExercise = workoutExercise
    }
}
