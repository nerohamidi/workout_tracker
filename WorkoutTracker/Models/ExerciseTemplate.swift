import Foundation
import SwiftData

/// The kind of exercise — determines whether it is logged with sets/reps/weight or duration/distance.
enum ExerciseCategory: String, Codable, CaseIterable {
    case strength = "Strength"
    case cardio = "Cardio"
}

/// The primary muscle group an exercise targets, used for grouping in the UI.
/// `cardio` is a sentinel value used for cardio exercises since they are not muscle-specific.
enum MuscleGroup: String, Codable, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case legs = "Legs"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case core = "Core"
    case fullBody = "Full Body"
    case cardio = "Cardio"
}

/// Represents a single exercise definition (e.g. "Bench Press").
///
/// Templates are reusable across many workouts. They come from two sources:
/// - The pre-built library seeded by `ExerciseLibrary` on first launch (`isCustom == false`)
/// - User-created exercises added via `AddExerciseForm` (`isCustom == true`)
///
/// A template is referenced by `WorkoutExercise` instances when added to a workout.
@Model
final class ExerciseTemplate {
    /// Display name of the exercise (e.g. "Bench Press").
    var name: String

    /// Whether this is a strength or cardio exercise. Determines logging UI.
    var category: ExerciseCategory

    /// Primary muscle group, used to group exercises in the picker.
    var muscleGroup: MuscleGroup

    /// `true` if the user created this exercise, `false` if it came from the seeded library.
    var isCustom: Bool

    /// All workout exercises that reference this template. Set to `.nullify` so deleting
    /// a template does not cascade-delete historical workout entries.
    @Relationship(deleteRule: .nullify)
    var workoutExercises: [WorkoutExercise] = []

    /// All routine exercises that reference this template. Same `.nullify` rule —
    /// removing a custom exercise leaves any routines that used it intact, just
    /// with an unnamed slot.
    @Relationship(deleteRule: .nullify)
    var routineExercises: [RoutineExercise] = []

    init(name: String, category: ExerciseCategory, muscleGroup: MuscleGroup, isCustom: Bool = false) {
        self.name = name
        self.category = category
        self.muscleGroup = muscleGroup
        self.isCustom = isCustom
    }
}
