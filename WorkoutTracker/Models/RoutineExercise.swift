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

    init(order: Int, exerciseTemplate: ExerciseTemplate? = nil, routine: Routine? = nil) {
        self.order = order
        self.exerciseTemplate = exerciseTemplate
        self.routine = routine
    }
}
