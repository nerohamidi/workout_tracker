import Foundation
import SwiftData

/// A single cardio log entry: duration and distance for a cardio exercise.
///
/// One entry per `WorkoutExercise` is the current convention (no concept of "sets" for cardio).
/// Both fields default to 0 so the row can be displayed before the user enters any values.
@Model
final class CardioEntry {
    /// Duration of the cardio activity in minutes.
    var durationMinutes: Double

    /// Distance covered in the user's selected unit (km or mi).
    /// Unit conversion is purely a display concern.
    var distance: Double

    /// Back-reference to the parent exercise.
    var workoutExercise: WorkoutExercise?

    init(durationMinutes: Double = 0, distance: Double = 0, workoutExercise: WorkoutExercise? = nil) {
        self.durationMinutes = durationMinutes
        self.distance = distance
        self.workoutExercise = workoutExercise
    }
}
