import Foundation
import SwiftData

/// A single exercise slot within a `Routine`.
///
/// Mirrors the `WorkoutExercise` ↔ `Workout` relationship but for the template side:
/// it points at an `ExerciseTemplate` and remembers its position in the routine.
/// No sets or cardio entries are stored here — those only exist on actual workouts.
@Model
final class RoutineExercise {
    /// Position within the routine (0-indexed). Used by `Routine.sortedExercises`.
    var order: Int

    /// The exercise definition this slot points at. Optional because the template
    /// could be deleted later (the relationship is `.nullify`); a routine entry
    /// without a template is effectively orphaned and shown as "Exercise" in the UI.
    var exerciseTemplate: ExerciseTemplate?

    /// The parent routine. Optional for the same reason as `exerciseTemplate`.
    var routine: Routine?

    /// Default sets for this exercise slot. Cascade-deleted with the routine exercise.
    /// When a workout is started from the routine, these are copied into `ExerciseSet`
    /// records on the new `WorkoutExercise`.
    @Relationship(deleteRule: .cascade)
    var defaultSets: [RoutineSet] = []

    /// Default sets in display order (by `setNumber`).
    var sortedDefaultSets: [RoutineSet] {
        defaultSets.sorted { $0.setNumber < $1.setNumber }
    }

    init(order: Int, exerciseTemplate: ExerciseTemplate? = nil, routine: Routine? = nil) {
        self.order = order
        self.exerciseTemplate = exerciseTemplate
        self.routine = routine
    }
}
