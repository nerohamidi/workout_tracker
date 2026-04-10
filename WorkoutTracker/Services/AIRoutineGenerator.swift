import Foundation

/// Asks Gemini to design a workout routine and return a list of exercises drawn from
/// the user's existing exercise library.
///
/// We constrain Gemini to *names from the supplied library* (rather than letting it
/// invent exercises) so that the result can be hooked up to real `ExerciseTemplate`
/// records on the device. The caller is responsible for resolving names back to
/// templates and creating the `Routine` + `RoutineExercise` records.
enum AIRoutineGenerator {
    /// Decoded shape of Gemini's response. Matches the `responseSchema` below.
    struct GeneratedRoutine: Decodable {
        let name: String
        let exerciseNames: [String]
    }

    /// Generate a routine from a free-text user prompt.
    ///
    /// - Parameters:
    ///   - userPrompt: What the user wants (e.g. "a 45-minute push day for hypertrophy").
    ///   - availableExercises: The exercises Gemini is allowed to choose from. Pass the
    ///     full library so it has options across muscle groups.
    static func generate(
        userPrompt: String,
        availableExercises: [ExerciseTemplate]
    ) async throws -> GeneratedRoutine {
        // Build a compact catalog so Gemini knows the exact names it must pick from.
        // Format: "Bench Press [Strength/Chest]" — one per line.
        let catalog = availableExercises
            .map { "- \($0.name) [\($0.category.rawValue)/\($0.muscleGroup.rawValue)]" }
            .joined(separator: "\n")

        let prompt = """
        You are designing a workout routine for a fitness tracking app.

        The user wants: \(userPrompt)

        You MUST pick exercises only from the following catalog. Use the names EXACTLY
        as written (case and spelling). Do not invent new exercises.

        Catalog:
        \(catalog)

        Respond with a JSON object containing:
        - "name": a short routine name (e.g. "Push Day", "Upper Body Strength")
        - "exerciseNames": an ordered array of exercise names from the catalog (typically
          5–8 exercises, in the order they should be performed)
        """

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "exerciseNames": [
                    "type": "array",
                    "items": ["type": "string"]
                ]
            ],
            "required": ["name", "exerciseNames"]
        ]

        return try await GeminiClient.generateJSON(
            prompt: prompt,
            schema: schema,
            as: GeneratedRoutine.self
        )
    }
}
