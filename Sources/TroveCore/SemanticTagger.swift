import Foundation
import FoundationModels

/// Parole chiave e sinonimi it/en dal modello linguistico on-device di Apple.
public enum SemanticTagger {
    public static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    public static func keywords(for text: String) async -> [String] {
        await ask(instructions: """
        You index clipboard snippets for search. Reply ONLY with 16 comma-separated lowercase keywords: \
        8 in Italian and 8 in English. Include the topic, synonyms, the people/professions, places and objects \
        involved, and the category. Never repeat a word.
        """, prompt: String(text.prefix(1500)))
    }

    public static func expand(query: String) async -> [String] {
        await ask(instructions: """
        You expand a search query for a notes app. Reply ONLY with 12 comma-separated lowercase words, \
        6 in Italian and 6 in English: synonyms, related professions, places, objects and activities that a \
        matching note might contain. Never repeat the query words.
        """, prompt: query)
    }

    private static func ask(instructions: String, prompt: String) async -> [String] {
        guard isAvailable, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        do {
            let r = try await LanguageModelSession(instructions: instructions).respond(to: prompt, options: GenerationOptions(sampling: .greedy))
            return r.content.split(whereSeparator: { $0 == "," || $0 == "\n" })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased() }
                .filter { !$0.isEmpty && $0.count < 40 }
                .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        } catch {
            return [] // guardrail o contesto troppo lungo: niente tag, la ricerca testuale resta
        }
    }
}
