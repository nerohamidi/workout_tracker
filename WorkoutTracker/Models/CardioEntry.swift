import Foundation
import SwiftData

@Model
final class CardioEntry {
    var durationMinutes: Double
    var distance: Double
    var workoutExercise: WorkoutExercise?

    init(durationMinutes: Double = 0, distance: Double = 0, workoutExercise: WorkoutExercise? = nil) {
        self.durationMinutes = durationMinutes
        self.distance = distance
        self.workoutExercise = workoutExercise
    }
}
