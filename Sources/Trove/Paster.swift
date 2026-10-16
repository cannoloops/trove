import AppKit
import ApplicationServices
import TroveCore

/// Scrive un elemento sul pasteboard e simula ⌘V nell'app attiva.
@MainActor
enum Paster {
    static func write(_ item: ClipItem, plain: Bool, store: Store) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .image:
            if let blob = item.blobPath, let data = try? Data(contentsOf: store.blobsDir.appendingPathComponent(blob)) {
                pb.setData(data, forType: .png)
                if let tiff = NSImage(data: data)?.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
            }
        case .file:
            if plain { pb.setString(item.filePaths.joined(separator: "\n"), forType: .string) }
            else { pb.writeObjects(item.filePaths.map { URL(fileURLWithPath: $0) as NSURL }) }
        default:
            pb.setString(item.text, forType: .string)
            guard !plain else { break }
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
