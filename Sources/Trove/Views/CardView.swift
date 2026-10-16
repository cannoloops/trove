import AppKit
import SwiftUI
import TroveCore

struct CardView: View {
    let item: ClipItem
    let index: Int
    let selected: Bool
    let store: Store

    var body: some View {
        VStack(spacing: 0) {
            header
            ItemBody(item: item, store: store, compact: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
            footer
        }
        .frame(width: 236, height: 248)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.trove : .white.opacity(0.08), lineWidth: selected ? 3 : 1))
        .scaleEffect(selected ? 1.0 : 0.97)
        .shadow(color: .black.opacity(selected ? 0.35 : 0.15), radius: selected ? 10 : 4, y: 3)
        .animation(.easeOut(duration: 0.12), value: selected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kind.label) da \(item.sourceApp ?? "app sconosciuta"): \(item.title ?? String(item.text.prefix(80)))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.kind.label).font(.system(size: 13, weight: .semibold))
                Text(item.createdAt.formatted(.relative(presentation: .named))).font(.system(size: 11)).opacity(0.8)
            }
            Spacer()
            if let icon = AppIcons.icon(for: item.sourceBundle) {
                Image(nsImage: icon).resizable().frame(width: 30, height: 30)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(AppIcons.tint(for: item.sourceBundle ?? item.sourceApp))
    }

    private var footer: some View {
        HStack {
            Text(detail).lineLimit(1)
            Spacer()
            if index < 9 { Text("⌘\(index + 1)") }
        }
        .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
        .padding(.horizontal, 10).padding(.bottom, 8)
    }

    private var detail: String {
        switch item.kind {
        case .image: item.text
        case .file: item.filePaths.count == 1 ? "1 file" : "\(item.filePaths.count) file"
        case .link: URL(string: item.text.trimmingCharacters(in: .whitespacesAndNewlines))?.host ?? ""
        case .color: item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        default: "\(item.text.count) caratteri"
        }
    }
}

/// Contenuto di un elemento, usato sia nella card sia nell'anteprima grande.
struct ItemBody: View {
    let item: ClipItem
    let store: Store
    let compact: Bool

    var body: some View {
        switch item.kind {
        case .image:
            ThumbnailView(url: item.blobPath.map { store.blobsDir.appendingPathComponent($0) }, maxPixel: compact ? 520 : 1600)
        case .color:
            let c = Classifier.rgb(fromColorText: item.text) ?? (0, 0, 0)
            VStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8).fill(Color(red: c.r, green: c.g, blue: c.b))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.15)))
                Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines)).font(.system(size: 14, weight: .medium, design: .monospaced))
            }
        case .link:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "globe").font(.system(size: 26)).foregroundStyle(Color.trove)
                if let t = item.title { Text(t).font(.system(size: 14, weight: .semibold)).lineLimit(compact ? 3 : nil) }
                Text(item.text).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(compact ? 4 : nil)
            }
        case .file:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(item.filePaths.prefix(compact ? 4 : 50), id: \.self) { p in
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: p)).resizable().frame(width: 28, height: 28)
                        Text((p as NSString).lastPathComponent).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                    }
                }
            }
        case .richText:
            if let rtf = item.rtf, let ns = NSAttributedString(rtf: rtf, documentAttributes: nil),
               let a = try? AttributedString(ns.attributedSubstring(from: NSRange(location: 0, length: min(ns.length, compact ? 600 : 20000))), including: \.appKit) {
                textBlock(Text(a))
            } else { textBlock(Text(item.text)) }
        case .text:
            textBlock(Text(String(item.text.prefix(compact ? 600 : 20000)))
                .font(.system(size: 12.5, design: Self.looksLikeCode(item.text) ? .monospaced : .default)))
        }
    }

    @ViewBuilder private func textBlock(_ t: Text) -> some View {
        if compact { t.font(.system(size: 12.5)).lineLimit(11) } else { ScrollView { t.textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) } }
    }

    static func looksLikeCode(_ s: String) -> Bool {
        let hits = ["{", "}", ";", "=>", "func ", "def ", "import ", "</", "$ ", "--"].filter { s.contains($0) }.count
        return hits >= 2
    }
}

struct ThumbnailView: View {
    let url: URL?
    let maxPixel: Int
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().aspectRatio(contentMode: .fit) }
            else { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) }
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

    /// Colore stabile per app (come le testate colorate di Paste).
    static func tint(for key: String?) -> Color {
        guard let key else { return Color(hue: 0, saturation: 0, brightness: 0.35) }
        let h = key.unicodeScalars.reduce(UInt32(5381)) { ($0 &<< 5) &+ $0 &+ $1.value }
        return Color(hue: Double(h % 360) / 360, saturation: 0.55, brightness: 0.62)
    }
}
