import Foundation
import SwiftData

/// A reusable workout template — a named list of exercises that can be turned into a
/// fresh `Workout` on demand.
///
/// Routines are pure templates: they hold references to `ExerciseTemplate`s but no
/// per-set data. Starting a workout from a routine creates a new `Workout` populated
/// with `WorkoutExercise` records pointing at the same templates.
@Model
final class Routine {
    /// User-visible name (e.g. "Push Day").
    var name: String

    /// Free-text notes (currently unused in UI but available for future expansion).
    var notes: String

    /// When the routine was created — used for stable sorting in the list.
    var dateCreated: Date

    /// Exercises that make up this routine. Cascade-deleted with the routine.
    @Relationship(deleteRule: .cascade)
    var exercises: [RoutineExercise] = []

    /// Inverse of `SplitRoutine.routine`. Nullify so deleting a routine just removes it
    /// from any splits that referenced it (rather than taking those splits down too).
    @Relationship(deleteRule: .nullify)
    var splitEntries: [SplitRoutine] = []

    /// Exercises in display order (by `RoutineExercise.order`).
    var sortedExercises: [RoutineExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    init(name: String, notes: String = "", dateCreated: Date = .now) {
        self.name = name
        self.notes = notes
        self.dateCreated = dateCreated
    }
}
