import Foundation
import Testing
@testable import TroveCore

@Suite struct ReviewFixTests {
    @Test func failedRestoreKeepsLocalData() throws {
        let dataDir = tempDir(), bad = tempDir()
        let s = try Store(directory: dataDir)
        try s.insert(textItem("prezioso"))
        s.close()
        try Data("non un database".utf8).write(to: bad.appendingPathComponent("trove.sqlite"))
        #expect(throws: (any Error).self) { try Backup.restore(from: bad, dataDir: dataDir) }
        #expect(try Store(directory: dataDir).count() == 1)
    }

    @Test func truncatedBlobIsRecopied() throws {
        let dataDir = tempDir(), dest = tempDir()
        let s = try Store(directory: dataDir)
        try Data(repeating: 7, count: 100).write(to: s.blobsDir.appendingPathComponent("a.png"))
        try FileManager.default.createDirectory(at: dest.appendingPathComponent("blobs"), withIntermediateDirectories: true)
        try Data([7]).write(to: dest.appendingPathComponent("blobs/a.png")) // copia interrotta
        try Backup.run(store: s, to: dest)
        #expect(try Data(contentsOf: dest.appendingPathComponent("blobs/a.png")).count == 100)
        #expect(!FileManager.default.fileExists(atPath: dest.appendingPathComponent("trove.sqlite.tmp").path))
    }

    @Test func pendingEnrichmentIds() throws {
        let s = try Store(directory: tempDir())
        let a = try s.insert(textItem("a"))
        let b = try s.insert(textItem("b"))
        s.update(ocr: nil, title: nil, tags: "x", embedding: nil, lang: nil, for: a)
        #expect(s.pendingEnrichmentIds() == [b])
    }

    @Test func corpusOmitsHeavyFieldsButGetHasThem() throws {
        let s = try Store(directory: tempDir())
        var it = textItem("rich", kind: .richText); it.rtf = Data([1, 2, 3]); it.html = "<b>rich</b>"
        let id = try s.insert(it)
        #expect(s.all().first?.rtf == nil)
        #expect(s.get(id)?.rtf == Data([1, 2, 3]))
        #expect(s.get(id)?.html == "<b>rich</b>")
    }

    @Test func searchStopsWhenCancelled() async throws {
        let s = try Store(directory: tempDir())
        let corpus = (0..<3000).map { i -> ClipItem in var c = textItem("riga \(i) lorem ipsum"); c.id = Int64(i); return c }
        let t = Task { () -> [ClipItem] in
            withUnsafeCurrentTask { $0?.cancel() }
            return Search.run(Query.parse("lorem"), store: s, corpus: corpus)
        }
        #expect(await t.value.isEmpty)
    }
}
