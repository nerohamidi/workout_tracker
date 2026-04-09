import Foundation
import SwiftData

/// An instance of an `ExerciseTemplate` performed during a specific `Workout`.
///
/// This is the bridge between a reusable exercise definition and the sets / cardio entries
/// logged for it within a single workout. Strength exercises use `sets`, cardio exercises
/// use `cardioEntries` — never both.
///
/// `order` is set by `AddExerciseSheet` when the exercise is added, so the workout view
/// can render exercises in the sequence the user added them.
@Model
final class WorkoutExercise {
    /// Position within the workout (0-indexed). Used by `Workout.sortedExercises`.
    var order: Int

    /// The reusable exercise definition. Optional because SwiftData requires
    /// inverse relationships to be optional, but in practice this is always set.
    var exerciseTemplate: ExerciseTemplate?

    /// The parent workout. Optional for the same reason as `exerciseTemplate`.
    var workout: Workout?

    /// Strength sets logged for this exercise (empty for cardio).
    @Relationship(deleteRule: .cascade)
    var sets: [ExerciseSet] = []

    /// Cardio entries logged for this exercise (empty for strength).
    /// Modeled as an array for future-proofing, but currently only one entry is used per exercise.
    @Relationship(deleteRule: .cascade)
    var cardioEntries: [CardioEntry] = []

    /// Sets in display order (by `setNumber`).
    var sortedSets: [ExerciseSet] {
        sets.sorted { $0.setNumber < $1.setNumber }
    }

    /// `true` if the underlying template is a cardio exercise. Drives which logging UI is shown.
    var isCardio: Bool {
        exerciseTemplate?.category == .cardio
    }

    init(order: Int, exerciseTemplate: ExerciseTemplate? = nil, workout: Workout? = nil) {
        self.order = order
        self.exerciseTemplate = exerciseTemplate
        self.workout = workout
    }
}
