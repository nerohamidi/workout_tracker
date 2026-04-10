import Foundation

/// Thin wrapper around Google's Gemini REST API. Targets the `generateContent` endpoint
/// with structured-output (`responseMimeType: application/json` + `responseSchema`).
///
/// Why hand-rolled instead of an SDK: there's no first-party Swift SDK for Gemini, and
/// the surface area we use is tiny — one POST per request. Keeping it as plain
/// URLSession means zero new dependencies.
///
/// API key resolution order:
///   1. `UserDefaults` value `geminiAPIKeyOverride` (set by the user in Settings)
///   2. `Secrets.geminiAPIKey` (baked in at build time from `.env`)
/// Available Gemini models. Persisted via `@AppStorage("geminiModel")`.
enum GeminiModel: String, CaseIterable {
    case flashLite = "gemini-3.1-flash-lite-preview"
    case flash = "gemini-3-flash-preview"
    case pro = "gemini-3.1-pro-preview"

    var displayName: String {
        switch self {
        case .flashLite: return "Flash Lite"
        case .flash:     return "Flash"
        case .pro:       return "Pro"
        }
    }
}

enum GeminiClient {
    /// Resolve the model from user preference or default.
    static var model: String {
        let stored = UserDefaults.standard.string(forKey: "geminiModel") ?? ""
        if let chosen = GeminiModel(rawValue: stored) {
            return chosen.rawValue
        }
        return GeminiModel.flashLite.rawValue
    }

    enum GeminiError: LocalizedError {
        case missingAPIKey
        case httpError(status: Int, body: String)
        case emptyResponse
        case invalidJSON(underlying: Error, raw: String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "No Gemini API key configured. Add one in Settings."
            case .httpError(let status, let body):
                return "Gemini returned HTTP \(status): \(body)"
            case .emptyResponse:
                return "Gemini returned no content."
            case .invalidJSON(let underlying, _):
                return "Couldn't parse Gemini response: \(underlying.localizedDescription)"
            }
        }
    }

    /// Resolve the API key from user override or build-time secrets. Empty string means
    /// no key is configured.
    static var apiKey: String {
        let override = UserDefaults.standard.string(forKey: "geminiAPIKeyOverride") ?? ""
        let trimmed = override.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        return Secrets.geminiAPIKey
    }

    /// Send a prompt to Gemini with a JSON response schema and decode the result.
    ///
    /// - Parameters:
    ///   - prompt: The user prompt. We send it as a single `user` turn.
    ///   - schema: A JSON schema (as a `[String: Any]` dict) describing the expected
    ///     response shape. Gemini enforces this — the response will conform.
    ///   - type: The Decodable type to decode the response into. Must match `schema`.
    /// - Returns: The decoded response.
    static func generateJSON<T: Decodable>(
        prompt: String,
        schema: [String: Any],
        as type: T.Type
    ) async throws -> T {
        let key = apiKey
        guard !key.isEmpty else { throw GeminiError.missingAPIKey }

        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        components.queryItems = [URLQueryItem(name: "key", value: key)]

        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": prompt]]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": schema,
                "temperature": 0.7
            ]
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.httpError(status: 0, body: "Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<binary>"
            throw GeminiError.httpError(status: http.statusCode, body: bodyText)
        }

        // The structured-output response has the shape:
        // { "candidates": [ { "content": { "parts": [ { "text": "<json string>" } ] } } ] }
        guard
            let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = envelope["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String,
            !text.isEmpty
        else {
            throw GeminiError.emptyResponse
        }

        do {
            let payload = Data(text.utf8)
            return try JSONDecoder().decode(T.self, from: payload)
        } catch {
            throw GeminiError.invalidJSON(underlying: error, raw: text)
        }
    }
}
