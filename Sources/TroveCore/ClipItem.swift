import Foundation

public enum ClipKind: String, CaseIterable, Sendable {
    case text, richText, link, image, file, color

    public var label: String {
        switch self {
        case .text: "Testo"
        case .richText: "Rich text"
        case .link: "Link"
        case .image: "Immagine"
        case .file: "File"
        case .color: "Colore"
        }
    }
}

public struct ClipItem: Identifiable, Equatable, Sendable {
    public var id: Int64 = 0
    public var kind: ClipKind
    public var text: String
    public var rtf: Data?
    public var html: String?
    public var blobPath: String?
    public var filePaths: [String] = []
    public var sourceApp: String?
    public var sourceBundle: String?
    public var createdAt: Date
    public var hash: String
    public var ocr: String?
    public var title: String?
    public var embedding: [Float]?
    public var embeddingLang: String?

    public init(kind: ClipKind, text: String, rtf: Data? = nil, html: String? = nil, blobPath: String? = nil,
                filePaths: [String] = [], sourceApp: String? = nil, sourceBundle: String? = nil,
                createdAt: Date = Date(), hash: String) {
        self.kind = kind; self.text = text; self.rtf = rtf; self.html = html; self.blobPath = blobPath
        self.filePaths = filePaths; self.sourceApp = sourceApp; self.sourceBundle = sourceBundle
        self.createdAt = createdAt; self.hash = hash
    }

    /// Testo su cui cercare: contenuto + OCR + titolo link.
    public var searchableText: String {
        [text, ocr ?? "", title ?? "", filePaths.joined(separator: " ")].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
