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
        if item.kind == .link, let url = titleURL(for: item.text, enabled: UserDefaults.standard.bool(forKey: "fetchLinkTitles")) {
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
    /// e mai per URL con credenziali o query (token, firme, reset password).
    static func titleURL(for text: String, enabled: Bool) -> URL? {
        guard enabled, let u = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              u.user == nil, u.password == nil, u.query == nil else { return nil }
        return u
    }

    @MainActor
    static func linkTitle(_ url: URL) async -> String? {
        let p = LPMetadataProvider()
        p.timeout = 6
        return try? await p.startFetchingMetadata(for: url).title
    }
}
