import AppKit
import SwiftUI
import TroveCore

extension Color {
    static let trove = Color(red: 0.91, green: 0.71, blue: 0.29)      // oro: selezione, accenti
    static let ink = Color(red: 0.07, green: 0.08, blue: 0.11)        // fondo pannello
    static let cardInk = Color(red: 0.11, green: 0.12, blue: 0.16)    // superficie card
    static let paper = Color(red: 0.93, green: 0.93, blue: 0.95)      // testo principale
    static let codeString = Color(red: 0.49, green: 0.80, blue: 0.75)
    static let codeComment = Color(red: 0.45, green: 0.48, blue: 0.56)
}

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
        .background(Color.cardInk)
        .overlay(alignment: .top) { AppIcons.tint(for: item.sourceBundle ?? item.sourceApp).frame(height: 3) }
        .overlay(alignment: .topTrailing) {
            if index < 9 { KeyCap("⌘\(index + 1)").padding(8).opacity(selected ? 1 : 0.0) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(selected ? Color.trove : .white.opacity(0.07), lineWidth: selected ? 2.5 : 1))
        .shadow(color: selected ? Color.trove.opacity(0.35) : .black.opacity(0.25), radius: selected ? 14 : 5, y: selected ? 0 : 3)
        .offset(y: selected ? -4 : 0)
        .animation(.spring(duration: 0.18), value: selected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kind.label) da \(item.sourceApp ?? "app sconosciuta"): \(item.title ?? String(item.text.prefix(80)))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Etichetta in basso: da dove viene e quando, come il cartellino di un reperto.
    private var label: some View {
        HStack(spacing: 7) {
            if let icon = AppIcons.icon(for: item.sourceBundle) {
                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(item.sourceApp ?? "Sconosciuta").font(Theme.ui(11, .semibold)).foregroundStyle(Color.paper)
                Text(item.createdAt.formatted(.relative(presentation: .named))).font(Theme.ui(10)).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 4)
            let f = Flags.of(item)
            if f.secret { Image(systemName: "lock.fill").foregroundStyle(Color.trove).help("Contiene segreti: ⌥↩ li sostituisce con segnaposto") }
            if f.dirty { Image(systemName: "wand.and.sparkles").foregroundStyle(Color.trove).help("Testo da terminale: ⌥↩ lo incolla pulito") }
            Text(detail).font(Theme.ui(10)).foregroundStyle(.secondary).lineLimit(1).monospacedDigit()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.black.opacity(0.22))
    }

    private var detail: String {
        switch item.kind {
        case .image: item.text
        case .file: item.filePaths.count == 1 ? "1 file" : "\(item.filePaths.count) file"
        case .link: "link"
        case .color: "colore"
        default:
            CodeStyle.language(of: item.text).map { _ in "\(item.text.split(separator: "\n", omittingEmptySubsequences: false).count) righe" }
                ?? "\(item.text.count) car."
        }
    }
}

/// Segreti e testo "sporco" da terminale, calcolati una volta per elemento.
enum Flags {
    nonisolated(unsafe) private static var cache: [Int64: (secret: Bool, dirty: Bool)] = [:]

    static func of(_ it: ClipItem) -> (secret: Bool, dirty: Bool) {
        guard [.text, .richText, .link].contains(it.kind) else { return (false, false) }
        if let c = cache[it.id] { return c }
        let c = (Secrets.contains(it.text), Cleaner.needsCleaning(String(it.text.prefix(20000))))
        cache[it.id] = c
        return c
    }
}

struct KeyCap: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(Theme.ui(10, .semibold)).foregroundStyle(Color.paper)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.2)))
    }
}

/// Il contenuto dà forma alla card: codice come editor, prosa in serif, link come dominio, colore e immagini a tutta card.
struct ItemBody: View {
    let item: ClipItem
    let store: Store
    let compact: Bool

    /// Nella card: testo da terminale già pulito e segreti mascherati. L'anteprima mostra l'originale.
    private var shown: String {
        guard compact else { return item.text }
        let f = Flags.of(item)
        var t = f.dirty ? Cleaner.clean(String(item.text.prefix(4000))) : item.text
        if f.secret { t = Secrets.redact(String(t.prefix(4000))).text }
        return t
    }

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
            ThumbnailView(url: item.blobPath.map { store.blobsDir.appendingPathComponent($0) }, maxPixel: compact ? 520 : 1600, fill: compact)
            if compact, let ocr = item.ocr, !ocr.isEmpty {
                Label(ocr.replacingOccurrences(of: "\n", with: " "), systemImage: "text.viewfinder")
                    .font(Theme.ui(10, .medium)).lineLimit(1)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(.black.opacity(0.6), in: Capsule()).foregroundStyle(Color.paper)
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
            Text(host).font(Theme.ui(compact ? 20 : 30, .heavy)).foregroundStyle(Color.trove)
                .lineLimit(2).minimumScaleFactor(0.6)
            if let t = item.title {
                Text(t).font(Theme.prose(13, .medium)).foregroundStyle(Color.paper).lineLimit(compact ? 3 : nil)
            }
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
                        Text((p as NSString).lastPathComponent).font(Theme.ui(12, .medium)).foregroundStyle(Color.paper)
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
        if let rtf = item.rtf, let ns = NSAttributedString(rtf: rtf, documentAttributes: nil),
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
                    Text(first).font(Theme.prose(14, .medium)).foregroundStyle(Color.paper).lineLimit(6)
                        .padding(.trailing, 26) // spazio per il badge ⌘N
                    if lines.count > 1 { Text(lines[1]).font(Theme.prose(12)).foregroundStyle(.secondary).lineLimit(5) }
                } else {
                    t.font(Theme.prose(13)).foregroundStyle(Color.paper).lineLimit(10)
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
                Text(lang).font(Theme.ui(10, .bold)).foregroundStyle(Color.ink)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Color.trove, in: RoundedRectangle(cornerRadius: 4))
                Spacer()
            }
            .padding(.bottom, 6)
            ScrollView(compact ? [] : [.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { n, line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(n + 1)").foregroundStyle(Color.codeComment.opacity(0.7)).frame(width: 16, alignment: .trailing)
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
        .background(Color.black.opacity(0.25))
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
            a.foregroundColor = keywords.contains(token.lowercased()) && (lang != "sql" || true) ? .trove : .paper
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
                flush(); var a = AttributedString(String(ch)); a.foregroundColor = Color.paper.opacity(0.75); out += a
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

    /// Colore stabile per app: filo colorato in cima alla card.
    static func tint(for key: String?) -> Color {
        guard let key else { return Color(white: 0.4) }
        let h = key.unicodeScalars.reduce(UInt32(5381)) { ($0 &<< 5) &+ $0 &+ $1.value }
        return Color(hue: Double(h % 360) / 360, saturation: 0.6, brightness: 0.85)
    }
}
