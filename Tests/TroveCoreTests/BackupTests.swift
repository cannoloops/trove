import Foundation
import Testing
@testable import TroveCore

@Suite struct BackupTests {
    @Test func backupWithoutDriveThrows() throws {
        let s = try Store(directory: tempDir())
        #expect(Backup.driveFolder(home: tempDir()) == nil)
        #expect(throws: BackupError.driveNotFound) { try Backup.runToDrive(store: s, home: tempDir()) }
    }

    @Test func findsLocalizedDriveFolder() throws {
        let home = tempDir()
        let mine = home.appendingPathComponent("Library/CloudStorage/GoogleDrive-a@b.com/Il mio Drive")
        try FileManager.default.createDirectory(at: mine, withIntermediateDirectories: true)
        #expect(Backup.driveFolder(home: home)?.standardizedFileURL == mine.appendingPathComponent("Trove").standardizedFileURL)
    }

    @Test func backupRoundTrip() throws {
        let dataDir = tempDir(), dest = tempDir()
        let s = try Store(directory: dataDir)
        try Data([9, 9]).write(to: s.blobsDir.appendingPathComponent("a.png"))
        var img = textItem("", kind: .image); img.hash = "img"; img.blobPath = "a.png"
        try s.insert(img)
        try s.insert(textItem("ricordami"))
        try Backup.run(store: s, to: dest)
        #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("trove.sqlite").path))
        #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("blobs/a.png").path))

        s.deleteAll()
        #expect(s.count() == 0)
        s.close()
        try Backup.restore(from: dest, dataDir: dataDir)
        let r = try Store(directory: dataDir)
        #expect(r.count() == 2)
        #expect(r.ftsSearch("ricordami", limit: 5).count == 1)
        #expect(FileManager.default.fileExists(atPath: r.blobsDir.appendingPathComponent("a.png").path))
        #expect(Backup.lastBackupDate(at: dest) != nil)
    }
}
