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
    @AppStorage("panelEdge") private var edge = PanelEdge.left

    private let filters: [(String, ClipKind?)] = [
        (String(localized: "Tutto"), nil), (String(localized: "Testo"), .text), (String(localized: "Formattato"), .richText), (String(localized: "Link"), .link),
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

    @ViewBuilder private var topBar: some View {
        if edge.isVertical {
            VStack(spacing: 8) {
                HStack { logo; Spacer(); countAndSettings }
                searchField
                ScrollView(.horizontal, showsIndicators: false) { filterBar }
            }
        } else {
            HStack(spacing: 12) {
                logo
                searchField.frame(maxWidth: 480)
                filterBar
                Spacer()
                countAndSettings
            }
        }
    }

    private var logo: some View {
        Text("trove").font(Theme.ui(15, .bold)).foregroundStyle(Color.trove)
            .accessibilityHidden(true)
    }

    private var searchField: some View {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Cerca  ·  tipo:immagine  app:Safari  oggi", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(Theme.ui(14))
                    .focused($searchFocused)
                if model.semanticActive {
                    Text("anche per significato").font(Theme.ui(11)).foregroundStyle(.secondary)
                        .help("Risultati anche per significato, oltre che per parole")
                } else if model.semanticLoading {
                    ProgressView().controlSize(.small)
                } else if model.canSearchByMeaning {
                    Button { model.searchByMeaning(); searchFocused = true } label: {
                        // capsula colorata e manina: deve leggersi come pulsante, non come etichetta
                        Label("per significato", systemImage: "sparkles").font(Theme.ui(11, .semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.trove.opacity(0.14), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.trove.opacity(0.35), lineWidth: 0.5))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).foregroundStyle(Color.trove)
                    .pointerStyle(.link)
                    .help("Cerca anche sinonimi e parole affini con Apple Intelligence")
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous)
                .strokeBorder(searchFocused ? Color.trove.opacity(0.7) : Color.hairline, lineWidth: searchFocused ? 1.5 : 0.5))
    }

    private var countAndSettings: some View {
        HStack(spacing: 12) {
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
            ScrollView(edge.isVertical ? .vertical : .horizontal, showsIndicators: false) {
                if edge.isVertical { LazyVStack(spacing: 12) { cards }.padding(.vertical, 10).padding(.horizontal, 4) }
                else { LazyHStack(spacing: 12) { cards }.padding(.vertical, 10).padding(.horizontal, 4) }
            }
            .onChange(of: model.selection) { _, new in
                guard model.results.indices.contains(new) else { return }
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(model.results[new].id, anchor: .center) }
            }
            // sui risultati, non sulla query: la ricerca è asincrona e alla digitazione la lista è ancora la vecchia
            .onChange(of: model.results.first?.id) { if model.selection == 0, let f = model.results.first { proxy.scrollTo(f.id, anchor: edge.isVertical ? .top : .leading) } }
        }
    }

    private var popoverEdge: Edge {
        switch edge { case .bottom: .top; case .top: .bottom; case .left: .trailing; case .right: .leading }
    }

    @ViewBuilder private var cards: some View {
            ForEach(Array(model.results.enumerated()), id: \.element.id) { i, item in
                if model.query.isEmpty, let day = dayLabel(at: i) { DaySeparator(text: day, vertical: edge.isVertical) }
                CardView(item: item, index: i, selected: i == model.selection, store: model.store,
                         width: edge.isVertical ? PanelController.sideWidth - 40 : CardView.size.width,
                     height: edge.isVertical ? 168 : CardView.size.height)
                    .id(item.id)
                    .onTapGesture(count: 2) { actions.paste(item, .normal) }
                    .simultaneousGesture(TapGesture().onEnded { model.selection = i })
                    .popover(isPresented: Binding(get: { model.previewing && i == model.selection },
                                                  set: { if !$0 { model.previewing = false } }), arrowEdge: popoverEdge) {
                        PreviewView(item: model.store.get(item.id) ?? item, store: model.store)
                    }
                    .contextMenu {
                        Button("Incolla", systemImage: "doc.on.clipboard") { actions.paste(item, .normal) }
                        Button(item.kind == .image ? "Incolla solo il testo dell’immagine" : "Incolla come testo semplice", systemImage: "textformat") { actions.paste(item, .plain) }
                        Button("Incolla per agenti (pulito, senza segreti)", systemImage: "lock.shield") { actions.paste(item, .agent) }
                        Button("Copia", systemImage: "doc.on.doc") { actions.copy(item) }
                        Button("Anteprima", systemImage: "eye") { model.selection = i; model.previewing = true }
                        Divider()
                        Button("Elimina", systemImage: "trash", role: .destructive) { model.delete(item) }
                    }
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

    @ViewBuilder private var hints: some View {
        let keys = ForEach([("↩", String(localized: "incolla")), ("⇧↩", String(localized: "testo semplice")), ("⌥↩", String(localized: "per agenti")),
                            ("␣", String(localized: "anteprima")), ("⌘⌫", String(localized: "elimina")), ("esc", String(localized: "chiudi"))], id: \.0) { k, v in
            HStack(spacing: 5) { KeyCap(k); Text(v) }
        }
        Group {
            if edge.isVertical {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 6) { keys }
            } else {
                HStack(spacing: 14) {
                    keys
                    Spacer()
                    if let it = model.selected, let tags = it.tags {
                        Text(tags.split(separator: ",").prefix(5).joined(separator: " ·")).lineLimit(1).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .font(Theme.ui(11)).foregroundStyle(.secondary)
    }

    @ViewBuilder private var emptyState: some View {
        if model.totalCount == 0 {
            ContentUnavailableView("Nessun elemento", systemImage: "clipboard",
                                   description: Text("Copia qualcosa con ⌘C: comparirà qui."))
        } else {
            ContentUnavailableView("Nessun risultato per “\(model.query)”", systemImage: "magnifyingglass",
                                   description: Text("La ricerca considera il testo, anche nelle immagini, e il significato. Prova altre parole o rimuovi i filtri."))
        }
    }
}

struct DaySeparator: View {
    let text: String
    var vertical = false
    var body: some View {
        let t = Text(text).font(Theme.ui(11, .semibold)).foregroundStyle(.secondary).fixedSize()
        if vertical { t.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4) }
        else { t.rotationEffect(.degrees(-90)).frame(width: 18, height: CardView.size.height) }
    }
}
