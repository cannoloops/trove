import NaturalLanguage

/// Sentence embedding on-device (NaturalLanguage), lingua it o en.
public enum Embedder {
    nonisolated(unsafe) private static var cache: [NLLanguage: NLEmbedding] = [:]
    private static let lock = NSLock()

    public static func language(of text: String) -> NLLanguage {
        let r = NLLanguageRecognizer()
        r.languageConstraints = [.italian, .english]
        r.processString(String(text.prefix(1000)))
        return r.dominantLanguage ?? .english
    }

    public static func embed(_ text: String) -> (vec: [Float], lang: String)? {
        let t = String(text.prefix(1000))
        guard t.count >= 3 else { return nil }
        let lang = language(of: t)
        // NLEmbedding non è thread-safe: modello e vector(for:) sotto lo stesso lock.
        let v: [Double]? = lock.withLock {
            if cache[lang] == nil { cache[lang] = NLEmbedding.sentenceEmbedding(for: lang) }
            return cache[lang]?.vector(for: t)
        }
        guard let v else { return nil }
        return (v.map(Float.init), lang.rawValue)
    }

    public static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var d: Float = 0, na: Float = 0, nb: Float = 0
        for i in a.indices { d += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
        return na == 0 || nb == 0 ? 0 : d / (na.squareRoot() * nb.squareRoot())
    }
}
