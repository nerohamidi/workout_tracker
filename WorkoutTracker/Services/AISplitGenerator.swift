import Foundation

/// Asks Gemini to design a complete training split — multiple routines, each with
/// exercises and set schemes — from a single user prompt. No pre-existing routines
/// are required.
///
/// Like `AIRoutineGenerator`, Gemini prefers exercises from the user's library but
/// may invent new ones. The caller is responsible for creating all the SwiftData
/// records (`TrainingSplit`, `SplitRoutine`, `Routine`, `RoutineExercise`,
/// `RoutineSet`, and any new `ExerciseTemplate`s).
enum AISplitGenerator {
    /// Top-level decoded response.
    struct GeneratedSplit: Decodable {
        let name: String
        let routines: [GeneratedSplitRoutine]
    }

    struct GeneratedSplitRoutine: Decodable {
        let name: String
        let exercises: [GeneratedExercise]
    }

    struct GeneratedExercise: Decodable {
        let name: String
        let category: String
        let muscleGroup: String
        let sets: [GeneratedSet]
    }

    struct GeneratedSet: Decodable {
        let reps: Int
        let weight: Double
    }

    /// Generate a full split from a free-text user prompt.
    ///
    /// - Parameters:
    ///   - userPrompt: What the user wants (e.g. "a 6-day PPL split for hypertrophy").
    ///   - availableExercises: The user's exercise library. Gemini will prefer these.
    static func generate(
        userPrompt: String,
        availableExercises: [ExerciseTemplate]
    ) async throws -> GeneratedSplit {
        let catalog = availableExercises
            .map { "- \($0.name) [\($0.category.rawValue)/\($0.muscleGroup.rawValue)]" }
            .joined(separator: "\n")

        let prompt = """
        You are designing a complete training split for a fitness tracking app. A split
        is an ordered rotation of routines that the user cycles through over the week.

        The user wants: \(userPrompt)

        Prefer exercises from the catalog below (use names EXACTLY as written). If the
        user's request requires exercises not in the catalog, you may invent new ones —
        provide an appropriate category and muscle group for each.

        Catalog:
        \(catalog)

        For each exercise in each routine, suggest 3–5 working sets with reps and weight
        (in kg). Choose weights reasonable for an intermediate lifter unless the user
        specifies otherwise.

        Respond with a JSON object containing:
        - "name": a short split name (e.g. "Push/Pull/Legs", "Upper/Lower 4-Day")
        - "routines": an ordered array of routine objects, each with:
          - "name": routine name (e.g. "Push Day", "Pull Day")
          - "exercises": ordered array of exercise objects, each with:
            - "name": exercise name
            - "category": "Strength" or "Cardio"
            - "muscleGroup": one of "Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Full Body", "Cardio"
            - "sets": array of objects with "reps" (integer) and "weight" (number, kg)
        """

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "routines": [
                    "type": "array",
                    "items": [
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
                ]
            ],
            "required": ["name", "routines"]
        ]

        return try await GeminiClient.generateJSON(
            prompt: prompt,
            schema: schema,
            as: GeneratedSplit.self
        )
    }
}
