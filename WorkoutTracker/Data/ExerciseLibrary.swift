import Foundation
import SwiftData

struct ExerciseLibrary {
    struct ExerciseDefinition {
        let name: String
        let category: ExerciseCategory
        let muscleGroup: MuscleGroup
    }

    static let exercises: [ExerciseDefinition] = [
        // Chest
        ExerciseDefinition(name: "Bench Press", category: .strength, muscleGroup: .chest),
        ExerciseDefinition(name: "Incline Bench Press", category: .strength, muscleGroup: .chest),
        ExerciseDefinition(name: "Push-ups", category: .strength, muscleGroup: .chest),
        ExerciseDefinition(name: "Dumbbell Fly", category: .strength, muscleGroup: .chest),

        // Back
        ExerciseDefinition(name: "Pull-ups", category: .strength, muscleGroup: .back),
        ExerciseDefinition(name: "Barbell Row", category: .strength, muscleGroup: .back),
        ExerciseDefinition(name: "Lat Pulldown", category: .strength, muscleGroup: .back),
        ExerciseDefinition(name: "Deadlift", category: .strength, muscleGroup: .back),
        ExerciseDefinition(name: "Seated Cable Row", category: .strength, muscleGroup: .back),

        // Legs
        ExerciseDefinition(name: "Squat", category: .strength, muscleGroup: .legs),
        ExerciseDefinition(name: "Leg Press", category: .strength, muscleGroup: .legs),
        ExerciseDefinition(name: "Lunges", category: .strength, muscleGroup: .legs),
        ExerciseDefinition(name: "Leg Curl", category: .strength, muscleGroup: .legs),
        ExerciseDefinition(name: "Leg Extension", category: .strength, muscleGroup: .legs),
        ExerciseDefinition(name: "Calf Raise", category: .strength, muscleGroup: .legs),

        // Shoulders
        ExerciseDefinition(name: "Overhead Press", category: .strength, muscleGroup: .shoulders),
        ExerciseDefinition(name: "Lateral Raise", category: .strength, muscleGroup: .shoulders),
        ExerciseDefinition(name: "Face Pull", category: .strength, muscleGroup: .shoulders),
        ExerciseDefinition(name: "Front Raise", category: .strength, muscleGroup: .shoulders),

        // Arms
        ExerciseDefinition(name: "Bicep Curl", category: .strength, muscleGroup: .arms),
        ExerciseDefinition(name: "Tricep Pushdown", category: .strength, muscleGroup: .arms),
        ExerciseDefinition(name: "Hammer Curl", category: .strength, muscleGroup: .arms),
        ExerciseDefinition(name: "Tricep Dips", category: .strength, muscleGroup: .arms),

        // Core
        ExerciseDefinition(name: "Plank", category: .strength, muscleGroup: .core),
        ExerciseDefinition(name: "Crunches", category: .strength, muscleGroup: .core),
        ExerciseDefinition(name: "Russian Twist", category: .strength, muscleGroup: .core),
        ExerciseDefinition(name: "Hanging Leg Raise", category: .strength, muscleGroup: .core),

        // Cardio
        ExerciseDefinition(name: "Running", category: .cardio, muscleGroup: .cardio),
        ExerciseDefinition(name: "Cycling", category: .cardio, muscleGroup: .cardio),
        ExerciseDefinition(name: "Swimming", category: .cardio, muscleGroup: .cardio),
        ExerciseDefinition(name: "Rowing", category: .cardio, muscleGroup: .cardio),
        ExerciseDefinition(name: "Walking", category: .cardio, muscleGroup: .cardio),
        ExerciseDefinition(name: "Jump Rope", category: .cardio, muscleGroup: .cardio),
        ExerciseDefinition(name: "Elliptical", category: .cardio, muscleGroup: .cardio),
    ]

    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<ExerciseTemplate>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        for exercise in exercises {
            let template = ExerciseTemplate(
                name: exercise.name,
                category: exercise.category,
                muscleGroup: exercise.muscleGroup,
                isCustom: false
            )
            modelContext.insert(template)
        }
        try? modelContext.save()
    }
}
