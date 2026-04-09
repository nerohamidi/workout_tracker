import Foundation
import SwiftData

/// A single workout session — a container for one or more `WorkoutExercise` entries.
///
/// A workout starts in the "in progress" state (`isCompleted == false`) and is moved to
/// "completed" when the user taps Finish in `ActiveWorkoutView`. Only completed workouts
/// appear in the `HistoryTab`.
///
/// Deletion cascades to all child `WorkoutExercise` entries (and through them, to sets
/// and cardio entries).
@Model
final class Workout {
    /// When the workout was started.
    var date: Date

    /// Free-text notes (currently unused in UI but available for future expansion).
    var notes: String

    /// Total elapsed time in seconds, captured when the workout is finished.
    var durationSeconds: Int

    /// `false` while the workout is being logged, `true` once the user finishes it.
    /// In-progress workouts are auto-resumed on next launch.
    var isCompleted: Bool

    /// Exercises performed during this workout. Cascade-deleted with the workout.
    @Relationship(deleteRule: .cascade)
    var exercises: [WorkoutExercise] = []

    /// Human-readable duration string. Examples: `"45m"`, `"1h 12m"`.
    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Exercises in the order they were added (by `WorkoutExercise.order`).
    /// SwiftData relationships are unordered, so we sort on access.
    var sortedExercises: [WorkoutExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    init(date: Date = .now, notes: String = "", durationSeconds: Int = 0, isCompleted: Bool = false) {
        self.date = date
        self.notes = notes
        self.durationSeconds = durationSeconds
        self.isCompleted = isCompleted
    }
}
