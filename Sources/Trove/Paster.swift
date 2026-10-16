import AppKit
import ApplicationServices
import TroveCore

enum PasteMode { case normal, plain, agent }

/// Scrive un elemento sul pasteboard e simula ⌘V nell'app attiva.
@MainActor
enum Paster {
    static let terminals: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable", "com.github.wez.wezterm",
        "net.kovidgoyal.kitty", "org.alacritty", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "com.exafunction.windsurf", "dev.zed.Zed",
    ]
    static let aiApps: Set<String> = [
        "com.openai.chat", "com.openai.codex", "com.anthropic.claudefordesktop", "ai.perplexity.mac", "ai.perplexity.macv3", "com.google.GeminiMacOS",
    ]
    static let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("io.trove.app/paste")

    static var redactForAI: Bool { UserDefaults.standard.object(forKey: "redactForAI") as? Bool ?? true }

    /// `target`: bundle id dell'app che riceverà l'incolla (nil = sconosciuta, es. ⌘C).
    static func write(_ item: ClipItem, mode: PasteMode, target: String?, store: Store) {
        let pb = NSPasteboard.general
        pb.clearContents()
        let toTerminal = target.map(terminals.contains) ?? false
        let toAI = toTerminal || (target.map(aiApps.contains) ?? false)

        switch item.kind {
        case .image:
            guard let blob = item.blobPath.map({ store.blobsDir.appendingPathComponent($0) }) else { return }
            // agenti e terminali leggono file, non immagini dal pasteboard
            if mode == .agent || toTerminal, let path = try? AgentPaste.imagePath(blob: blob, cacheDir: cacheDir) {
                pb.setString(path.path, forType: .string)
            } else if let data = try? Data(contentsOf: blob) {
                pb.setData(data, forType: .png)
                if let tiff = NSImage(data: data)?.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
            }
        case .file:
            if mode == .normal && !toTerminal { pb.writeObjects(item.filePaths.map { URL(fileURLWithPath: $0) as NSURL }) }
            else { pb.setString(item.filePaths.joined(separator: "\n"), forType: .string) }
        default:
            if mode == .agent { pb.setString(AgentPaste.text(item.text), forType: .string); break }
            if toAI, redactForAI, Secrets.contains(item.text) { pb.setString(Secrets.redact(item.text).text, forType: .string); break }
            pb.setString(item.text, forType: .string)
            guard mode == .normal else { break }
            if let rtf = item.rtf { pb.setData(rtf, forType: .rtf) }
            if let html = item.html { pb.setString(html, forType: .html) }
            if item.kind == .link { pb.setString(item.text.trimmingCharacters(in: .whitespacesAndNewlines), forType: .URL) }
        }
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func promptForAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// ⌘V verso l'app in primo piano.
    static func sendPaste() {
        guard isTrusted else { promptForAccessibility(); return }
        let src = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: down) // 9 = V
            e?.flags = .maskCommand
            e?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
