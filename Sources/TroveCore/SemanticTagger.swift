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
        You index clipboard snippets for search. Reply ONLY with 14 comma-separated lowercase keywords: \
        7 in Italian and 7 in English, covering topic, synonyms and category of the text. No other words.
        """, prompt: String(text.prefix(1500)))
    }

    public static func expand(query: String) async -> [String] {
        await ask(instructions: """
        You expand search queries. Reply ONLY with 10 comma-separated lowercase words: synonyms and closely \
        related terms, 5 in Italian and 5 in English, that would appear in a note matching the query. No other words.
        """, prompt: query)
    }

    private static func ask(instructions: String, prompt: String) async -> [String] {
        guard isAvailable, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        do {
            let r = try await LanguageModelSession(instructions: instructions).respond(to: prompt)
            return r.content.split(whereSeparator: { $0 == "," || $0 == "\n" })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased() }
                .filter { !$0.isEmpty && $0.count < 40 }
        } catch {
            return [] // guardrail o contesto troppo lungo: niente tag, la ricerca testuale resta
        }
    }
}
