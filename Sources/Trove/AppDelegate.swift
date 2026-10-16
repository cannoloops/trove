import AppKit
import SwiftUI
import TroveCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: Store!
    private var model: AppModel!
    private var monitor: ClipboardMonitor!
    private var panel: PanelController!
    private var hotKey: HotKey!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private let settings = SettingsModel()
    private var enrichQueue: Task<Void, Never>?

    static let dataDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Trove")

    func applicationDidFinishLaunching(_ notification: Notification) {
        do { store = try Store(directory: Self.dataDir) } catch {
            let a = NSAlert()
            a.messageText = "Trove non riesce ad aprire la history"
            a.informativeText = "\(error)\n\nCartella: \(Self.dataDir.path)"
            a.runModal()
            NSApp.terminate(nil)
            return
        }
        model = AppModel(store: store)
        monitor = ClipboardMonitor(store: store) { [weak self] id, isNew in
            guard let self else { return }
            model.reload()
            if isNew { enrich([id]) }
        }
        monitor.start()

        panel = PanelController(model: model)
        panel.onPaste = { [weak self] in self?.paste($0, plain: $1) }
        panel.onCopy = { [weak self] in self?.copy($0) }
        panel.onSettings = { [weak self] in self?.openSettings() }

        hotKey = HotKey { [weak self] in self?.panel.toggle() }
        hotKey.register(settings.combo)
        settings.onCombo = { [weak self] c in self?.hotKey.register(c) ?? false }
        settings.onBackup = { [weak self] in self?.backupNow(manual: true) }
        settings.onRestore = { [weak self] in self?.restore() }
        settings.onClear = { [weak self] in self?.store.deleteAll(); self?.model.reload() }

        setupStatusItem()
        if !Paster.isTrusted { Paster.promptForAccessibility() }

        // arricchisce ciò che non lo è ancora (es. dopo un ripristino o un aggiornamento)
        let store = store!
        Task {
            // tagsVersion 2: tag generati per lingua (it + en); gli elementi con tag vecchi si rigenerano una volta
            let retag = UserDefaults.standard.integer(forKey: "tagsVersion") < 2
            let pending = await Task.detached(priority: .utility) {
                retag ? store.all().map(\.id) : store.pendingEnrichmentIds()
            }.value
            UserDefaults.standard.set(2, forKey: "tagsVersion")
            enrich(pending)
        }

        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.backupIfDue() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in self?.backupIfDue() }
    }

    // MARK: azioni

    private func paste(_ item: ClipItem, plain: Bool) {
        Paster.write(store.get(item.id) ?? item, plain: plain, store: store)
        monitor.skipCurrent()
        touch(item.id)
        panel.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { Paster.sendPaste() }
    }

    private func copy(_ item: ClipItem) {
        Paster.write(store.get(item.id) ?? item, plain: false, store: store)
        monitor.skipCurrent()
        touch(item.id)
        panel.hide()
    }

    private func touch(_ id: Int64) {
        let store = store!
        Task {
            await Task.detached(priority: .userInitiated) { store.touch(id) }.value
            model.reload()
        }
    }

    /// Coda seriale: OCR, titolo link, tag semantici ed embedding uno alla volta, in background.
    private func enrich(_ ids: [Int64]) {
        guard !ids.isEmpty else { return }
        let prev = enrichQueue, store = store!
        enrichQueue = Task { [weak self] in
            await prev?.value
            for id in ids {
                await Task.detached(priority: .utility) {
                    if let item = store.get(id) { await Enricher.enrich(item, store: store) }
                }.value
                self?.model.refresh(id)
            }
        }
    }

    // MARK: backup

    private func backupIfDue() {
        guard settings.autoBackup, let dest = Backup.driveFolder() else { return }
        if let last = Backup.lastBackupDate(at: dest), Date().timeIntervalSince(last) < 86400 { return }
        backupNow(manual: false)
    }

    private func backupNow(manual: Bool) {
        let store = store!
        settings.backupStatus = "Backup in corso…"
        let settings = settings
        Task {
            let r = await Task.detached(priority: .utility) { Result { try Backup.runToDrive(store: store) } }.value
            switch r {
            case .success(let dest):
                settings.lastBackup = Backup.lastBackupDate(at: dest)
                settings.backupStatus = "Backup completato in \(dest.path)."
            case .failure(let error):
                settings.backupStatus = error as? BackupError == .driveNotFound
                    ? "Google Drive per desktop non trovato." : "Backup non riuscito: \(error.localizedDescription)"
                if manual { NSSound.beep() }
            }
        }
    }

    private func restore() {
        guard let src = Backup.driveFolder() else { return }
        store.close()
        do {
            try Backup.restore(from: src, dataDir: Self.dataDir)
            relaunch()
        } catch {
            // i dati locali non sono stati toccati: si riapre lo stesso DB
            let msg = error as? BackupError == .backupCorrupted
                ? "Il backup su Drive non è leggibile (forse non ancora scaricato): la history locale è intatta."
                : "Ripristino non riuscito: \(error.localizedDescription). La history locale è intatta."
            let a = NSAlert()
            a.messageText = "Ripristino non riuscito"
            a.informativeText = msg
            NSApp.activate()
            a.runModal()
            relaunch() // riapre l'app sullo store locale intatto
        }
    }

    private func relaunch() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        // aspetta che questo processo sia davvero terminato prima di riaprire l'app
        p.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"\(Bundle.main.bundlePath)\""]
        try? p.run()
        NSApp.terminate(nil)
    }

    // MARK: UI

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: "Trove")
        let menu = NSMenu()
        let open = NSMenuItem(title: "Apri Trove", action: #selector(openPanel), keyEquivalent: "")
        menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Esegui backup ora", action: #selector(menuBackup), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Impostazioni…", action: #selector(openSettingsAction), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Esci da Trove", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.items.forEach { if $0.action != #selector(NSApplication.terminate(_:)) { $0.target = self } }
        statusItem.menu = menu
    }

    @objc private func openPanel() { panel.show() }
    @objc private func menuBackup() { backupNow(manual: true) }
    @objc private func openSettingsAction() { openSettings() }

    func openSettings() {
        panel.hide()
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(s: settings, app: model)))
            w.title = "Impostazioni di Trove"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        settings.trusted = Paster.isTrusted
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
