import Foundation

/// "Incolla per agenti": testo pulito e senza segreti, immagini come percorso file.
public enum AgentPaste {
    public static func text(_ s: String, fromTerminal: Bool = false) -> String {
        Secrets.redact(Cleaner.clean(s, fromTerminal: fromTerminal)).text
    }

    /// Copia il blob in una cartella senza spazi nel percorso (comoda da incollare in un terminale).
    public static func imagePath(blob: URL, cacheDir: URL) throws -> URL {
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let dest = cachedImage(blob.lastPathComponent, cacheDir: cacheDir)
        if !FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.copyItem(at: blob, to: dest) }
        else { try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: dest.path) } // rinvia `prune`
        return dest
    }

    public static func cachedImage(_ blobName: String, cacheDir: URL) -> URL {
        cacheDir.appendingPathComponent("trove-" + blobName)
    }

    /// Le copie per i terminali servono solo il tempo dell'incolla: dopo `maxAge` si cancellano.
    public static func prune(cacheDir: URL, maxAge: TimeInterval = 86400, now: Date = Date()) {
        let fm = FileManager.default
        for f in (try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
            let m = (try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(m) > maxAge { try? fm.removeItem(at: f) }
        }
    }
}
