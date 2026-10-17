import Foundation

public enum BackupError: Error, Equatable { case driveNotFound, backupMissing, backupCorrupted }

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

    /// Il backup automatico manda la history (segreti compresi) su Google: solo se l'utente l'ha attivato.
    public static func autoEnabled(_ d: UserDefaults = .standard) -> Bool { d.object(forKey: "autoBackup") as? Bool ?? false }

    /// Argomenti per `/bin/sh` che riaprono l'app dopo l'uscita di `pid`; il percorso è un argomento, mai interpolato nello script.
    public static func relaunchArguments(pid: Int32, appPath: String) -> [String] {
        ["-c", #"while kill -0 "$1" 2>/dev/null; do sleep 0.2; done; /usr/bin/open "$2""#, "sh", String(pid), appPath]
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
        // il file temporaneo sta fuori dalla cartella sincronizzata, così Drive non lo carica a metà
        let tmp = fm.temporaryDirectory.appendingPathComponent("trove-backup-\(UUID().uuidString).sqlite")
        defer { try? fm.removeItem(at: tmp) }
        try store.vacuum(into: tmp)
        let final = dest.appendingPathComponent("trove.sqlite")
        if fm.fileExists(atPath: final.path) { _ = try fm.replaceItemAt(final, withItemAt: tmp) } else { try fm.moveItem(at: tmp, to: final) }
        try syncBlobs(from: store.blobsDir, to: blobs)
        pruneBlobs(at: blobs, keeping: store.blobsDir)
    }

    /// Le immagini cancellate in locale spariscono anche dal backup, altrimenti un ripristino le riporterebbe.
    static func pruneBlobs(at dst: URL, keeping src: URL) {
        let fm = FileManager.default
        let live = Set((try? fm.contentsOfDirectory(atPath: src.path)) ?? [])
        for f in (try? fm.contentsOfDirectory(atPath: dst.path)) ?? [] where !live.contains(f) {
            try? fm.removeItem(at: dst.appendingPathComponent(f))
        }
    }

    public static func lastBackupDate(at dest: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: dest.appendingPathComponent("trove.sqlite").path))?[.modificationDate] as? Date
    }

    /// Sostituisce i dati locali con il backup. Lo Store aperto su `dataDir` va chiuso prima.
    /// I dati locali vengono toccati solo dopo che la copia del backup è risultata integra.
    public static func restore(from src: URL, dataDir: URL) throws {
        let fm = FileManager.default
        let db = src.appendingPathComponent("trove.sqlite")
        guard fm.fileExists(atPath: db.path) else { throw BackupError.backupMissing }
        let staged = dataDir.appendingPathComponent("trove.sqlite.restore")
        try? fm.removeItem(at: staged)
        try fm.copyItem(at: db, to: staged)
        guard Store.isValidDatabase(staged) else { try? fm.removeItem(at: staged); throw BackupError.backupCorrupted }
        try syncBlobs(from: src.appendingPathComponent("blobs"), to: dataDir.appendingPathComponent("blobs"))
        for ext in ["-wal", "-shm"] { try? fm.removeItem(at: dataDir.appendingPathComponent("trove.sqlite" + ext)) }
        let live = dataDir.appendingPathComponent("trove.sqlite")
        if fm.fileExists(atPath: live.path) { _ = try fm.replaceItemAt(live, withItemAt: staged) } else { try fm.moveItem(at: staged, to: live) }
    }

    /// Copia i blob mancanti o di dimensione diversa (copia interrotta), via file temporaneo + rename.
    static func syncBlobs(from src: URL, to dst: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dst, withIntermediateDirectories: true)
        func size(_ u: URL) -> Int? { (try? fm.attributesOfItem(atPath: u.path))?[.size] as? Int }
        for f in (try? fm.contentsOfDirectory(atPath: src.path)) ?? [] where !f.hasSuffix(".part") {
            let from = src.appendingPathComponent(f), to = dst.appendingPathComponent(f)
            guard size(from) != size(to) else { continue }
            let part = dst.appendingPathComponent(f + ".part")
            try? fm.removeItem(at: part)
            try fm.copyItem(at: from, to: part)
            try? fm.removeItem(at: to)
            try fm.moveItem(at: part, to: to)
        }
    }
}
