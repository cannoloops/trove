import AppKit
import SwiftUI
import TroveCore

struct CardView: View {
    let item: ClipItem
    let index: Int
    let selected: Bool
    let store: Store
    static let size = CGSize(width: 228, height: 236)

    var body: some View {
        VStack(spacing: 0) {
            ItemBody(item: item, store: store, compact: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            label
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color.cardSurface)
        .overlay(alignment: .topTrailing) {
            if index < 9 { KeyCap("⌘\(index + 1)").padding(8).opacity(selected ? 1 : 0) }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).strokeBorder(Color.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
        // anello di selezione staccato di 3pt, raggio concentrico alla card
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius + 3, style: .continuous)
            .strokeBorder(Color.trove, lineWidth: 2).padding(-3).opacity(selected ? 1 : 0))
        .animation(.easeOut(duration: 0.12), value: selected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kind.label) da \(item.sourceApp ?? String(localized: "app sconosciuta")): \(item.title ?? String(item.text.prefix(80)))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Etichetta in basso: da dove viene e quando, come il cartellino di un reperto.
    private var label: some View {
        HStack(spacing: 7) {
            if let icon = AppIcons.icon(for: item.sourceBundle) {
                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(item.sourceApp ?? String(localized: "Sconosciuta")).font(Theme.ui(11, .semibold)).foregroundStyle(.primary)
                Text(item.createdAt.formatted(.relative(presentation: .named))).font(Theme.ui(10)).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 4)
            let f = Flags.of(item)
            Group {
                if f.secret { Image(systemName: "lock.fill").help("Contiene segreti: ⌥↩ li sostituisce con segnaposto") }
                if f.dirty { Image(systemName: "terminal").help("Testo da terminale: ⌥↩ lo incolla pulito") }
            }
            .font(Theme.ui(10, .semibold)).foregroundStyle(.secondary)
            Text(detail).font(Theme.ui(10)).foregroundStyle(.secondary).lineLimit(1).monospacedDigit()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 0.5) }
    }

    private var detail: String {
        switch item.kind {
        case .image: item.text
        case .file: item.filePaths.count == 1 ? String(localized: "1 file") : String(localized: "\(item.filePaths.count) file")
        case .link: String(localized: "link")
        case .color: String(localized: "colore")
        default:
            CodeStyle.language(of: item.text).map { _ in String(localized: "\(item.text.split(separator: "\n", omittingEmptySubsequences: false).count) righe") }
                ?? String(localized: "\(item.text.count) car.")
        }
    }
}

/// Segreti, testo "sporco" da terminale e testo da mostrare nella card, calcolati una volta per elemento.
@MainActor
enum Flags {
    struct Info { var secret: Bool; var dirty: Bool; var shown: String }
    // ponytail: cache senza eviction, chiave id+hash (gli id SQLite possono essere riusati); basta per qualche decina di migliaia di card
    private static var cache: [String: Info] = [:]

    static func of(_ it: ClipItem) -> Info {
        guard [.text, .richText, .link].contains(it.kind) else { return Info(secret: false, dirty: false, shown: it.text) }
        let key = "\(it.id)#\(it.hash)"
        if let c = cache[key] { return c }
        let head = String(it.text.prefix(20000))
        let term = it.sourceBundle.map(Paster.terminals.contains) ?? false
        let secret = Secrets.contains(head)
        let dirty = it.kind == .text && Cleaner.needsCleaning(head, fromTerminal: term)
        var shown = dirty ? Cleaner.clean(String(head.prefix(4000)), fromTerminal: term) : head
        if secret { shown = Secrets.redact(shown).text }
        let c = Info(secret: secret, dirty: dirty, shown: shown)
        cache[key] = c
        return c
    }
}

struct KeyCap: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(Theme.ui(10, .medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.chipRadius, style: .continuous).strokeBorder(Color.hairline, lineWidth: 0.5))
    }
}

/// Il contenuto dà forma alla card: codice come editor, prosa in serif, link come dominio, colore e immagini a tutta card.
struct ItemBody: View {
    let item: ClipItem
    let store: Store
    let compact: Bool

    /// Nella card: testo da terminale già pulito e segreti mascherati. L'anteprima mostra l'originale.
    private var shown: String { compact ? Flags.of(item).shown : item.text }

    var body: some View {
        switch item.kind {
        case .image: image
        case .color: color
        case .link: link
        case .file: files
        case .richText: richText
        case .text:
            if let lang = CodeStyle.language(of: shown) { code(lang) } else { prose(Text(String(shown.prefix(compact ? 500 : 20000)))) }
        }
    }

    private var image: some View {
        ZStack(alignment: .bottomLeading) {
            ThumbnailView(url: item.blobPath.flatMap(store.blobURL), maxPixel: compact ? 520 : 1600, fill: compact)
            if compact, let ocr = item.ocr, !ocr.isEmpty {
                Label(ocr.replacingOccurrences(of: "\n", with: " "), systemImage: "text.viewfinder")
                    .font(Theme.ui(10, .medium)).lineLimit(1)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(.black.opacity(0.6), in: Capsule()).foregroundStyle(.white)
                    .padding(8)
            }
        }
    }

    private var color: some View {
        let c = Classifier.rgb(fromColorText: item.text) ?? (0, 0, 0)
        let light = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b > 0.6
        return ZStack(alignment: .bottomLeading) {
            Color(red: c.r, green: c.g, blue: c.b)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
                    .font(Theme.mono(compact ? 24 : 40, .bold))
                Text("rgb \(Int(c.r * 255)) \(Int(c.g * 255)) \(Int(c.b * 255))").font(Theme.mono(11)).opacity(0.75)
            }
            .foregroundStyle(light ? Color.black.opacity(0.85) : .white)
            .padding(12)
        }
    }

    private var link: some View {
        let url = URL(string: item.text.trimmingCharacters(in: .whitespacesAndNewlines))
        let host = (url?.host ?? item.text).replacingOccurrences(of: "www.", with: "")
        return VStack(alignment: .leading, spacing: 8) {
            Label(host, systemImage: "link").font(Theme.ui(compact ? 12 : 14, .semibold)).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            // senza titolo è il dominio a fare da titolo
            Text(item.title ?? host).font(Theme.prose(compact ? 15 : 20, .semibold)).foregroundStyle(.primary)
                .lineLimit(compact ? 4 : nil).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Text(url?.path.isEmpty == false ? url!.path : item.text).font(Theme.mono(10))
                .foregroundStyle(.secondary).lineLimit(compact ? 2 : nil).truncationMode(.middle)
        }
        .padding(12)
    }

    private var files: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(item.filePaths.prefix(compact ? 3 : 50), id: \.self) { p in
                HStack(spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: p)).resizable().frame(width: compact ? 34 : 28, height: compact ? 34 : 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text((p as NSString).lastPathComponent).font(Theme.ui(12, .medium)).foregroundStyle(.primary)
                        Text((p as NSString).deletingLastPathComponent).font(Theme.mono(9.5)).foregroundStyle(.secondary)
                    }
                    .lineLimit(1).truncationMode(.middle)
                }
            }
            if compact, item.filePaths.count > 3 { Text("+ altri \(item.filePaths.count - 3)").font(.caption).foregroundStyle(.secondary) }
        }
        .padding(12)
    }

    @ViewBuilder private var richText: some View {
        if compact, Flags.of(item).secret { prose(Text(shown)) } // niente segreti in chiaro nella card
        else if let rtf = item.rtf, let ns = NSAttributedString(rtf: rtf, documentAttributes: nil),
           let a = try? AttributedString(ns.attributedSubstring(from: NSRange(location: 0, length: min(ns.length, compact ? 500 : 20000))), including: \.appKit) {
            prose(Text(a), styled: true)
        } else { prose(Text(item.text)) }
    }

    /// Prosa in serif: la prima riga fa da titolo.
    @ViewBuilder private func prose(_ t: Text, styled: Bool = false) -> some View {
        if compact {
            let lines = shown.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            VStack(alignment: .leading, spacing: 6) {
                if !styled, let first = lines.first {
                    Text(first).font(Theme.prose(14, .medium)).foregroundStyle(.primary).lineLimit(6)
                        .padding(.trailing, 26) // spazio per il badge ⌘N
                    if lines.count > 1 { Text(lines[1]).font(Theme.prose(12)).foregroundStyle(.secondary).lineLimit(5) }
                } else {
                    t.font(Theme.prose(13)).foregroundStyle(.primary).lineLimit(10)
                }
            }
            .padding(12)
        } else {
            ScrollView { t.font(Theme.prose(15)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
        }
    }

    /// Codice come in un editor: numeri di riga, linguaggio, evidenziazione leggera.
    private func code(_ lang: String) -> some View {
        let lines = shown.split(separator: "\n", omittingEmptySubsequences: false).prefix(compact ? 11 : 400)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(lang).font(Theme.mono(10, .medium)).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.bottom, 6)
            ScrollView(compact ? [] : [.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { n, line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(n + 1)").foregroundStyle(.tertiary).frame(width: 16, alignment: .trailing)
                            Text(CodeStyle.highlight(String(line), lang: lang)).lineLimit(1)
                        }
                    }
                }
                .font(Theme.mono(compact ? 10.5 : 12.5))
                .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.codeSurface)
    }
}

enum CodeStyle {
    /// Riconosce i linguaggi più comuni negli appunti di chi programma; nil = prosa.
    static func language(of s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > 3 else { return nil }
        let firstLine = t.split(separator: "\n").first.map(String.init) ?? t
        if ["$ ", "git ", "npm ", "brew ", "cd ", "sudo ", "swift ", "docker ", "kubectl ", "curl ", "pip ", "uvx ", "./"].contains(where: firstLine.hasPrefix)
            || (firstLine.contains(" && ") && !firstLine.contains(". ")) { return "shell" }
        if (t.hasPrefix("{") && t.hasSuffix("}") || t.hasPrefix("[") && t.hasSuffix("]")) && t.contains("\":") { return "json" }
        if t.range(of: #"(?i)^\s*(select|insert|update|delete|create table)\b"#, options: .regularExpression) != nil { return "sql" }
        if t.contains("func ") && (t.contains("->") || t.contains("let ") || t.contains("{")) { return "swift" }
        if t.range(of: #"(?m)^\s*(def |class |import |from \w+ import)"#, options: .regularExpression) != nil && t.contains(":") { return "python" }
        if t.contains("=>") || t.contains("const ") || t.contains("function ") { return "js" }
        if t.hasPrefix("<") && t.contains("</") { return "html" }
        let signals = ["{", "}", ";", "()", "==", "//", "#include", "public ", "return "].filter { t.contains($0) }.count
        return signals >= 3 ? "code" : nil
    }

    static let keywords: Set<String> = ["func", "let", "var", "return", "if", "else", "for", "in", "while", "import", "def", "class",
        "struct", "enum", "const", "function", "public", "private", "static", "async", "await", "try", "from", "select", "from",
        "where", "insert", "update", "delete", "git", "npm", "brew", "cd", "sudo", "echo", "export", "true", "false", "nil", "null", "None"]

    static func highlight(_ line: String, lang: String) -> AttributedString {
        var out = AttributedString()
        if let r = line.range(of: lang == "python" || lang == "shell" ? "#" : "//"), !line[..<r.lowerBound].contains("\"") {
            out += colored(String(line[..<r.lowerBound]), lang: lang)
            var c = AttributedString(String(line[r.lowerBound...])); c.foregroundColor = .codeComment
            return out + c
        }
        return colored(line, lang: lang)
    }

    private static func colored(_ s: String, lang: String) -> AttributedString {
        var out = AttributedString()
        var token = "", inString: Character?
        func flush() {
            guard !token.isEmpty else { return }
            var a = AttributedString(token)
            a.foregroundColor = keywords.contains(token.lowercased()) ? .codeKeyword : .codeText
            out += a; token = ""
        }
        for ch in s {
            if let q = inString {
                token.append(ch)
                if ch == q { var a = AttributedString(token); a.foregroundColor = .codeString; out += a; token = ""; inString = nil }
            } else if ch == "\"" || ch == "'" {
                flush(); token.append(ch); inString = ch
            } else if ch.isLetter || ch.isNumber || ch == "_" {
                token.append(ch)
            } else {
                flush(); var a = AttributedString(String(ch)); a.foregroundColor = Color.codeText.opacity(0.75); out += a
            }
        }
        if inString != nil { var a = AttributedString(token); a.foregroundColor = .codeString; out += a } else { flush() }
        return out
    }
}

struct ThumbnailView: View {
    let url: URL?
    let maxPixel: Int
    var fill = false
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                if fill {
                    Color.clear.overlay(Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)).clipped()
                } else {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                }
            } else { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url) { image = await Thumbnails.load(url, maxPixel: maxPixel) }
    }
}

enum Thumbnails {
    nonisolated(unsafe) private static let cache = NSCache<NSString, NSImage>()

    static func load(_ url: URL?, maxPixel: Int) async -> NSImage? {
        guard let url else { return nil }
        let key = "\(url.path)#\(maxPixel)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let img = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceThumbnailMaxPixelSize: maxPixel, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary)
            else { return nil }
            return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }.value
        if let img { cache.setObject(img, forKey: key) }
        return img
    }
}

enum AppIcons {
    nonisolated(unsafe) private static var icons: [String: NSImage] = [:]

    @MainActor static func icon(for bundle: String?) -> NSImage? {
        guard let bundle else { return nil }
        if let i = icons[bundle] { return i }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else { return nil }
        let i = NSWorkspace.shared.icon(forFile: url.path)
        icons[bundle] = i
        return i
    }
}
