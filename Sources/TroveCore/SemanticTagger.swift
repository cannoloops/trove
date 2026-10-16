import Foundation
import FoundationModels

/// Parole chiave e sinonimi it/en dal modello linguistico on-device di Apple.
public enum SemanticTagger {
    public static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Una richiesta per lingua, con l'istruzione scritta nella lingua voluta: chiedendo "metà e metà" (o "English only"
    /// su un testo italiano) il modello risponde nella lingua del testo, e tag e query in lingue diverse non si incontrano.
    static let tagIT = """
    Indicizzi appunti per la ricerca. Rispondi SOLO con 10 parole chiave italiane minuscole separate da virgola: \
    argomento, sinonimi, professioni, luoghi, oggetti e categoria del testo. Solo parole italiane, anche se il testo è in inglese.
    """
    static let tagEN = """
    Translate the meaning of the text into English, then reply ONLY with 10 comma-separated lowercase English keywords \
    (topic, synonyms, professions, places, objects, category). Every keyword must be an English word, even if the text is Italian.
    """
    static let expandIT = """
    Sei il motore di ricerca di un'app di appunti. Dato un termine di ricerca, rispondi SOLO con 8 parole italiane minuscole \
    separate da virgola: sinonimi e parole che comparirebbero in una nota pertinente (oggetti, luoghi, professioni, documenti). \
    Nessun'altra parola.
    """
    static let expandEN = """
    You are the search engine of a notes app. Given a search term in any language, reply ONLY with 8 lowercase English words \
    separated by commas: synonyms and words that would appear in a relevant note (objects, places, professions, documents). \
    No other words.
    """

    public static func keywords(for text: String) async -> [String] {
        let t = String(text.prefix(1500))
        // in sequenza: il modello on-device rifiuta richieste concorrenti
        let it = await ask(instructions: tagIT, prompt: t)
        let en = await ask(instructions: tagEN, prompt: t)
        return unique(it + en)
    }

    public static func expand(query: String) async -> [String] {
        let it = await ask(instructions: expandIT, prompt: query)
        let en = await ask(instructions: expandEN, prompt: query)
        return unique(it + en)
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
        for attempt in 0..<2 {
            do {
                let r = try await LanguageModelSession(instructions: instructions)
                    .respond(to: prompt, options: GenerationOptions(sampling: .greedy))
                return parse(r.content)
            } catch {
                NSLog("Trove semantic: %@", String(describing: error))
                if attempt == 0 { try? await Task.sleep(for: .milliseconds(400)) } // modello occupato: un secondo tentativo
            }
        }
        return [] // guardrail o contesto troppo lungo: niente tag, la ricerca testuale resta
    }
}
