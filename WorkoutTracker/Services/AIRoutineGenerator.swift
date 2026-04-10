import Foundation

/// Asks Gemini to design a workout routine with exercises and per-exercise set schemes.
///
/// Gemini prefers exercises from the user's existing library but may also invent new
/// ones — the response includes category and muscle group for each exercise so the
/// caller can create `ExerciseTemplate` records on the fly when needed.
enum AIRoutineGenerator {
    /// Decoded shape of Gemini's response.
    struct GeneratedRoutine: Decodable {
        let name: String
        let exercises: [GeneratedExercise]
    }

    struct GeneratedExercise: Decodable {
        let name: String
        let category: String      // "Strength" or "Cardio"
        let muscleGroup: String   // e.g. "Chest", "Back", "Legs"
        let sets: [GeneratedSet]
    }

    struct GeneratedSet: Decodable {
        let reps: Int
        let weight: Double
    }

    /// Generate a routine from a free-text user prompt.
    ///
    /// - Parameters:
    ///   - userPrompt: What the user wants (e.g. "a 45-minute push day for hypertrophy").
    ///   - availableExercises: The user's exercise library. Gemini will prefer these but
    ///     may suggest new ones if the prompt calls for it.
    static func generate(
        userPrompt: String,
        availableExercises: [ExerciseTemplate]
    ) async throws -> GeneratedRoutine {
        let catalog = availableExercises
            .map { "- \($0.name) [\($0.category.rawValue)/\($0.muscleGroup.rawValue)]" }
            .joined(separator: "\n")

        let prompt = """
        You are designing a workout routine for a fitness tracking app.

        The user wants: \(userPrompt)

        Prefer exercises from the catalog below (use names EXACTLY as written). If the
        user's request requires exercises not in the catalog, you may invent new ones —
        provide an appropriate category and muscle group for each.

        Catalog:
        \(catalog)

        For each exercise, suggest 3–5 working sets with reps and weight (in kg).
        Choose weights that are reasonable for an intermediate lifter unless the user
        specifies otherwise.

        Respond with a JSON object containing:
        - "name": a short routine name (e.g. "Push Day", "Upper Body Strength")
        - "exercises": an ordered array of exercise objects, each with:
          - "name": exercise name
          - "category": "Strength" or "Cardio"
          - "muscleGroup": one of "Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Full Body", "Cardio"
          - "sets": array of objects with "reps" (integer) and "weight" (number, kg)
        """

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "exercises": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "category": ["type": "string"],
                            "muscleGroup": ["type": "string"],
                            "sets": [
                                "type": "array",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "reps": ["type": "integer"],
                                        "weight": ["type": "number"]
                                    ],
                                    "required": ["reps", "weight"]
                                ]
                            ]
                        ],
                        "required": ["name", "category", "muscleGroup", "sets"]
                    ]
                ]
            ],
            "required": ["name", "exercises"]
        ]

        return try await GeminiClient.generateJSON(
            prompt: prompt,
            schema: schema,
            as: GeneratedRoutine.self
        )
    }
}
