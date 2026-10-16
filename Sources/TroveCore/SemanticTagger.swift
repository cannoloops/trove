import Foundation
import FoundationModels

/// Parole chiave e sinonimi it/en dal modello linguistico on-device di Apple.
public enum SemanticTagger {
    public static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Una richiesta per lingua: chiedendo "metà in italiano, metà in inglese" il modello risponde in una sola lingua,
    /// e tag e query in lingue diverse non si incontrano più.
    public static func keywords(for text: String) async -> [String] {
        let t = String(text.prefix(1500))
        async let it = ask(instructions: """
        You index clipboard snippets for search. Reply ONLY with 10 comma-separated lowercase ITALIAN keywords: topic, \
        synonyms, people/professions, places, objects and category of the text. Italian words only. Never repeat a word.
        """, prompt: t)
        async let en = ask(instructions: """
        You index clipboard snippets for search. Reply ONLY with 10 comma-separated lowercase ENGLISH keywords: topic, \
        synonyms, people/professions, places, objects and category of the text. English words only. Never repeat a word.
        """, prompt: t)
        return unique(await it + en)
    }

    public static func expand(query: String) async -> [String] {
        @Sendable func instr(_ lang: String) -> String {
            """
            You expand a search query for a notes app. Reply ONLY with 8 comma-separated lowercase \(lang) words: synonyms, \
            related professions, places, objects and activities that a matching note might contain. \(lang) words only.
            """
        }
        async let it = ask(instructions: instr("ITALIAN"), prompt: query)
        async let en = ask(instructions: instr("ENGLISH"), prompt: query)
        return unique(await it + en)
    }

    private static func unique(_ words: [String]) -> [String] {
        words.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    }

    /// "topic: art, Canvas, canvas, - brush." → ["art", "canvas", "brush"]
    static func parse(_ content: String) -> [String] {
        content.split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { part -> String in
                let p = part.split(separator: ":").last.map(String.init) ?? ""
                return p.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
            }
            .filter { !$0.isEmpty && $0.count < 40 }
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    }

    private static func ask(instructions: String, prompt: String) async -> [String] {
        guard isAvailable, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        do {
            let r = try await LanguageModelSession(instructions: instructions).respond(to: prompt, options: GenerationOptions(sampling: .greedy))
            return parse(r.content)
        } catch {
            return [] // guardrail o contesto troppo lungo: niente tag, la ricerca testuale resta
        }
    }
}
