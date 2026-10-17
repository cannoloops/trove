import Foundation
import Testing
@testable import TroveCore

@Suite struct DeletionTests {
    private func bytes(_ dir: URL) -> Data {
        ["trove.sqlite", "trove.sqlite-wal"].reduce(into: Data()) { d, f in
            d += (try? Data(contentsOf: dir.appendingPathComponent(f))) ?? Data()
        }
    }

    /// Il testo cancellato non deve restare nelle pagine libere, nel WAL né nell'indice FTS.
    @Test func deletedTextLeavesNoTraceOnDisk() throws {
        let dir = tempDir()
        let s = try Store(directory: dir)
        for i in 0..<50 { try s.insert(textItem("riga di riempimento numero \(i)")) }
        let marker = "QZXmarcatoreSegretoQZX"
        let id = try s.insert(textItem("password \(marker) da dimenticare"))
        #expect(bytes(dir).range(of: Data(marker.utf8)) != nil)
        s.delete(id)
        #expect(bytes(dir).range(of: Data(marker.utf8)) == nil)
        #expect(s.ftsSearch("marcatore", limit: 5).isEmpty)
    }

    @Test func deleteAllLeavesNoTraceOnDisk() throws {
        let dir = tempDir()
        let s = try Store(directory: dir)
        let marker = "QZXtuttoQZX"
        for i in 0..<20 { try s.insert(textItem("\(marker) \(i)")) }
        s.deleteAll()
        #expect(bytes(dir).range(of: Data(marker.utf8)) == nil)
    }

    @Test func backupDropsBlobsDeletedLocally() throws {
        let dest = tempDir()
        let s = try Store(directory: tempDir())
        try Data([1]).write(to: s.blobsDir.appendingPathComponent("a.png"))
        var img = textItem("", kind: .image); img.hash = "img"; img.blobPath = "a.png"
        let id = try s.insert(img)
        try Backup.run(store: s, to: dest)
        #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("blobs/a.png").path))
        s.delete(id)
        try Backup.run(store: s, to: dest)
        #expect(!FileManager.default.fileExists(atPath: dest.appendingPathComponent("blobs/a.png").path))
    }
}
