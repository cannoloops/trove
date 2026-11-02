import AppKit
import Combine
import TroveCore

/// Stato condiviso tra monitor, pannello e impostazioni.
@MainActor
final class AppModel: ObservableObject {
    let store: Store
    @Published var query = "" { didSet { scheduleSearch() } }
    @Published var kindFilter: ClipKind? { didSet { scheduleSearch() } }
    @Published private(set) var results: [ClipItem] = []
    @Published var selection = 0
    @Published var previewing = false
    @Published private(set) var semanticActive = false
    @Published private(set) var semanticLoading = false
    @Published private(set) var totalCount = 0
    /// Cambia ogni volta che il pannello si apre: la vista rifocalizza la ricerca.
    @Published var openToken = 0

    private var corpus: [ClipItem] = []
    private var searchTask: Task<Void, Never>?
    private var semanticTask: Task<Void, Never>?
    /// Sinonimi chiesti con «per significato»: restano finché non cambia la query.
    private var expansions: [String] = []
    private var reloadPending = false

    init(store: Store) {
        self.store = store
        reload()
    }

    var selected: ClipItem? { results.indices.contains(selection) ? results[selection] : nil }

    /// Ricarica il corpus dal DB (dopo nuove copie o arricchimenti), coalescendo richieste ravvicinate.
    func reload() {
        guard !reloadPending else { return }
        reloadPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            reloadPending = false
            let store = store
            Task {
                let all = await Task.detached(priority: .userInitiated) { store.all() }.value
                self.corpus = all
                self.totalCount = all.count
                self.runSearch()
            }
        }
    }

    private func scheduleSearch() {
        selection = 0
        semanticTask?.cancel()
        semanticLoading = false
        expansions = []
        runSearch(keepSelection: false)
    }

    /// `keepSelection`: dopo un aggiornamento della stessa ricerca resta sull'elemento scelto; con una query nuova si riparte dal primo.
    private func runSearch(keepSelection: Bool = true) {
        var q = Query.parse(query)
        if let k = kindFilter { q.kinds.insert(k) }
        let corpus = corpus, store = store, expansions = expansions
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            // funzione nonisolated: gira fuori dal main thread ma eredita la cancellazione di questo task
            let r = await Self.search(q, store: store, corpus: corpus, expansions: expansions)
            guard !Task.isCancelled, let self else { return }
            do {
                let keep = keepSelection ? self.selected?.id : nil
                self.results = r
                if let keep, let i = r.firstIndex(where: { $0.id == keep }) { self.selection = i }
                else { self.selection = min(self.selection, max(0, r.count - 1)) }
                self.semanticActive = !expansions.isEmpty
            }
        }
    }

    /// Il modello impiega circa un secondo: con una query lunga almeno 3 caratteri si può chiedere la ricerca per significato.
    var canSearchByMeaning: Bool { Query.parse(query).text.count >= 3 && SemanticTagger.isAvailable }
    nonisolated private static func search(_ q: Query, store: Store, corpus: [ClipItem], expansions: [String]) async -> [ClipItem] {
        Search.run(q, store: store, corpus: corpus, expansions: expansions, limit: 2000)
    }

    /// Aggiorna un solo elemento nel corpus (dopo l'arricchimento) senza rileggere tutto il DB.
    func refresh(_ id: Int64) {
        let store = store
        Task {
            guard var it = await Task.detached(priority: .utility, operation: { store.get(id) }).value else { return }
            it.rtf = nil; it.html = nil // il corpus resta leggero
            if let i = corpus.firstIndex(where: { $0.id == id }) { corpus[i] = it } else { corpus.insert(it, at: 0) }
            if !query.isEmpty || kindFilter != nil { runSearch() }
            else if let i = results.firstIndex(where: { $0.id == id }) { results[i] = it }
        }
    }

    func delete(_ item: ClipItem) {
        let store = store
        Task.detached(priority: .userInitiated) { store.delete(item.id) }
        if let b = item.blobPath { try? FileManager.default.removeItem(at: AgentPaste.cachedImage(b, cacheDir: Paster.cacheDir)) }
        corpus.removeAll { $0.id == item.id }
        results.removeAll { $0.id == item.id }
        totalCount = corpus.count
        selection = min(selection, max(0, results.count - 1))
    }

    /// Solo su richiesta: chiede al modello on-device sinonimi it/en e rilancia la ricerca, così i risultati non cambiano da soli.
    func searchByMeaning() {
        guard canSearchByMeaning, !semanticLoading else { return }
        let text = Query.parse(query).text
        semanticLoading = true
        semanticTask = Task { [weak self] in
            let exp = await SemanticTagger.expand(query: text)
            guard !Task.isCancelled, let self, Query.parse(self.query).text == text else { return }
            self.semanticLoading = false
            self.expansions = exp
            self.runSearch()
        }
    }

    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = max(0, min(results.count - 1, selection + delta))
    }

    func resetForOpen() {
        query = ""
        kindFilter = nil
        selection = 0
        previewing = false
        openToken += 1
    }
}
