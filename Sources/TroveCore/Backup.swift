import Foundation

public enum BackupError: Error, Equatable { case driveNotFound, backupMissing }

/// Backup nella cartella locale di Google Drive per desktop (che sincronizza da sé).
public enum Backup {
    /// `<CloudStorage>/GoogleDrive-*/{My Drive|Il mio Drive|…}/Trove`
    public static func driveFolder(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
        let fm = FileManager.default
        let cloud = home.appendingPathComponent("Library/CloudStorage")
        guard let accounts = try? fm.contentsOfDirectory(atPath: cloud.path) else { return nil }
        for acc in accounts.sorted() where acc.hasPrefix("GoogleDrive-") {
            let base = cloud.appendingPathComponent(acc)
            let roots = (try? fm.contentsOfDirectory(atPath: base.path)) ?? []
            // la cartella personale è localizzata ("My Drive", "Il mio Drive"); "Altri computer"/"Other computers" no
            if let mine = roots.first(where: { ["my drive", "il mio drive", "mein drive", "mi unidad", "mon drive"].contains($0.lowercased()) })
                ?? roots.first(where: { $0.localizedCaseInsensitiveContains("drive") && !$0.hasPrefix(".") }) {
                return base.appendingPathComponent(mine).appendingPathComponent("Trove")
            }
        }
        return nil
    }

    @discardableResult
    public static func runToDrive(store: Store, home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> URL {
        guard let dest = driveFolder(home: home) else { throw BackupError.driveNotFound }
        try run(store: store, to: dest)
        return dest
    }

    /// DB copiato in modo atomico + blob mancanti copiati (incrementale).
    public static func run(store: Store, to dest: URL) throws {
        let fm = FileManager.default
        let blobs = dest.appendingPathComponent("blobs")
        try fm.createDirectory(at: blobs, withIntermediateDirectories: true)
        let tmp = dest.appendingPathComponent("trove.sqlite.tmp")
        try store.vacuum(into: tmp)
        let final = dest.appendingPathComponent("trove.sqlite")
        if fm.fileExists(atPath: final.path) { _ = try fm.replaceItemAt(final, withItemAt: tmp) } else { try fm.moveItem(at: tmp, to: final) }
        let existing = Set((try? fm.contentsOfDirectory(atPath: blobs.path)) ?? [])
        for f in (try? fm.contentsOfDirectory(atPath: store.blobsDir.path)) ?? [] where !existing.contains(f) {
            try fm.copyItem(at: store.blobsDir.appendingPathComponent(f), to: blobs.appendingPathComponent(f))
        }
    }

    public static func lastBackupDate(at dest: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: dest.appendingPathComponent("trove.sqlite").path))?[.modificationDate] as? Date
    }

    /// Sostituisce i dati locali con il backup. Lo Store aperto su `dataDir` va chiuso prima.
    public static func restore(from src: URL, dataDir: URL) throws {
        let fm = FileManager.default
        let db = src.appendingPathComponent("trove.sqlite")
        guard fm.fileExists(atPath: db.path) else { throw BackupError.backupMissing }
        for ext in ["", "-wal", "-shm"] { try? fm.removeItem(at: dataDir.appendingPathComponent("trove.sqlite" + ext)) }
        try fm.copyItem(at: db, to: dataDir.appendingPathComponent("trove.sqlite"))
        let localBlobs = dataDir.appendingPathComponent("blobs")
        try fm.createDirectory(at: localBlobs, withIntermediateDirectories: true)
        let have = Set((try? fm.contentsOfDirectory(atPath: localBlobs.path)) ?? [])
        for f in (try? fm.contentsOfDirectory(atPath: src.appendingPathComponent("blobs").path)) ?? [] where !have.contains(f) {
            try fm.copyItem(at: src.appendingPathComponent("blobs").appendingPathComponent(f), to: localBlobs.appendingPathComponent(f))
        }
    }
}
