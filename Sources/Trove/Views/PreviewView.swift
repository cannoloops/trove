import SwiftUI
import TroveCore

/// Anteprima grande (spazio), con testo OCR e tag semantici quando presenti.
struct PreviewView: View {
    let item: ClipItem
    let store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.kind.label).font(.headline)
                if let app = item.sourceApp { Text("da \(app)").foregroundStyle(.secondary) }
                Spacer()
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
            }
            ItemBody(item: item, store: store, compact: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if let ocr = item.ocr, !ocr.isEmpty {
                Divider()
                Text("Testo riconosciuto").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                ScrollView { Text(ocr).font(.system(size: 12)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 90)
            }
            if let tags = item.tags {
                Text(tags).font(.caption).foregroundStyle(.tertiary).lineLimit(2)
            }
            Text("↩ incolla   ⇧↩ incolla come testo semplice   esc chiudi").font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 640, height: 460)
    }
}
