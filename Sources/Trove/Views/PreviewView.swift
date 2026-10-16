import SwiftUI
import TroveCore

/// Anteprima grande (spazio), con testo OCR e tag semantici quando presenti.
struct PreviewView: View {
    let item: ClipItem
    let store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let icon = AppIcons.icon(for: item.sourceBundle) { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                Text(item.kind.label).font(Theme.ui(13, .semibold))
                if let app = item.sourceApp { Text("da \(app)").font(Theme.ui(13)).foregroundStyle(.secondary) }
                Spacer()
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened)).font(Theme.ui(12)).foregroundStyle(.secondary).monospacedDigit()
            }
            ItemBody(item: item, store: store, compact: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if let ocr = item.ocr, !ocr.isEmpty {
                Divider()
                Text("Testo riconosciuto").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ScrollView { Text(ocr).font(Theme.ui(12)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 90)
            }
            if let tags = item.tags {
                Text(tags).font(.caption).foregroundStyle(.tertiary).lineLimit(2)
            }
            HStack(spacing: 14) {
                ForEach([("↩", "incolla"), ("⇧↩", "testo semplice"), ("⌥↩", "per agenti, senza segreti"), ("esc", "chiudi")], id: \.0) { k, v in
                    HStack(spacing: 5) { KeyCap(k); Text(v) }
                }
            }
            .font(Theme.ui(11)).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 640, height: 460)
    }
}
