import AppKit
import ServiceManagement
import SwiftUI
import TroveCore

@MainActor
final class SettingsModel: ObservableObject {
    @Published var combo = HotKey.Combo.load()
    @Published var recording = false
    @Published var hotKeyError: String?
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var loginError: String?
    @Published var autoBackup = Backup.autoEnabled() {
        didSet { UserDefaults.standard.set(autoBackup, forKey: "autoBackup") }
    }
    @Published var redactForAI = Paster.redactForAI { didSet { UserDefaults.standard.set(redactForAI, forKey: "redactForAI") } }
    @Published var fetchLinkTitles = UserDefaults.standard.bool(forKey: "fetchLinkTitles") {
        didSet { UserDefaults.standard.set(fetchLinkTitles, forKey: "fetchLinkTitles") }
    }
    @Published var backupStatus: String?
    @Published var lastBackup: Date?
    @Published var trusted = Paster.isTrusted
    let driveFolder = Backup.driveFolder()

    var onCombo: (HotKey.Combo) -> Bool = { _ in true }
    var onBackup: () -> Void = {}
    var onRestore: () -> Void = {}
    var onClear: () -> Void = {}
    var onTutorial: () -> Void = {}

    init() { lastBackup = driveFolder.flatMap(Backup.lastBackupDate(at:)) }

    func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch { loginError = String(localized: "Impossibile modificare l’apertura al login: \(error.localizedDescription)") }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if on, SMAppService.mainApp.status == .requiresApproval {
            loginError = String(localized: "Consenti Trove in Impostazioni di Sistema › Generali › Elementi login ed estensioni.")
        }
    }

    private var monitor: Any?

    func startRecording() {
        recording = true
        hotKeyError = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self else { return e }
            if e.keyCode == 53 { self.stopRecording(); return nil } // esc annulla
            guard let c = HotKey.Combo(event: e) else { self.hotKeyError = String(localized: "Combina un tasto con ⌘ ⌥ o ⌃."); return nil }
            if self.onCombo(c) { self.combo = c; c.save() } else { self.hotKeyError = String(localized: "\(c.display) è già usata da un’altra app.") }
            self.stopRecording()
            return nil
        }
    }

    func stopRecording() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

struct SettingsView: View {
    @ObservedObject var s: SettingsModel
    @ObservedObject var app: AppModel
    @State private var confirmRestore = false
    @State private var confirmClear = false
    @AppStorage("panelEdge") private var panelEdge = PanelEdge.left
    @AppStorage("appearance") private var appearance = "dark"

    var body: some View {
        Form {
            Section {
                LabeledContent("Apri Trove") {
                    HStack {
                        Button(s.recording ? String(localized: "Premi la nuova scorciatoia…") : s.combo.display) {
                            s.recording ? s.stopRecording() : s.startRecording()
                        }
                        .frame(minWidth: 150)
                        if s.combo != .default { Button("Ripristina ⇧⌘V") { if s.onCombo(.default) { s.combo = .default; s.combo.save() } } }
                    }
                }
                if let e = s.hotKeyError { Text(e).foregroundStyle(.red).font(.caption) }
                Picker("Posizione del pannello", selection: $panelEdge) {
                    Text("In basso").tag(PanelEdge.bottom)
                    Text("In alto").tag(PanelEdge.top)
                    Text("A sinistra").tag(PanelEdge.left)
                    Text("A destra").tag(PanelEdge.right)
                }
                Picker("Aspetto", selection: $appearance) {
                    Text("Automatico").tag("system")
                    Text("Chiaro").tag("light")
                    Text("Scuro").tag("dark")
                }
                .onChange(of: appearance) { _, v in Theme.applyAppearance(v) }
                Toggle("Apri Trove al login", isOn: Binding(get: { s.launchAtLogin }, set: { s.setLogin($0) }))
                if let e = s.loginError { Text(e).foregroundStyle(.orange).font(.caption) }
                LabeledContent("Incolla nell’app attiva") {
                    if s.trusted { Label("Autorizzato", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                    else {
                        Button("Autorizza in Accessibilità…") {
                            Paster.promptForAccessibility()
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                }
                LabeledContent("Tutorial") { Button("Rivedi il tutorial", action: s.onTutorial) }
            } header: { Label("Generale", systemImage: "gearshape") }
            Section {
                Toggle("Oscura i segreti nelle chat AI", isOn: $s.redactForAI)
                if s.redactForAI, NSPasteboard.general.accessBehavior != .alwaysAllow {
                    Text("Per il controllo anche sui ⌘V fatti a mano, imposta Trove su «Consenti sempre» in Impostazioni di Sistema › Privacy e sicurezza › Incolla da altre app.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: { Label("AI e agenti", systemImage: "sparkles") } footer: {
                Text("Quando incolli in ChatGPT, Claude, Perplexity o Gemini, chiavi API, token, password, carte e IBAN vengono sostituiti da segnaposto come <OPENAI_KEY_1> e compare un avviso. Nei terminali ↩ incolla il testo così com’è. ⌥↩ incolla in qualsiasi app la versione pulita, senza segreti. Le immagini incollate in un terminale diventano il percorso del file.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                if let f = s.driveFolder {
                    LabeledContent("Cartella") {
                        // ponytail: mostra le ultime due cartelle (es. Il mio Drive › Trove), il percorso intero sta nel tooltip
                        Text(f.pathComponents.suffix(2).joined(separator: " › ")).foregroundStyle(.secondary).help(f.path)
                    }
                    Toggle("Backup automatico ogni 24 ore", isOn: $s.autoBackup)
                    LabeledContent("Ultimo backup") {
                        Text(s.lastBackup.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? String(localized: "mai"))
                    }
                    HStack {
                        Button("Esegui backup adesso", action: s.onBackup)
                        Button("Ripristina dal backup…") { confirmRestore = true }.disabled(s.lastBackup == nil)
                    }
                    if let st = s.backupStatus { Text(st).font(.caption).foregroundStyle(.secondary) }
                } else {
                    Text("Google Drive per desktop non trovato. Installalo ed esegui l’accesso: Trove salverà la cronologia nella cartella Il mio Drive/Trove.")
                        .foregroundStyle(.secondary)
                }
            } header: { Label("Backup su Google Drive", systemImage: "externaldrive.badge.icloud") }
            Section {
                LabeledContent("Elementi salvati", value: "\(app.totalCount)")
                LabeledContent("Ricerca per significato") {
                    Text(SemanticTagger.isAvailable ? String(localized: "Attiva (Apple Intelligence, sul dispositivo)") : String(localized: "Solo modello locale: Apple Intelligence non disponibile"))
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Conservazione", value: String(localized: "Per sempre"))
                Toggle("Mostra il titolo dei link copiati", isOn: $s.fetchLinkTitles)
                    .help(String(localized: "Trove apre il link per leggerne il titolo: il sito vede il tuo indirizzo IP. I link con parametri (?…) o credenziali non vengono mai aperti."))
                Button("Cancella cronologia…", role: .destructive) { confirmClear = true }
            } header: { Label("Cronologia", systemImage: "clock.arrow.circlepath") }
            Section {
                Link("Sostieni lo sviluppo di Trove", destination: URL(string: "https://github.com/sponsors/cannoloops")!)
            } header: { Label("Sostieni Trove", systemImage: "heart") }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in s.trusted = Paster.isTrusted }
        .alert("Ripristinare il backup?", isPresented: $confirmRestore) {
            Button("Ripristina e riavvia", role: .destructive, action: s.onRestore)
            Button("Annulla", role: .cancel) {}
        } message: { Text("La cronologia su questo Mac verrà sostituita da quella del backup.") }
        .alert("Cancellare tutta la cronologia?", isPresented: $confirmClear) {
            Button("Cancella", role: .destructive, action: s.onClear)
            Button("Annulla", role: .cancel) {}
        } message: { Text("Gli elementi su questo Mac verranno eliminati. I backup su Google Drive non verranno modificati.") }
    }
}
