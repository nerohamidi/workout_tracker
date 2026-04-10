import Foundation

/// A personal record for a strength exercise — the heaviest weight ever lifted at a
/// specific rep count, plus when it happened.
///
/// Records are derived from completed workout history, never stored. The list of
/// records for an exercise is computed on demand by `PersonalRecord.records(for:)`.
struct PersonalRecord: Identifiable, Equatable {
    /// The rep count this record is for (e.g. 1 for a 1RM, 5 for a 5RM).
    let reps: Int

    /// Heaviest weight ever lifted at this rep count, in the user's stored unit.
    let weight: Double

    /// Date of the workout where this record was set. If multiple workouts tied at the
    /// same weight, this is the earliest one (first to hit it wins the date).
    let date: Date

    var id: Int { reps }

    /// Compute max-weight-per-rep-count from a strength template's completed workout
    /// history. Returns rows sorted by rep count ascending. Cardio templates always
    /// return an empty array — they don't have rep-based PRs.
    ///
    /// Only sets with both `weight > 0` and `reps > 0` are considered, so unlogged
    /// blank rows in past workouts are ignored. Only completed workouts count;
    /// in-progress sessions don't yet contribute to PRs.
    /// One data point in a rep-count's weight progression over time. Used to plot
    /// strength gains in `ExerciseDetailView`.
    struct ProgressionPoint: Identifiable, Equatable {
        let date: Date
        let weight: Double
        var id: Date { date }
    }

    /// For each rep count the user has ever logged, return their heaviest set per
    /// completed workout, sorted by date ascending. Suitable for plotting one line
    /// chart per rep count.
    ///
    /// If the user did multiple sets at the same rep count in the same workout, only
    /// the heaviest set contributes to that day's data point — that's what "progress"
    /// means in a workout-tracker context.
    ///
    /// Returns an empty dictionary for cardio templates.
    static func progressionByReps(for template: ExerciseTemplate) -> [Int: [ProgressionPoint]] {
        guard template.category == .strength else { return [:] }

        // reps -> (workout date -> heaviest weight that day)
        var maxByDay: [Int: [Date: Double]] = [:]
        for workoutExercise in template.workoutExercises {
            guard let workout = workoutExercise.workout, workout.isCompleted else { continue }
            for set in workoutExercise.sets where set.weight > 0 && set.reps > 0 {
                let existing = maxByDay[set.reps]?[workout.date] ?? 0
                if set.weight > existing {
                    maxByDay[set.reps, default: [:]][workout.date] = set.weight
                }
            }
        }

        return maxByDay.mapValues { dayDict in
            dayDict
                .map { ProgressionPoint(date: $0.key, weight: $0.value) }
                .sorted { $0.date < $1.date }
        }
    }

    static func records(for template: ExerciseTemplate) -> [PersonalRecord] {
        guard template.category == .strength else { return [] }

        var bestByReps: [Int: PersonalRecord] = [:]
        for workoutExercise in template.workoutExercises {
            guard let workout = workoutExercise.workout, workout.isCompleted else { continue }
            for set in workoutExercise.sets where set.weight > 0 && set.reps > 0 {
                let candidate = PersonalRecord(reps: set.reps, weight: set.weight, date: workout.date)
                if let existing = bestByReps[set.reps] {
                    if set.weight > existing.weight {
                        bestByReps[set.reps] = candidate
                    } else if set.weight == existing.weight && workout.date < existing.date {
                        // Tie on weight — keep the earlier date so "when did I first hit this?" stays stable.
                        bestByReps[set.reps] = candidate
                    }
                } else {
                    bestByReps[set.reps] = candidate
                }
            }
        }
        return bestByReps.values.sorted { $0.reps < $1.reps }
    }
}
