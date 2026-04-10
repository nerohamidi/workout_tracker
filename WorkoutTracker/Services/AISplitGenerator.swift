import Foundation

/// Asks Gemini to compose a training split — an ordered rotation of routines — from
/// the user's existing routine list.
///
/// Like `AIRoutineGenerator`, this is constrained to names from a supplied list so the
/// result maps cleanly back to real `Routine` records.
enum AISplitGenerator {
    /// Decoded shape of Gemini's response. Matches the `responseSchema` below.
    struct GeneratedSplit: Decodable {
        let name: String
        let routineNames: [String]
    }

    /// Generate a split from a free-text user prompt.
    ///
    /// - Parameters:
    ///   - userPrompt: What the user wants (e.g. "a 4-day upper/lower split").
    ///   - availableRoutines: Routines Gemini may pick from. Pass the user's full list.
    static func generate(
        userPrompt: String,
        availableRoutines: [Routine]
    ) async throws -> GeneratedSplit {
        // Build a catalog with each routine's exercises so Gemini can reason about how
        // they fit together (e.g. avoid putting two leg days back-to-back).
        let catalog = availableRoutines.map { routine -> String in
            let exercises = routine.sortedExercises
                .compactMap { $0.exerciseTemplate?.name }
                .joined(separator: ", ")
            return "- \(routine.name): \(exercises.isEmpty ? "(no exercises)" : exercises)"
        }.joined(separator: "\n")

        let prompt = """
        You are composing a weekly training split for a fitness tracking app. A split is
        an ordered rotation of routines that the user cycles through over the week.

        The user wants: \(userPrompt)

        You MUST pick routine names only from the following list. Use the names EXACTLY
        as written. You may repeat a routine if the split calls for it. Do not invent
        new routines.

        Available routines:
        \(catalog)

        Respond with a JSON object containing:
        - "name": a short split name (e.g. "Push/Pull/Legs", "Upper/Lower 4-Day")
        - "routineNames": an ordered array of routine names — the rotation the user will
          cycle through (typically 3–6 entries)
        """

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "routineNames": [
                    "type": "array",
                    "items": ["type": "string"]
                ]
            ],
            "required": ["name", "routineNames"]
        ]

        return try await GeminiClient.generateJSON(
            prompt: prompt,
            schema: schema,
            as: GeneratedSplit.self
        )
    }
}
