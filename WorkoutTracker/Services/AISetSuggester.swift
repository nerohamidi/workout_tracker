import Foundation

/// Asks Gemini to recommend the next set scheme (reps + weight per set) for a given
/// strength exercise, using the user's actual personal-record history as context.
///
/// The model is told what the user has lifted before and asked to pick a sensible
/// progression. We constrain the result to a fixed shape so the caller can drop the
/// suggestions straight into `ExerciseSet` rows.
enum AISetSuggester {
    /// Decoded shape of Gemini's response.
    struct SuggestedSets: Decodable {
        let sets: [SuggestedSet]

        struct SuggestedSet: Decodable {
            let reps: Int
            let weight: Double
        }
    }

    /// Suggest sets for a strength exercise based on past PRs.
    ///
    /// - Parameters:
    ///   - template: The exercise to suggest sets for. Must be a strength exercise —
    ///     cardio is not supported and will throw `AISetSuggesterError.unsupported`.
    ///   - goal: Optional free-text hint (e.g. "hypertrophy", "go heavy today").
    ///     Pass `nil` for a generic progression.
    static func suggest(
        for template: ExerciseTemplate,
        goal: String? = nil
    ) async throws -> SuggestedSets {
        guard template.category == .strength else {
            throw AISetSuggesterError.unsupported
        }

        // Pull the user's existing PRs so Gemini has real numbers to anchor on.
        let records = PersonalRecord.records(for: template)
        let historyLines: String
        if records.isEmpty {
            historyLines = "(no prior history — user is new to this exercise)"
        } else {
            historyLines = records
                .map { "- \($0.reps) reps @ \(formatted($0.weight))" }
                .joined(separator: "\n")
        }

        let goalLine = goal.map { "User goal: \($0)\n" } ?? ""

        let prompt = """
        You are a strength coach suggesting today's working sets for a single exercise.

        Exercise: \(template.name) (\(template.muscleGroup.rawValue))
        \(goalLine)
        Personal records (heaviest weight at each rep count):
        \(historyLines)

        Suggest 3–5 working sets that represent a reasonable progression for today.
        Pick weights that are realistic based on the history (small overload from prior
        bests, or matching weights at slightly higher reps). If there is no history,
        suggest moderate starting weights.

        Respond with a JSON object containing a "sets" array. Each set has:
        - "reps": integer rep count
        - "weight": number (use the same units as the history)
        """

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
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
            "required": ["sets"]
        ]

        return try await GeminiClient.generateJSON(
            prompt: prompt,
            schema: schema,
            as: SuggestedSets.self
        )
    }

    /// Trim trailing zeros so "100.0" reads as "100" in the prompt — keeps the model
    /// from getting confused about precision.
    private static func formatted(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return String(Int(weight))
        }
        return String(weight)
    }
}

enum AISetSuggesterError: LocalizedError {
    case unsupported

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Set suggestions are only available for strength exercises."
        }
    }
}
