import AppKit
import SwiftUI
import TroveCore

/// `Trove --snapshot <dir>`: renderizza la barra con dati d'esempio in PNG, fuori schermo.
// ponytail: strumento di sviluppo per rivedere la UI senza screen recording né tasti simulati.
@MainActor
enum Snapshot {
    static func run(_ dir: URL) {
        let data = FileManager.default.temporaryDirectory.appendingPathComponent("trove-snap-\(UUID().uuidString)")
        let store = try! Store(directory: data)
        seed(store)
        let model = AppModel(store: store)
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        let actions = PanelActions(paste: { _, _ in }, copy: { _ in }, settings: {})
        for (mode, look) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
            func save(_ view: some View, _ size: NSSize, _ name: String) {
                Snapshot.save(view, size: size, appearance: look, to: dir.appendingPathComponent("\(name)-\(mode).png"))
            }
            model.query = ""
            model.selection = 1
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            save(PanelView(model: model, actions: actions), NSSize(width: 1500, height: PanelController.height), "panel")
            model.query = "dentista"
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            save(PanelView(model: model, actions: actions), NSSize(width: 1500, height: PanelController.height), "panel-search")
            model.query = "zzzqqq"
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            save(PanelView(model: model, actions: actions), NSSize(width: 1500, height: PanelController.height), "panel-empty")
            if let it = store.all().first(where: { $0.kind == .image }) {
                save(PreviewView(item: it, store: store), NSSize(width: 640, height: 460), "preview")
            }
            save(SettingsView(s: SettingsModel(), app: model), NSSize(width: 560, height: 820), "settings")
        }
    }

    static func save(_ view: some View, size: NSSize, appearance: NSAppearance.Name, to url: URL) {
        // fondo neutro tipo scrivania: il vetro vero non si renderizza fuori schermo
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor)))
        host.frame = NSRect(origin: .zero, size: size)
        let win = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.appearance = NSAppearance(named: appearance)
        win.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    static func seed(_ s: Store) {
        let now = Date()
        func add(_ kind: ClipKind, _ text: String, app: String, bundle: String, ago: TimeInterval, title: String? = nil,
                 rtf: Data? = nil, blob: String? = nil, files: [String] = [], tags: String? = nil, ocr: String? = nil) {
            var it = ClipItem(kind: kind, text: text, rtf: rtf, blobPath: blob, filePaths: files, sourceApp: app, sourceBundle: bundle,
                              createdAt: now.addingTimeInterval(-ago), hash: UUID().uuidString)
            it.title = title
            let id = try! s.insert(it)
            s.update(ocr: ocr, title: title, tags: tags, embedding: nil, lang: nil, for: id)
        }
        let img = NSImage(size: NSSize(width: 800, height: 500), flipped: false) { r in
            NSGradient(colors: [.systemTeal, .systemIndigo])!.draw(in: r, angle: 35)
            ("Bolletta Enel · scadenza 12 novembre" as NSString).draw(at: NSPoint(x: 40, y: 220),
                withAttributes: [.font: NSFont.boldSystemFont(ofSize: 38), .foregroundColor: NSColor.white])
            return true
        }
        let png = NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        try! png.write(to: s.blobsDir.appendingPathComponent("snap.png"))
        let rich = NSAttributedString(string: "Nota importante: consegna entro venerdì, poi revisione con il cliente.",
                                      attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
        add(.text, "Ricordati la visita odontoiatrica martedì alle 15, portare la tessera sanitaria.", app: "Notes", bundle: "com.apple.Notes", ago: 30, tags: "dentista, dentist")
        add(.text, "func greet(_ name: String) -> String {\n    let msg = \"Ciao, \\(name)!\"\n    return msg\n}\n\nprint(greet(\"World\"))", app: "Xcode", bundle: "com.apple.dt.Xcode", ago: 300)
        add(.link, "https://developer.apple.com/documentation/foundationmodels", app: "Safari", bundle: "com.apple.Safari", ago: 1800, title: "Foundation Models | Apple Developer Documentation")
        add(.image, "800×500", app: "Screenshot", bundle: "com.apple.screenshot.launcher", ago: 3600, blob: "snap.png", ocr: "Bolletta Enel scadenza 12 novembre")
        add(.color, "#E8B44A", app: "Figma", bundle: "com.figma.Desktop", ago: 7200)
        add(.richText, rich.string, app: "Mail", bundle: "com.apple.mail", ago: 90000,
            rtf: try! rich.data(from: NSRange(location: 0, length: rich.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]))
        add(.file, "Contratto.pdf\nPreventivo.xlsx", app: "Finder", bundle: "com.apple.finder", ago: 100000,
            files: ["/System/Library/CoreServices/Finder.app", "/Applications/Safari.app"])
        add(.text, "\u{1B}[32m⏺\u{1B}[0m Ho aggiornato Store.swift e aggiunto i test per il ripristino: ora la history locale resta intatta anche se il   \n  backup è corrotto.   \n  ⎿  Updated Sources/TroveCore/Store.swift", app: "Terminal", bundle: "com.apple.Terminal", ago: 60)
        add(.text, "OPENAI_API_KEY=sk-proj-abcDEF1234567890abcdef1234567890XYZ\nDATABASE_URL=postgres://admin:s3cr3t@db.local/app", app: "Visual Studio Code", bundle: "com.microsoft.VSCode", ago: 120)
        add(.text, "git commit -m \"fix: ripristino sicuro\" && git push origin trove-v1", app: "Terminal", bundle: "com.apple.Terminal", ago: 200000)
    }
}
