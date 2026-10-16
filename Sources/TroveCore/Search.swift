import Foundation

public struct Query: Equatable {
    public var text: String
    public var kinds: Set<ClipKind>
    public var app: String?
    public var since: Date?

    public init(text: String = "", kinds: Set<ClipKind> = [], app: String? = nil, since: Date? = nil) {
        self.text = text; self.kinds = kinds; self.app = app; self.since = since
    }

    static let kindWords: [String: ClipKind] = [
        "text": .text, "testo": .text, "rich": .richText, "richtext": .richText, "link": .link, "url": .link,
        "image": .image, "immagine": .image, "img": .image, "file": .file, "color": .color, "colore": .color,
    ]

    /// Filtri inline: `type:`/`tipo:`, `app:`, `oggi`/`today`, `ieri`/`yesterday`, `settimana`/`week`, `mese`/`month`.
    public static func parse(_ raw: String, now: Date = Date()) -> Query {
        var q = Query()
        var words: [String] = []
        let cal = Calendar.current
        for w in raw.split(whereSeparator: \.isWhitespace).map(String.init) {
            let l = w.lowercased()
            if let v = l.split(separator: ":", maxSplits: 1).last, l.hasPrefix("type:") || l.hasPrefix("tipo:"),
               let k = kindWords[String(v)] {
                q.kinds.insert(k)
            } else if l.hasPrefix("app:"), l.count > 4 {
                q.app = String(l.dropFirst(4))
            } else if ["oggi", "today"].contains(l) {
                q.since = cal.startOfDay(for: now)
            } else if ["ieri", "yesterday"].contains(l) {
                q.since = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: now))
            } else if ["settimana", "week"].contains(l) {
                q.since = now.addingTimeInterval(-7 * 86400)
            } else if ["mese", "month"].contains(l) {
                q.since = now.addingTimeInterval(-30 * 86400)
            } else {
                words.append(w)
            }
        }
        q.text = words.joined(separator: " ")
        return q
    }
}

/// Ricerca ibrida: FTS trigram + fuzzy (typo) + espansione semantica + embedding.
// ponytail: scansione lineare del corpus, ok fino a ~50k elementi; oltre servirebbe un indice ANN.
public enum Search {
    public static func run(_ q: Query, store: Store, corpus: [ClipItem]? = nil, expansions: [String] = [],
                           limit: Int = 300) -> [ClipItem] {
        let items = (corpus ?? store.all()).filter { it in
            (q.kinds.isEmpty || q.kinds.contains(it.kind))
                && (q.app.map { (it.sourceApp ?? "").localizedCaseInsensitiveContains($0) } ?? true)
                && (q.since.map { it.createdAt >= $0 } ?? true)
        }
        let text = q.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return Array(items.sorted { $0.createdAt > $1.createdAt }.prefix(limit)) }

        let fts = Set(store.ftsSearch(text, limit: 5000))
        var expanded: [Int64: Int] = [:] // quanti termini di espansione colpiscono ogni elemento
        for term in Set(expansions) where term.count >= 3 {
            for id in store.ftsSearch(term, limit: 500) { expanded[id, default: 0] += 1 }
        }
        let tokens = normalize(text).split(separator: " ").map(String.init)
        let qvec = Embedder.embed(text)

        var scored: [(ClipItem, Double)] = []
        for it in items {
            var s = 0.0
            if fts.contains(it.id) { s += 1 }
            s += fuzzyScore(tokens, words(it)) * 0.8
            if let n = expanded[it.id] { s += min(0.9, 0.3 * Double(n)) }
            if let qv = qvec, let e = it.embedding, it.embeddingLang == qv.lang {
                let c = Double(Embedder.cosine(qv.vec, e))
                if c >= 0.68 { s += c - 0.6 }
            }
            if s > 0 { scored.append((it, s)) }
        }
        scored.sort { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.createdAt > $1.0.createdAt }
        return scored.prefix(limit).map(\.0)
    }

    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func words(_ it: ClipItem) -> [String] {
        normalize(String(it.searchableText.prefix(4000)) + " " + (it.sourceApp ?? "")).split(separator: " ").map(String.init)
    }

    /// Media sui token della query: 1 se sottostringa di una parola, 0.8 se entro 1–2 errori; 0 se un token non trova nulla.
    static func fuzzyScore(_ tokens: [String], _ words: [String]) -> Double {
        guard !tokens.isEmpty else { return 0 }
        var total = 0.0
        for t in tokens {
            var best = 0.0
            for w in words {
                if w.contains(t) { best = 1; break }
                if t.count >= 4, best < 0.8 {
                    let maxEdits = t.count <= 5 ? 1 : 2
                    if abs(w.count - t.count) <= maxEdits, osa(t, w, max: maxEdits) <= maxEdits { best = 0.8 }
                    else if w.count > t.count, osa(t, String(w.prefix(t.count)), max: maxEdits) <= maxEdits - (t.count <= 5 ? 0 : 1) { best = 0.8 }
                }
            }
            if best == 0 { return 0 }
            total += best
        }
        return total / Double(tokens.count)
    }

    /// Distanza Damerau-Levenshtein (optimal string alignment), con uscita anticipata oltre `max`.
    static func osa(_ a: String, _ b: String, max: Int) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty || b.isEmpty { return Swift.max(a.count, b.count) }
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...a.count {
            var rowMin = Int.max
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                d[i][j] = Swift.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] { d[i][j] = Swift.min(d[i][j], d[i - 2][j - 2] + 1) }
                rowMin = Swift.min(rowMin, d[i][j])
            }
            if rowMin > max { return rowMin }
        }
        return d[a.count][b.count]
    }
}
