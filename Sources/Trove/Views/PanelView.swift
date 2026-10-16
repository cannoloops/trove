import SwiftUI
import TroveCore

struct PanelActions {
    var paste: (ClipItem, Bool) -> Void
    var copy: (ClipItem) -> Void
    var settings: () -> Void
}

extension Color {
    static let trove = Color(red: 0.91, green: 0.71, blue: 0.29) // oro: selezione e accenti
}

struct PanelView: View {
    @ObservedObject var model: AppModel
    let actions: PanelActions
    @FocusState private var searchFocused: Bool

    private let filters: [(String, ClipKind?, String)] = [
        ("Tutto", nil, "square.stack"), ("Testo", .text, "text.alignleft"), ("Rich", .richText, "textformat"),
        ("Link", .link, "link"), ("Immagini", .image, "photo"), ("File", .file, "doc"), ("Colori", .color, "paintpalette"),
    ]

    var body: some View {
        VStack(spacing: 10) {
            topBar
            if model.results.isEmpty { emptyState } else { strip }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .onChange(of: model.openToken) { searchFocused = true }
        .onAppear { searchFocused = true }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: model.semanticActive ? "sparkle.magnifyingglass" : "magnifyingglass")
                    .foregroundStyle(model.semanticActive ? Color.trove : .secondary)
                    .help(model.semanticActive ? "Risultati anche per significato" : "Cerca")
                TextField("Cerca nella history — prova type:image, app:Safari, oggi", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($searchFocused)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            .frame(maxWidth: 520)

            HStack(spacing: 4) {
                ForEach(filters, id: \.0) { name, kind, icon in
                    let on = model.kindFilter == kind
                    Button { model.kindFilter = kind } label: {
                        Label(name, systemImage: icon).labelStyle(.titleAndIcon).font(.system(size: 12, weight: on ? .semibold : .regular))
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(on ? Color.trove.opacity(0.25) : .clear, in: Capsule())
                            .foregroundStyle(on ? Color.trove : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            Text(model.query.isEmpty && model.kindFilter == nil ? "\(model.totalCount) elementi" : "\(model.results.count) risultati")
                .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
            Button(action: actions.settings) { Image(systemName: "gearshape") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Impostazioni (⌘,)")
        }
    }

    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { i, item in
                        CardView(item: item, index: i, selected: i == model.selection, store: model.store)
                            .id(item.id)
                            .onTapGesture(count: 2) { actions.paste(item, false) }
                            .simultaneousGesture(TapGesture().onEnded { model.selection = i })
                            .popover(isPresented: Binding(get: { model.previewing && i == model.selection },
                                                          set: { if !$0 { model.previewing = false } }), arrowEdge: .top) {
                                PreviewView(item: item, store: model.store)
                            }
                            .contextMenu {
                                Button("Incolla") { actions.paste(item, false) }
                                Button("Incolla come testo semplice") { actions.paste(item, true) }
                                Button("Copia") { actions.copy(item) }
                                Button("Anteprima") { model.selection = i; model.previewing = true }
                                Divider()
                                Button("Elimina", role: .destructive) { model.delete(item) }
                            }
                    }
                }
                .padding(.vertical, 6).padding(.horizontal, 4)
            }
            .onChange(of: model.selection) { _, new in
                guard model.results.indices.contains(new) else { return }
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(model.results[new].id, anchor: .center) }
            }
            .onChange(of: model.query) { if let f = model.results.first { proxy.scrollTo(f.id, anchor: .leading) } }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: model.totalCount == 0 ? "clipboard" : "magnifyingglass").font(.system(size: 28)).foregroundStyle(.secondary)
            Text(model.totalCount == 0 ? "Copia qualcosa con ⌘C: comparirà qui." : "Nessun risultato per “\(model.query)”.")
                .foregroundStyle(.secondary)
            if model.totalCount > 0 {
                Text("La ricerca guarda testo, testo nelle immagini e significato. Prova parole diverse o togli i filtri.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
