import SwiftUI
import TroveCore

struct PanelActions {
    var paste: (ClipItem, PasteMode) -> Void
    var copy: (ClipItem) -> Void
    var settings: () -> Void
}

struct PanelView: View {
    @ObservedObject var model: AppModel
    let actions: PanelActions
    @FocusState private var searchFocused: Bool
    @Namespace private var filterNS

    private let filters: [(String, ClipKind?)] = [
        (String(localized: "Tutto"), nil), (String(localized: "Testo"), .text), (String(localized: "Rich"), .richText), (String(localized: "Link"), .link),
        (String(localized: "Immagini"), .image), (String(localized: "File"), .file), (String(localized: "Colori"), .color),
    ]

    var body: some View {
        VStack(spacing: 8) {
            topBar
            if model.results.isEmpty { emptyState.frame(maxWidth: .infinity, maxHeight: .infinity) } else { strip }
            hints
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .onChange(of: model.openToken) { searchFocused = true }
        .onAppear { searchFocused = true }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("trove").font(Theme.ui(15, .bold)).foregroundStyle(Color.trove)
                .accessibilityHidden(true)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Cerca  ·  type:image  app:Safari  oggi", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(Theme.ui(14))
                    .focused($searchFocused)
                if model.semanticActive {
                    Text("anche per significato").font(Theme.ui(11)).foregroundStyle(.secondary)
                        .help("Risultati anche per significato, oltre che per parole")
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous)
                .strokeBorder(searchFocused ? Color.trove.opacity(0.7) : Color.hairline, lineWidth: searchFocused ? 1.5 : 0.5))
            .frame(maxWidth: 480)

            filterBar
            Spacer()
            Text(model.query.isEmpty && model.kindFilter == nil ? (model.totalCount == 1 ? String(localized: "1 elemento") : String(localized: "\(model.totalCount) elementi")) : (model.results.count == 1 ? String(localized: "1 risultato") : String(localized: "\(model.results.count) risultati")))
                .font(Theme.ui(12)).foregroundStyle(.secondary).monospacedDigit()
            Button(action: actions.settings) { Image(systemName: "gearshape") }
                .buttonStyle(.borderless).foregroundStyle(.secondary).help("Impostazioni (⌘,)")
                .accessibilityLabel("Impostazioni")
        }
    }

    /// Filtri a capsula senza cornice né divisori: il fondo della selezione scorre tra le voci.
    private var filterBar: some View {
        HStack(spacing: 2) {
            ForEach(filters, id: \.0) { name, kind in
                let on = model.kindFilter == kind
                Button { withAnimation(.snappy(duration: 0.2)) { model.kindFilter = kind } } label: {
                    Text(name).font(Theme.ui(12, on ? .semibold : .regular))
                        .foregroundStyle(on ? .primary : .secondary)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background {
                            if on { Capsule().fill(.primary.opacity(0.1)).matchedGeometryEffect(id: "filter", in: filterNS) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { i, item in
                        if model.query.isEmpty, let day = dayLabel(at: i) { DaySeparator(text: day) }
                        CardView(item: item, index: i, selected: i == model.selection, store: model.store)
                            .id(item.id)
                            .onTapGesture(count: 2) { actions.paste(item, .normal) }
                            .simultaneousGesture(TapGesture().onEnded { model.selection = i })
                            .popover(isPresented: Binding(get: { model.previewing && i == model.selection },
                                                          set: { if !$0 { model.previewing = false } }), arrowEdge: .top) {
                                PreviewView(item: model.store.get(item.id) ?? item, store: model.store)
                            }
                            .contextMenu {
                                Button("Incolla") { actions.paste(item, .normal) }
                                Button(item.kind == .image ? "Incolla solo il testo dell’immagine" : "Incolla come testo semplice") { actions.paste(item, .plain) }
                                Button("Incolla per agenti (pulito, senza segreti)") { actions.paste(item, .agent) }
                                Button("Copia") { actions.copy(item) }
                                Button("Anteprima") { model.selection = i; model.previewing = true }
                                Divider()
                                Button("Elimina", role: .destructive) { model.delete(item) }
                            }
                    }
                }
                .padding(.vertical, 10).padding(.horizontal, 4)
            }
            .onChange(of: model.selection) { _, new in
                guard model.results.indices.contains(new) else { return }
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(model.results[new].id, anchor: .center) }
            }
            .onChange(of: model.query) { if let f = model.results.first { proxy.scrollTo(f.id, anchor: .leading) } }
        }
    }

    /// Etichetta del giorno quando cambia rispetto alla card precedente.
    private func dayLabel(at i: Int) -> String? {
        let cal = Calendar.current
        let d = model.results[i].createdAt
        if i > 0, cal.isDate(d, inSameDayAs: model.results[i - 1].createdAt) { return nil }
        if cal.isDateInToday(d) { return String(localized: "Oggi") }
        if cal.isDateInYesterday(d) { return String(localized: "Ieri") }
        return d.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    private var hints: some View {
        HStack(spacing: 14) {
            ForEach([("↩", String(localized: "incolla")), ("⇧↩", String(localized: "testo semplice")), ("⌥↩", String(localized: "per agenti")),
                         ("␣", String(localized: "anteprima")), ("⌘⌫", String(localized: "elimina")), ("esc", String(localized: "chiudi"))], id: \.0) { k, v in
                HStack(spacing: 5) { KeyCap(k); Text(v) }
            }
            Spacer()
            if let it = model.selected, let tags = it.tags {
                Text(tags.split(separator: ",").prefix(5).joined(separator: " ·")).lineLimit(1).foregroundStyle(.tertiary)
            }
        }
        .font(Theme.ui(11)).foregroundStyle(.secondary)
    }

    @ViewBuilder private var emptyState: some View {
        if model.totalCount == 0 {
            ContentUnavailableView("Ancora niente", systemImage: "clipboard",
                                   description: Text("Copia qualcosa con ⌘C: comparirà qui."))
        } else {
            ContentUnavailableView("Nessun risultato per “\(model.query)”", systemImage: "magnifyingglass",
                                   description: Text("La ricerca guarda testo, testo nelle immagini e significato. Prova parole diverse o togli i filtri."))
        }
    }
}

struct DaySeparator: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.ui(11, .semibold))
            .foregroundStyle(.secondary)
            .fixedSize()
            .rotationEffect(.degrees(-90))
            .frame(width: 18, height: CardView.size.height)
    }
}
