import Foundation
import SwiftData

/// A default set stored on a `RoutineExercise` — pre-filled reps and weight that get
/// copied into real `ExerciseSet` records when a workout is started from the routine.
///
/// This lets AI-generated routines (or user-configured templates) carry suggested
/// programming so the user doesn't start every workout with blank rows.
@Model
final class RoutineSet {
    /// 1-indexed position within the parent exercise. Mirrors `ExerciseSet.setNumber`.
    var setNumber: Int

    /// Default rep count for this set.
    var reps: Int

    /// Default weight for this set, in the user's stored unit.
    var weight: Double

    /// The parent routine exercise.
    var routineExercise: RoutineExercise?

    init(setNumber: Int, reps: Int = 0, weight: Double = 0, routineExercise: RoutineExercise? = nil) {
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.routineExercise = routineExercise
    }
}
