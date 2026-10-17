import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Persistenza su SQLite con indice FTS5 trigram (substring, case-insensitive).
// ponytail: un solo lock globale; basta per un utente, connection pool se servisse concorrenza vera.
public final class Store: @unchecked Sendable {
    public let directory: URL
    public let blobsDir: URL
    public var dbURL: URL { directory.appendingPathComponent("trove.sqlite") }
    private var db: OpaquePointer?
    private let lock = NSRecursiveLock()

    public init(directory: URL) throws {
        self.directory = directory
        blobsDir = directory.appendingPathComponent("blobs")
        try FileManager.default.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        guard sqlite3_open(directory.appendingPathComponent("trove.sqlite").path, &db) == SQLITE_OK else {
            throw StoreError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        try exec("""
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS items(
          id INTEGER PRIMARY KEY, kind TEXT NOT NULL, text TEXT NOT NULL, rtf BLOB, html TEXT, blob TEXT,
          files TEXT, app TEXT, bundle TEXT, created REAL NOT NULL, hash TEXT NOT NULL UNIQUE,
          ocr TEXT, title TEXT, emb BLOB, lang TEXT, tags TEXT);
        CREATE INDEX IF NOT EXISTS items_created ON items(created DESC);
        CREATE VIRTUAL TABLE IF NOT EXISTS fts USING fts5(body, tokenize='trigram');
        """)
    }

    /// URL di un blob, solo se il nome è un file dentro `blobs/`: un DB ripristinato non deve puntare altrove (`../`).
    public func blobURL(_ name: String) -> URL? {
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else { return nil }
        return blobsDir.appendingPathComponent(name)
    }

    deinit { sqlite3_close(db) }

    public func close() { lock.withLock { sqlite3_close(db); db = nil } }

    // MARK: write

    @discardableResult
    public func insert(_ it: ClipItem) throws -> Int64 {
        try lock.withLock {
            let sql = """
            INSERT INTO items(kind,text,rtf,html,blob,files,app,bundle,created,hash)
            VALUES(?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(hash) DO UPDATE SET created=excluded.created, app=excluded.app, bundle=excluded.bundle
            RETURNING id
            """
            let st = try prepare(sql)
            defer { sqlite3_finalize(st) }
            bind(st, 1, it.kind.rawValue); bind(st, 2, it.text); bind(st, 3, it.rtf); bind(st, 4, it.html)
            bind(st, 5, it.blobPath); bind(st, 6, it.filePaths.isEmpty ? nil : it.filePaths.joined(separator: "\n"))
            bind(st, 7, it.sourceApp); bind(st, 8, it.sourceBundle)
            sqlite3_bind_double(st, 9, it.createdAt.timeIntervalSince1970); bind(st, 10, it.hash)
            guard sqlite3_step(st) == SQLITE_ROW else { throw StoreError.sqlite(String(cString: sqlite3_errmsg(db))) }
            let id = sqlite3_column_int64(st, 0)
            reindex(id)
            return id
        }
    }

    public func update(ocr: String?, title: String?, tags: String? = nil, embedding: [Float]?, lang: String?, for id: Int64) {
        lock.withLock {
            guard let st = try? prepare("""
            UPDATE items SET ocr=coalesce(?,ocr), title=coalesce(?,title), emb=coalesce(?,emb), lang=coalesce(?,lang), tags=coalesce(?,tags) WHERE id=?
            """) else { return }
            defer { sqlite3_finalize(st) }
            bind(st, 1, ocr); bind(st, 2, title)
            bind(st, 3, embedding.map { $0.withUnsafeBufferPointer { Data(buffer: $0) } }); bind(st, 4, lang); bind(st, 5, tags)
            sqlite3_bind_int64(st, 6, id)
            sqlite3_step(st)
            reindex(id)
        }
    }

    /// Riporta in cima un elemento (es. dopo averlo incollato).
    public func touch(_ id: Int64) {
        lock.withLock { run("UPDATE items SET created=? WHERE id=?", Date().timeIntervalSince1970, id) }
    }

    public func delete(_ id: Int64) {
        lock.withLock {
            if let url = get(id)?.blobPath.flatMap(blobURL) { try? FileManager.default.removeItem(at: url) }
            run("DELETE FROM items WHERE id=?", id)
            run("DELETE FROM fts WHERE rowid=?", id)
        }
    }

    public func deleteAll() {
        lock.withLock {
            run("DELETE FROM items"); run("DELETE FROM fts")
            try? FileManager.default.removeItem(at: blobsDir)
            try? FileManager.default.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        }
    }

    // MARK: read

    public func count() -> Int {
        lock.withLock {
            guard let st = try? prepare("SELECT count(*) FROM items") else { return 0 }
            defer { sqlite3_finalize(st) }
            return sqlite3_step(st) == SQLITE_ROW ? Int(sqlite3_column_int64(st, 0)) : 0
        }
    }

    public func get(_ id: Int64) -> ClipItem? { query("SELECT \(Self.cols) FROM items WHERE id=?", id).first }

    public func get(byHash h: String) -> ClipItem? {
        lock.withLock {
            guard let st = try? prepare("SELECT id FROM items WHERE hash=?") else { return nil }
            defer { sqlite3_finalize(st) }
            bind(st, 1, h)
            return sqlite3_step(st) == SQLITE_ROW ? get(sqlite3_column_int64(st, 0)) : nil
        }
    }

    public func recent(limit: Int, offset: Int) -> [ClipItem] {
        query("SELECT \(Self.cols) FROM items ORDER BY created DESC LIMIT ? OFFSET ?", Int64(limit), Int64(offset))
    }

    /// Elementi mai arricchiti (niente tag né embedding), dal più recente.
    public func pendingEnrichmentIds() -> [Int64] {
        lock.withLock {
            guard let st = try? prepare("SELECT id FROM items WHERE emb IS NULL AND tags IS NULL ORDER BY created DESC") else { return [] }
            defer { sqlite3_finalize(st) }
            var ids: [Int64] = []
            while sqlite3_step(st) == SQLITE_ROW { ids.append(sqlite3_column_int64(st, 0)) }
            return ids
        }
    }

    /// Corpus per la ricerca: senza rtf/html (pesanti); `get` li restituisce per anteprima e incolla.
    public func all() -> [ClipItem] { query("SELECT \(Self.lightCols) FROM items ORDER BY created DESC") }

    public func items(ids: [Int64]) -> [ClipItem] {
        guard !ids.isEmpty else { return [] }
        let byId = Dictionary(uniqueKeysWithValues:
            query("SELECT \(Self.cols) FROM items WHERE id IN (\(ids.map(String.init).joined(separator: ",")))").map { ($0.id, $0) })
        return ids.compactMap { byId[$0] }
    }

    /// Ricerca full-text. Token ≥3 caratteri passano da FTS5 trigram; query più corte usano LIKE.
    public func ftsSearch(_ q: String, limit: Int) -> [Int64] {
        let tokens = q.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return [] }
        return lock.withLock {
            let sql: String
            let args: [String]
            if tokens.allSatisfy({ $0.count >= 3 }) {
                // ogni token tra virgolette: neutralizza la sintassi FTS (AND/OR/NOT, *, -, parentesi)
                sql = "SELECT rowid FROM fts WHERE fts MATCH ? ORDER BY rank LIMIT ?"
                args = [tokens.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: " ")]
            } else {
                sql = "SELECT rowid FROM fts WHERE " + tokens.map { _ in "body LIKE ? ESCAPE '\\'" }.joined(separator: " AND ") + " LIMIT ?"
                args = tokens.map { "%" + $0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_") + "%" }
            }
            guard let st = try? prepare(sql) else { return [] }
            defer { sqlite3_finalize(st) }
            for (i, a) in args.enumerated() { bind(st, Int32(i + 1), a) }
            sqlite3_bind_int64(st, Int32(args.count + 1), Int64(limit))
            var ids: [Int64] = []
            while sqlite3_step(st) == SQLITE_ROW { ids.append(sqlite3_column_int64(st, 0)) }
            return ids
        }
    }

    // MARK: backup

    /// Copia consistente del DB (anche con WAL attivo).
    public func vacuum(into url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        var ro: OpaquePointer?
        defer { sqlite3_close(ro) }
        guard sqlite3_open_v2(dbURL.path, &ro, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw StoreError.sqlite(String(cString: sqlite3_errmsg(ro)))
        }
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(ro, "VACUUM INTO ?", -1, &st, nil) == SQLITE_OK else { throw StoreError.sqlite(String(cString: sqlite3_errmsg(ro))) }
        defer { sqlite3_finalize(st) }
        sqlite3_bind_text(st, 1, url.path, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(st) == SQLITE_DONE else { throw StoreError.sqlite(String(cString: sqlite3_errmsg(ro))) }
    }

    /// true se `url` è un database SQLite integro.
    public static func isValidDatabase(_ url: URL) -> Bool {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return false }
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA quick_check", -1, &st, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(st) }
        guard sqlite3_step(st) == SQLITE_ROW, let r = sqlite3_column_text(st, 0) else { return false }
        return String(cString: r) == "ok"
    }

    // MARK: private

    private static let cols = "id,kind,text,rtf,html,blob,files,app,bundle,created,hash,ocr,title,emb,lang,tags"
    private static let lightCols = "id,kind,text,NULL,NULL,blob,files,app,bundle,created,hash,ocr,title,emb,lang,tags"

    private func reindex(_ id: Int64) {
        run("DELETE FROM fts WHERE rowid=?", id)
        guard let it = get(id) else { return }
        guard let st = try? prepare("INSERT INTO fts(rowid, body) VALUES(?,?)") else { return }
        defer { sqlite3_finalize(st) }
        sqlite3_bind_int64(st, 1, id)
        bind(st, 2, it.searchableText + "\n" + (it.sourceApp ?? ""))
        sqlite3_step(st)
    }

    private func query(_ sql: String, _ args: Int64...) -> [ClipItem] {
        lock.withLock {
            guard let st = try? prepare(sql) else { return [] }
            defer { sqlite3_finalize(st) }
            for (i, a) in args.enumerated() { sqlite3_bind_int64(st, Int32(i + 1), a) }
            var out: [ClipItem] = []
            while sqlite3_step(st) == SQLITE_ROW {
                var it = ClipItem(kind: ClipKind(rawValue: str(st, 1) ?? "") ?? .text, text: str(st, 2) ?? "",
                                  rtf: data(st, 3), html: str(st, 4), blobPath: str(st, 5),
                                  filePaths: str(st, 6)?.split(separator: "\n").map(String.init) ?? [],
                                  sourceApp: str(st, 7), sourceBundle: str(st, 8),
                                  createdAt: Date(timeIntervalSince1970: sqlite3_column_double(st, 9)), hash: str(st, 10) ?? "")
                it.id = sqlite3_column_int64(st, 0)
                it.ocr = str(st, 11); it.title = str(st, 12)
                it.embedding = data(st, 13).map { d in d.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) } }
                it.embeddingLang = str(st, 14); it.tags = str(st, 15)
                out.append(it)
            }
            return out
        }
    }

    private func run(_ sql: String, _ args: Any...) {
        guard let st = try? prepare(sql) else { return }
        defer { sqlite3_finalize(st) }
        for (i, a) in args.enumerated() {
            switch a {
            case let v as Int64: sqlite3_bind_int64(st, Int32(i + 1), v)
            case let v as Double: sqlite3_bind_double(st, Int32(i + 1), v)
            default: bind(st, Int32(i + 1), "\(a)")
            }
        }
        sqlite3_step(st)
    }

    private func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw StoreError.sqlite(String(cString: sqlite3_errmsg(db))) }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else { throw StoreError.sqlite(String(cString: sqlite3_errmsg(db))) }
        return st
    }

    private func bind(_ st: OpaquePointer?, _ i: Int32, _ v: String?) {
        if let v { sqlite3_bind_text(st, i, v, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(st, i) }
    }

    private func bind(_ st: OpaquePointer?, _ i: Int32, _ v: Data?) {
        if let v { _ = v.withUnsafeBytes { sqlite3_bind_blob(st, i, $0.baseAddress, Int32(v.count), SQLITE_TRANSIENT) } }
        else { sqlite3_bind_null(st, i) }
    }

    private func str(_ st: OpaquePointer?, _ i: Int32) -> String? {
        sqlite3_column_text(st, i).map { String(cString: $0) }
    }

    private func data(_ st: OpaquePointer?, _ i: Int32) -> Data? {
        guard let p = sqlite3_column_blob(st, i) else { return nil }
        return Data(bytes: p, count: Int(sqlite3_column_bytes(st, i)))
    }
}

public enum StoreError: Error { case sqlite(String) }
