import Foundation
import Testing
@testable import TroveCore

@Suite struct SecurityTests {
    // S1
    @Test func linkTitlesOnlyWhenEnabledAndNeverForTokens() {
        #expect(Enricher.titleURL(for: "https://example.com/a", enabled: false) == nil)
        #expect(Enricher.titleURL(for: "https://example.com/a", enabled: true) != nil)
        #expect(Enricher.titleURL(for: "https://example.com/login?token=abc", enabled: true) == nil)
        #expect(Enricher.titleURL(for: "https://user:pw@example.com/", enabled: true) == nil)
    }

    // S2
    @Test func autoBackupIsOptIn() throws {
        let d = try #require(UserDefaults(suiteName: "trove-test-\(UUID().uuidString)"))
        #expect(!Backup.autoEnabled(d))
        d.set(true, forKey: "autoBackup")
        #expect(Backup.autoEnabled(d))
    }

    // S3
    @Test func blobPathCannotEscapeBlobsDir() throws {
        let dir = tempDir()
        let s = try Store(directory: dir)
        let victim = dir.appendingPathComponent("victim")
        try Data([1]).write(to: victim)
        var it = textItem("x", kind: .image); it.blobPath = "../victim"
        s.delete(try s.insert(it))
        #expect(FileManager.default.fileExists(atPath: victim.path))
        #expect(s.blobURL("..") == nil && s.blobURL("a/b.png") == nil && s.blobURL("") == nil)
        #expect(s.blobURL("ok.png") == s.blobsDir.appendingPathComponent("ok.png"))
    }

    // S4
    @Test func pruneRemovesOnlyOldCachedImages() throws {
        let cache = tempDir()
        let old = cache.appendingPathComponent("trove-old.png"), fresh = cache.appendingPathComponent("trove-new.png")
        try Data([1]).write(to: old); try Data([1]).write(to: fresh)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-2 * 86400)], ofItemAtPath: old.path)
        AgentPaste.prune(cacheDir: cache)
        #expect(!FileManager.default.fileExists(atPath: old.path))
        #expect(FileManager.default.fileExists(atPath: fresh.path))
    }

    // S5: un percorso con `"` e `$(…)` resta un argomento e non viene eseguito
    @Test func relaunchDoesNotInterpolatePath() throws {
        let marker = tempDir().appendingPathComponent("pwned")
        let evil = "/tmp/a\"; touch \(marker.path); \"$(touch \(marker.path)).app"
        var args = Backup.relaunchArguments(pid: 999_999, appPath: evil)
        #expect(!args[1].contains(evil))
        args[1] = args[1].replacingOccurrences(of: "/usr/bin/open", with: "/bin/echo") // non aprire nulla davvero
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = args
        p.standardOutput = Pipe()
        try p.run(); p.waitUntilExit()
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }
}
