import Foundation
import SwiftData

enum ExerciseCategory: String, Codable, CaseIterable {
    case strength = "Strength"
    case cardio = "Cardio"
}

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

@Model
final class ExerciseTemplate {
    var name: String
    var category: ExerciseCategory
    var muscleGroup: MuscleGroup
    var isCustom: Bool

    @Relationship(deleteRule: .deny, inverse: \WorkoutExercise.exerciseTemplate)
    var workoutExercises: [WorkoutExercise] = []

    init(name: String, category: ExerciseCategory, muscleGroup: MuscleGroup, isCustom: Bool = false) {
        self.name = name
        self.category = category
        self.muscleGroup = muscleGroup
        self.isCustom = isCustom
    }
}
