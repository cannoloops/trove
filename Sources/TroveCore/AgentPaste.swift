import Foundation

/// "Incolla per agenti": testo pulito e senza segreti, immagini come percorso file.
public enum AgentPaste {
    public static func text(_ s: String) -> String { Secrets.redact(Cleaner.clean(s)).text }

    /// Copia il blob in una cartella senza spazi nel percorso (comoda da incollare in un terminale).
    public static func imagePath(blob: URL, cacheDir: URL) throws -> URL {
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let dest = cacheDir.appendingPathComponent("trove-" + blob.lastPathComponent)
        if !FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.copyItem(at: blob, to: dest) }
        return dest
    }
}
