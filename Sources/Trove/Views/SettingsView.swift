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
    @Published var autoBackup = UserDefaults.standard.object(forKey: "autoBackup") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoBackup, forKey: "autoBackup") }
    }
    @Published var backupStatus: String?
    @Published var lastBackup: Date?
    @Published var trusted = Paster.isTrusted
    let driveFolder = Backup.driveFolder()

    var onCombo: (HotKey.Combo) -> Bool = { _ in true }
    var onBackup: () -> Void = {}
    var onRestore: () -> Void = {}
    var onClear: () -> Void = {}

    init() { lastBackup = driveFolder.flatMap(Backup.lastBackupDate(at:)) }

    func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch { loginError = "Non riesco a cambiare l’avvio al login: \(error.localizedDescription)" }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if on, SMAppService.mainApp.status == .requiresApproval {
            loginError = "Approva Trove in Impostazioni di Sistema › Generali › Elementi di login."
        }
    }

    private var monitor: Any?

    func startRecording() {
        recording = true
        hotKeyError = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self else { return e }
            if e.keyCode == 53 { self.stopRecording(); return nil } // esc annulla
            guard let c = HotKey.Combo(event: e) else { self.hotKeyError = "Usa almeno ⌘, ⌥ o ⌃ insieme a un tasto."; return nil }
            if self.onCombo(c) { self.combo = c; c.save() } else { self.hotKeyError = "\(c.display) è già usata da un’altra app." }
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

    var body: some View {
        Form {
            Section("Generale") {
                LabeledContent("Apri Trove") {
                    HStack {
                        Button(s.recording ? "Premi la nuova scorciatoia…" : s.combo.display) {
                            s.recording ? s.stopRecording() : s.startRecording()
                        }
                        .frame(minWidth: 150)
                        if s.combo != .default { Button("Ripristina ⇧⌘V") { if s.onCombo(.default) { s.combo = .default; s.combo.save() } } }
                    }
                }
                if let e = s.hotKeyError { Text(e).foregroundStyle(.red).font(.caption) }
                Toggle("Avvia Trove al login", isOn: Binding(get: { s.launchAtLogin }, set: { s.setLogin($0) }))
                if let e = s.loginError { Text(e).foregroundStyle(.orange).font(.caption) }
                LabeledContent("Incolla nell’app attiva") {
                    if s.trusted { Label("Permesso concesso", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                    else {
                        Button("Concedi accesso Accessibilità") {
                            Paster.promptForAccessibility()
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                }
            }
            Section("Backup su Google Drive") {
                if let f = s.driveFolder {
                    LabeledContent("Cartella") { Text(f.path).font(.caption).textSelection(.enabled).lineLimit(2) }
                    Toggle("Backup automatico ogni 24 ore", isOn: $s.autoBackup)
                    LabeledContent("Ultimo backup") {
                        Text(s.lastBackup.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "mai")
                    }
                    HStack {
                        Button("Esegui backup ora", action: s.onBackup)
                        Button("Ripristina dal backup…") { confirmRestore = true }.disabled(s.lastBackup == nil)
                    }
                    if let st = s.backupStatus { Text(st).font(.caption).foregroundStyle(.secondary) }
                } else {
                    Text("Google Drive per desktop non trovato. Installalo e accedi: Trove salverà la history in Il mio Drive/Trove.")
                        .foregroundStyle(.secondary)
                }
            }
            Section("History") {
                LabeledContent("Elementi salvati", value: "\(app.totalCount)")
                LabeledContent("Ricerca per significato") {
                    Text(SemanticTagger.isAvailable ? "Attiva (Apple Intelligence on-device)" : "Solo embedding locali: Apple Intelligence non disponibile")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Conservazione", value: "Per sempre")
                Button("Cancella tutta la history…", role: .destructive) { confirmClear = true }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in s.trusted = Paster.isTrusted }
        .alert("Ripristinare il backup?", isPresented: $confirmRestore) {
            Button("Ripristina e riavvia", role: .destructive, action: s.onRestore)
            Button("Annulla", role: .cancel) {}
        } message: { Text("La history attuale su questo Mac verrà sostituita da quella del backup.") }
        .alert("Cancellare tutta la history?", isPresented: $confirmClear) {
            Button("Cancella", role: .destructive, action: s.onClear)
            Button("Annulla", role: .cancel) {}
        } message: { Text("Gli elementi locali vengono eliminati. I backup su Google Drive restano.") }
    }
}
