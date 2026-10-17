import CoreGraphics
import Foundation
import ImageIO
import LinkPresentation
import Vision

/// Arricchimento in background: OCR immagini, titolo link, tag semantici, embedding.
public enum Enricher {
    public static func enrich(_ item: ClipItem, store: Store) async {
        var ocr: String?
        var title: String?
        if item.kind == .image, let url = item.blobPath.flatMap(store.blobURL),
           let src = CGImageSourceCreateWithURL(url as CFURL, nil),
           let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            ocr = try? await self.ocr(cg)
        }
        // solo se manca: un ri-arricchimento (aggiornamento, ripristino) non riapre tutta la history
        if item.kind == .link, item.title == nil, let url = titleURL(for: item.text, enabled: UserDefaults.standard.bool(forKey: "fetchLinkTitles")) {
            title = await linkTitle(url)
        }
        var full = item
        full.ocr = ocr ?? item.ocr
        full.title = title ?? item.title
        let basis = [full.text, full.ocr ?? "", full.title ?? ""].joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = basis.count >= 3 ? await SemanticTagger.keywords(for: basis) : []
        let emb = Embedder.embed(basis)
        store.update(ocr: ocr, title: title, tags: tags.isEmpty ? nil : tags.joined(separator: ", "),
                     embedding: emb?.vec, lang: emb?.lang, for: item.id)
    }

    public static func ocr(_ image: CGImage) async throws -> String {
        var req = RecognizeTextRequest()
        req.recognitionLanguages = [Locale.Language(identifier: "it-IT"), Locale.Language(identifier: "en-US")]
        req.usesLanguageCorrection = true
        let obs = try await req.perform(on: image)
        return obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    /// Aprire un link copiato rivela l'IP al sito e può consumare link monouso: solo su richiesta dell'utente,
    /// e mai per URL con credenziali o query (token, firme, reset password), con un token nel percorso
    /// o verso la rete locale (router, NAS, servizi su localhost).
    static func titleURL(for text: String, enabled: Bool) -> URL? {
        guard enabled, let u = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(u.scheme?.lowercased() ?? ""), let host = u.host?.lowercased(),
              u.user == nil, u.password == nil, u.query == nil, !isLocal(host) else { return nil }
        // es. /reset/8f3a9c1e2b7d4a6f0c11 o un JWT: 20+ lettere e cifre di fila
        if u.path.range(of: #"(?=[A-Za-z0-9]*\d)(?=[A-Za-z0-9]*[A-Za-z])[A-Za-z0-9]{20,}"#, options: .regularExpression) != nil { return nil }
        return u
    }

    // ponytail: guarda solo il nome scritto nell'URL; un dominio pubblico che risolve a un IP privato (o un redirect) passa
    static func isLocal(_ host: String) -> Bool {
        let h = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if h == "localhost" || !h.contains(".") && !h.contains(":") { return true }  // host senza punto: rete interna
        if [".local", ".localhost", ".internal", ".lan", ".home.arpa"].contains(where: h.hasSuffix) { return true }
        if h.contains(":") { return h == "::1" || h.hasPrefix("fc") || h.hasPrefix("fd") || h.hasPrefix("fe80") || h.hasPrefix("::ffff:") }
        let o = h.split(separator: ".").compactMap { Int($0) }
        guard o.count == 4 else { return false }
        return o[0] == 10 || o[0] == 127 || o[0] == 0 || (o[0] == 169 && o[1] == 254) || (o[0] == 192 && o[1] == 168)
            || (o[0] == 172 && (16...31).contains(o[1])) || (o[0] == 100 && (64...127).contains(o[1]))
    }

    @MainActor
    static func linkTitle(_ url: URL) async -> String? {
        let p = LPMetadataProvider()
        p.timeout = 6
        return try? await p.startFetchingMetadata(for: url).title
    }
}
