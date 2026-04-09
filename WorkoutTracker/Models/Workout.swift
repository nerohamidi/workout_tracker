import Foundation
import SwiftData

@Model
final class Workout {
    var date: Date
    var notes: String
    var durationSeconds: Int
    var isCompleted: Bool

    @Relationship(deleteRule: .cascade)
    var exercises: [WorkoutExercise] = []

    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

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
