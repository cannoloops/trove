import Foundation
import Testing
@testable import TroveCore

func tempDir() -> URL {
    let u = FileManager.default.temporaryDirectory.appendingPathComponent("trove-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}

func textItem(_ s: String, kind: ClipKind = .text, app: String? = nil, at: Date = Date()) -> ClipItem {
    ClipItem(kind: kind, text: s, sourceApp: app, createdAt: at, hash: Classifier.hash(Data(s.utf8)))
}

@Suite struct StoreTests {
    @Test func dedupMovesToTop() throws {
        let s = try Store(directory: tempDir())
        let a = try s.insert(textItem("alpha", at: Date(timeIntervalSince1970: 100)))
        _ = try s.insert(textItem("beta", at: Date(timeIntervalSince1970: 200)))
        let a2 = try s.insert(textItem("alpha", at: Date(timeIntervalSince1970: 300)))
        #expect(a == a2)
        let r = s.recent(limit: 10, offset: 0)
        #expect(r.map(\.text) == ["alpha", "beta"])
        #expect(s.count() == 2)
    }

    @Test func ftsMatchesOCRText() throws {
        let s = try Store(directory: tempDir())
        var img = textItem("", kind: .image)
        img.hash = "img1"
        let id = try s.insert(img)
        s.update(ocr: "Fattura Enel numero 4521", title: nil, embedding: nil, lang: nil, for: id)
        #expect(s.ftsSearch("enel", limit: 10) == [id])
    }

    @Test func shortQueryUsesLike() throws {
        let s = try Store(directory: tempDir())
        let id = try s.insert(textItem("ok va bene"))
        _ = try s.insert(textItem("niente"))
        #expect(s.ftsSearch("ok", limit: 10) == [id])
    }

    @Test func searchEscapesSpecialChars() throws {
        let s = try Store(directory: tempDir())
        let id = try s.insert(textItem("say \"hello\" (world) -x*"))
        for q in ["\"hello\"", "(world", "-x*", "\"", "AND OR NOT"] { _ = s.ftsSearch(q, limit: 10) }
        #expect(s.ftsSearch("\"hello\"", limit: 10) == [id])
    }

    @Test func deleteRemovesItemAndBlob() throws {
        let dir = tempDir()
        let s = try Store(directory: dir)
        let blob = s.blobsDir.appendingPathComponent("x.png")
        try Data([1, 2]).write(to: blob)
        var it = textItem("", kind: .image); it.hash = "h"; it.blobPath = "x.png"
        let id = try s.insert(it)
        s.delete(id)
        #expect(s.get(id) == nil)
        #expect(!FileManager.default.fileExists(atPath: blob.path))
    }

    @Test func embeddingRoundTrip() throws {
        let s = try Store(directory: tempDir())
        let id = try s.insert(textItem("v"))
        s.update(ocr: nil, title: "T", embedding: [0.5, -1, 2], lang: "it", for: id)
        let g = s.get(id)!
        #expect(g.embedding == [0.5, -1, 2])
        #expect(g.embeddingLang == "it")
        #expect(g.title == "T")
    }
}
