import AppKit
import ApplicationServices
import TroveCore

enum PasteMode { case normal, plain, agent }

/// Scrive un elemento sul pasteboard e simula ⌘V nell'app attiva.
@MainActor
enum Paster {
    /// Solo terminali veri: negli editor (VS Code, Cursor, Zed…) si incolla codice, immagini e file così come sono.
    static let terminals: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable", "com.github.wez.wezterm",
        "net.kovidgoyal.kitty", "org.alacritty",
    ]
    static let aiApps: Set<String> = [
        "com.openai.chat", "com.openai.codex", "com.anthropic.claudefordesktop", "ai.perplexity.mac", "ai.perplexity.macv3", "com.google.GeminiMacOS",
    ]
    static let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("io.github.cannoloops.trove/paste")

    static var redactForAI: Bool { UserDefaults.standard.object(forKey: "redactForAI") as? Bool ?? true }

    /// `target`: bundle id dell'app che riceverà l'incolla (nil = sconosciuta, es. ⌘C).
    /// Ritorna quanti segreti sono stati nascosti automaticamente (per avvisare l'utente) e se il testo
    /// superava `Secrets.limit`, quindi è stato analizzato solo in parte.
    @discardableResult
    static func write(_ item: ClipItem, mode: PasteMode, target: String?, store: Store) -> (hidden: Int, partial: Bool) {
        // ⇧↩ su un'immagine: solo il testo riconosciuto (OCR), con le stesse regole del testo
        if item.kind == .image, mode == .plain {
            var t = item; t.kind = .text; t.text = item.ocr ?? ""
            return write(t, mode: mode, target: target, store: store)
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        let toTerminal = target.map(terminals.contains) ?? false
        let toAIChat = target.map(aiApps.contains) ?? false

        switch item.kind {
        case .image:
            guard let blob = item.blobPath.flatMap(store.blobURL) else { return (0, false) }
            // agenti e terminali leggono file, non immagini dal pasteboard
            if mode == .agent || toTerminal, let path = try? AgentPaste.imagePath(blob: blob, cacheDir: cacheDir) {
                pb.setString(path.path, forType: .string)
            } else if let data = try? Data(contentsOf: blob) {
                pb.setData(data, forType: .png)
                if let tiff = NSImage(data: data)?.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
            }
        case .file:
            // i terminali citano da soli i percorsi dei file URL (spazi compresi)
            if mode == .normal { pb.writeObjects(item.filePaths.map { URL(fileURLWithPath: $0) as NSURL }) }
            else { pb.setString(item.filePaths.joined(separator: "\n"), forType: .string) }
        default:
            if mode == .agent {
                let r = AgentPaste.redact(item.text, fromTerminal: item.sourceBundle.map(terminals.contains) ?? false)
                pb.setString(r.text, forType: .string)
                return (r.found.count, r.truncated)
            }
            // nelle chat AI i segreti non partono: segnaposto + avviso. Nei terminali ↩ resta fedele (es. export KEY=…)
            if toAIChat, redactForAI {
                let r = Secrets.redact(item.text)
                if !r.found.isEmpty || r.truncated { pb.setString(r.text, forType: .string); return (r.found.count, r.truncated) }
            }
            pb.setString(item.text, forType: .string)
            guard mode == .normal else { break }
            if let rtf = item.rtf { pb.setData(rtf, forType: .rtf) }
            if let html = item.html { pb.setString(html, forType: .html) }
            if item.kind == .link { pb.setString(item.text.trimmingCharacters(in: .whitespacesAndNewlines), forType: .URL) }
        }
        return (0, false)
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func promptForAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// ⌘V verso l'app in primo piano.
    static func sendPaste() {
        guard isTrusted else { promptForAccessibility(); return }
        PasteGuard.ignoreUntil = Date() + 1
        let src = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: down) // 9 = V
            e?.flags = .maskCommand
            e?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
