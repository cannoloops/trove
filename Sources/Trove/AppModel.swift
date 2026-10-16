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
    @Published private(set) var totalCount = 0
    /// Cambia ogni volta che il pannello si apre: la vista rifocalizza la ricerca.
    @Published var openToken = 0

    private var corpus: [ClipItem] = []
    private var searchTask: Task<Void, Never>?
    private var semanticTask: Task<Void, Never>?
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
                self.runSearch(expansions: nil)
            }
        }
    }

    private func scheduleSearch() {
        selection = 0
        runSearch(expansions: nil)
    }

    private func runSearch(expansions: [String]?) {
        var q = Query.parse(query)
        if let k = kindFilter { q.kinds.insert(k) }
        let corpus = corpus, store = store
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            let r = await Task.detached(priority: .userInitiated) {
                Search.run(q, store: store, corpus: corpus, expansions: expansions ?? [], limit: 2000)
            }.value
            guard !Task.isCancelled, let self else { return }
            do {
                let keep = self.selected?.id
                self.results = r
                if let keep, let i = r.firstIndex(where: { $0.id == keep }) { self.selection = i }
                else { self.selection = min(self.selection, max(0, r.count - 1)) }
                self.semanticActive = expansions != nil && !(expansions ?? []).isEmpty
            }
        }
        if expansions == nil { scheduleSemantic(q.text) }
    }

    /// Dopo una pausa nella digitazione chiede al modello on-device sinonimi it/en e rilancia la ricerca.
    private func scheduleSemantic(_ text: String) {
        semanticTask?.cancel()
        semanticActive = false
        guard text.count >= 3, SemanticTagger.isAvailable else { return }
        semanticTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            let exp = await SemanticTagger.expand(query: text)
            guard !Task.isCancelled, let self, Query.parse(self.query).text == text else { return }
            self.runSearch(expansions: exp)
        }
    }

    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = max(0, min(results.count - 1, selection + delta))
    }

    func delete(_ item: ClipItem) {
        store.delete(item.id)
        corpus.removeAll { $0.id == item.id }
        results.removeAll { $0.id == item.id }
        totalCount = corpus.count
        selection = min(selection, max(0, results.count - 1))
    }

    func resetForOpen() {
        query = ""
        kindFilter = nil
        selection = 0
        previewing = false
        openToken += 1
    }
}
