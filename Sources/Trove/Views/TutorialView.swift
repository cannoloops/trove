import AppKit
import SwiftUI

/// Tutorial al primo avvio, riapribile da Impostazioni: una scena animata per ogni idea di Trove. ← → per scorrere.
struct TutorialView: View {
    let combo: String
    @State var page = 0
    let onDone: () -> Void
    @State private var forward = true
    @State private var trusted = Paster.isTrusted
    /// Scene ferme sul fotogramma finale (snapshot per README e sito).
    var frozen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var still: Bool { frozen || reduceMotion }
    private let count = 6
    private var last: Bool { page == count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                EllipticalGradient(colors: [Color.trove.opacity(0.14), .clear], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                scene.id(page).transition(slide)
            }
            .frame(height: 300)
            .clipped()
            VStack(spacing: 8) {
                Text(title).font(Theme.ui(22, .bold))
                Group {
                    if last { permission } else {
                        Text(text).font(Theme.prose(13)).foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center).frame(maxWidth: 520).fixedSize(horizontal: false, vertical: true)
            }
            .id(page).transition(slide)
            .padding(.horizontal, 24)
            Spacer(minLength: 12)
            footer
        }
        .padding(.top, 28).padding(.bottom, 20)
        .frame(width: 680, height: 500)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in trusted = Paster.isTrusted }
    }

    @ViewBuilder private var scene: some View {
        switch page {
        case 0: OrbitScene(combo: combo, still: still)
        case 1: PasteScene(combo: combo, still: still)
        case 2: SearchScene(still: still)
        case 3: CleanScene(still: still)
        case 4: AgentScene(still: still)
        default: WhyScene()
        }
    }

    private var title: LocalizedStringKey {
        switch page {
        case 0: "Tutto ciò che copi, ritrovato."
        case 1: "Trova e incolla, senza mouse."
        case 2: "Cerca come ricordi, non come hai scritto."
        case 3: "⌥↩ incolla la versione pulita."
        case 4: "Pronto per chat AI e terminale."
        default: "Cosa cambia con Trove"
        }
    }

    private var text: LocalizedStringKey {
        switch page {
        case 0: "Trove ricorda testo, link, immagini, file e colori, con l’app da cui arrivano. Lo apri sopra qualsiasi app con \(combo)."
        case 1: "\(PanelEdge.current.isVertical ? "↑ ↓" : "← →") per scegliere, ↩ per incollare nell’app che stavi usando. ⇧↩ incolla come testo semplice (da un’immagine, il testo riconosciuto), ⌘1…⌘9 i primi risultati. Il lato da cui esce il pannello si sceglie in Impostazioni."
        case 2: "Trova per parole, per significato e per il testo dentro le immagini, tutto sul Mac. Filtri come type:image, app:Safari e oggi restringono il campo."
        case 3: "Toglie i residui del terminale e sostituisce chiavi API, password, carte, IBAN, codici fiscali, email e telefoni con segnaposto come <OPENAI_KEY_1>."
        default: "Incollando con Trove in ChatGPT, Claude, Perplexity e Gemini i segreti spariscono da soli. Con ⌘V, anche nel browser, Trove propone di oscurarli. In un terminale un’immagine diventa il percorso del file."
        }
    }

    @ViewBuilder private var permission: some View {
        if trusted {
            Label("Accessibilità concessa: Trove può incollare nell’app attiva.", systemImage: "checkmark.circle.fill")
                .font(Theme.ui(12)).foregroundStyle(.green)
        } else {
            VStack(spacing: 6) {
                Text("Per incollare nell’app attiva Trove ha bisogno del permesso Accessibilità.")
                    .font(Theme.prose(13)).foregroundStyle(.secondary)
                Button("Concedi accesso Accessibilità") {
                    Paster.promptForAccessibility()
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Salta", action: onDone).buttonStyle(.plain).foregroundStyle(.secondary)
                .keyboardShortcut(.cancelAction).opacity(last ? 0 : 1)
            Spacer()
            if page > 0 { Button("Indietro") { go(page - 1) }.keyboardShortcut(.leftArrow, modifiers: []) }
            Button(last ? "Inizia" : "Avanti") { last ? onDone() : go(page + 1) }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).tint(.trove)
        }
        .overlay {
            HStack(spacing: 6) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule().fill(i == page ? Color.trove : Color.secondary.opacity(0.3))
                        .frame(width: i == page ? 18 : 6, height: 6)
                        .contentShape(Rectangle().inset(by: -4))
                        .onTapGesture { go(i) }
                }
            }
            .accessibilityHidden(true)
        }
        // → senza modificatori: un bottone non può avere due scorciatoie
        .background { Button("") { go(page + 1) }.keyboardShortcut(.rightArrow, modifiers: []).opacity(0).accessibilityHidden(true) }
        .controlSize(.large)
        .padding(.horizontal, 24)
    }

    private func go(_ i: Int) {
        guard i != page, (0..<count).contains(i) else { return }
        forward = i > page
        withAnimation(still ? .easeInOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.18)) { page = i }
    }

    private var slide: AnyTransition {
        still ? .opacity : .asymmetric(insertion: .offset(x: forward ? 60 : -60).combined(with: .opacity),
                                       removal: .offset(x: forward ? -60 : 60).combined(with: .opacity))
    }
}

// MARK: scene

/// Gli elementi copiati orbitano attorno al wordmark, in prospettiva.
private struct OrbitScene: View {
    let combo: String, still: Bool
    private let icons = ["doc.text", "link", "photo", "paintpalette", "doc", "chevron.left.forwardslash.chevron.right", "textformat"]

    var body: some View {
        TimelineView(.animation(paused: still)) { ctx in
            let t = still ? 0 : ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(icons.indices, id: \.self) { i in
                    let a = t * 0.4 + Double(i) / Double(icons.count) * 2 * .pi
                    let depth = (sin(a) + 1) / 2 // 0 dietro, 1 davanti
                    Image(systemName: icons[i]).font(.system(size: 18, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(width: 46, height: 46)
                        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous).strokeBorder(Color.hairline, lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        .scaleEffect(0.7 + 0.35 * depth)
                        .opacity(0.4 + 0.6 * depth)
                        .offset(x: cos(a) * 210, y: sin(a) * 75)
                        .zIndex(depth)
                }
                VStack(spacing: 12) {
                    Text(verbatim: "trove").font(.system(size: 64, weight: .bold)).foregroundStyle(Color.trove)
                    Key(combo, active: true)
                }
                .zIndex(0.5)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Scorciatoia, pannello, selezione, ↩: la card scelta vola nell'app. Il pannello esce dal lato scelto in Impostazioni.
private struct PasteScene: View {
    let combo: String, still: Bool
    private let edge = PanelEdge.current
    private let items: [(String, LocalizedStringKey, LocalizedStringKey)] = [
        ("doc.text", "Visita dal dentista martedì alle 15", "Note"), ("link", "developer.apple.com", "Safari"),
        ("terminal", "git push origin main", "Terminale"), ("paintpalette", "#E8B44A", "Figma"),
    ]

    var body: some View {
        PhaseAnimator(still ? [2] : [0, 1, 2, 3, 4]) { p in
            ZStack {
                panel(p).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align(edge))
                keys(p).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align(opposite))
            }
            .padding(.horizontal, 40).padding(.vertical, 18)
        } animation: { p in .spring(duration: 0.45, bounce: 0.2).delay(p == 0 ? 0.9 : 0.6) }
        .accessibilityHidden(true)
    }

    private func panel(_ p: Int) -> some View {
        let layout = edge.isVertical ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
        // a pannello chiuso è spostato verso il suo lato, come quando esce dallo schermo
        let away: CGFloat = p == 0 ? 30 : 0
        return layout {
            ForEach(items.indices, id: \.self) { i in
                let chosen = i == 2 && p == 4
                card(i, selected: i == p - 1 || (i == 2 && p >= 3))
                    .offset(x: chosen && edge.isVertical ? (edge == .left ? 90 : -90) : 0,
                            y: chosen && !edge.isVertical ? (edge == .bottom ? -80 : 80) : 0)
                    .opacity(chosen ? 0 : 1)
            }
        }
        .padding(edge.isVertical ? 10 : 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous).strokeBorder(Color.hairline, lineWidth: 0.5))
        .opacity(p == 0 ? 0 : 1)
        .offset(x: edge == .left ? -away : edge == .right ? away : 0, y: edge == .bottom ? away : edge == .top ? -away : 0)
    }

    @ViewBuilder private func card(_ i: Int, selected: Bool) -> some View {
        let (icon, text, app) = items[i]
        if edge.isVertical {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).frame(width: 18)
                Text(text).font(Theme.ui(11, .medium)).lineLimit(1)
                Spacer(minLength: 4)
                Text(app).font(Theme.ui(9)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).frame(width: 230, height: 44)
            .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous).strokeBorder(Color.hairline, lineWidth: 0.5))
            .overlay(RoundedRectangle(cornerRadius: Theme.fieldRadius + 3, style: .continuous)
                .strokeBorder(Color.trove, lineWidth: 2).padding(-3).opacity(selected ? 1 : 0))
            .scaleEffect(selected ? 1.03 : 1)
        } else {
            Mini(icon: icon, text: text, app: app, selected: selected)
        }
    }

    private func keys(_ p: Int) -> some View {
        let layout = edge.isVertical ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            Key(combo, active: p == 0)
            Key(edge.isVertical ? "↑ ↓" : "← →", active: p == 2 || p == 3)
            Key("↩", active: p == 4)
        }
    }

    private var opposite: PanelEdge {
        switch edge { case .left: .right; case .right: .left; case .top: .bottom; case .bottom: .top }
    }

    private func align(_ e: PanelEdge) -> Alignment {
        switch e { case .left: .leading; case .right: .trailing; case .top: .top; case .bottom: .bottom }
    }
}

/// Si digita "ricevuta": trova la fattura per significato e lo screenshot per il testo che contiene.
private struct SearchScene: View {
    let still: Bool

    var body: some View {
        let q = String(localized: "ricevuta")
        let phases: [Int] = still ? [q.count] : Array(0...q.count)
        PhaseAnimator(phases) { n in frame(q, n) } animation: { n -> Animation in
            let pause: Double = n == 0 ? 2.6 : n == q.count ? 0.15 : 0.11
            return .easeOut(duration: 0.25).delay(pause)
        }
        .accessibilityHidden(true)
    }

    private func frame(_ q: String, _ n: Int) -> some View {
        let done = n == q.count
        return VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                Text(verbatim: String(q.prefix(n))).font(Theme.ui(14))
                Rectangle().fill(Color.trove).frame(width: 1.5, height: 16).padding(.leading, -4)
                Spacer()
                Label("anche per significato", systemImage: "sparkles").font(Theme.ui(10, .medium))
                    .foregroundStyle(Color.trove).opacity(done ? 1 : 0)
            }
            .padding(.horizontal, 10).frame(width: 440, height: 34)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous))
            HStack(spacing: 10) {
                Mini(icon: "doc.text", text: "Fattura Enel n. 4471 · 84,20 €", app: "Mail", selected: done, badge: done ? "per significato" : nil)
                Mini(icon: "photo", text: "RICEVUTA DI PAGAMENTO", app: "Screenshot", selected: done, badge: done ? "testo nell’immagine" : nil, image: true)
                Mini(icon: "chevron.left.forwardslash.chevron.right", text: "func greet(_ name: String)", app: "Xcode", dim: done)
                Mini(icon: "link", text: "apple.com/it/iphone", app: "Safari", dim: done)
            }
            HStack(spacing: 8) {
                ForEach(["type:image", "app:Safari", String(localized: "oggi")], id: \.self) { Key($0) }
            }
            .opacity(0.8)
        }
    }
}

/// Lo stesso testo prima e dopo ⌥↩: via i residui del terminale, segreti al posto dei segnaposto.
private struct CleanScene: View {
    let still: Bool

    var body: some View {
        PhaseAnimator(still ? [true] : [false, true]) { clean in
            VStack(spacing: 18) {
                HStack(spacing: 10) {
                    Text(clean ? "Incollato con ⌥↩" : "Copiato").font(Theme.ui(11, .semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Key("⌥↩", active: clean)
                }
                VStack(alignment: .leading, spacing: 6) {
                    line(clean ? "Updated Store.swift" : "⏺ Updated Store.swift")
                    line(clean ? "2 files changed" : "  ⎿  2 files changed")
                    line("OPENAI_API_KEY=", clean ? "<OPENAI_KEY_1>" : "sk-proj-4f9QxT2b81LmZ0a71", hot: clean)
                    line("IBAN ", clean ? "<IBAN_1>" : "IT60 X054 2811 1010 0000 0123 456", hot: clean)
                    line("cc: ", clean ? "<EMAIL_1>" : "mario.rossi@example.com", hot: clean)
                }
                .padding(14).frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                .background(Color.codeSurface, in: RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous).strokeBorder(clean ? Color.trove.opacity(0.6) : Color.hairline, lineWidth: clean ? 1 : 0.5))
                Label("\(3) segreti nascosti con segnaposto", systemImage: "lock.fill")
                    .font(Theme.ui(11, .medium)).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .opacity(clean ? 1 : 0).offset(y: clean ? 0 : 10)
            }
            .frame(width: 440)
        } animation: { clean in .spring(duration: 0.6, bounce: 0.2).delay(clean ? 1.4 : 2.4) }
        .accessibilityHidden(true)
    }

    private func line(_ head: String, _ tail: String = "", hot: Bool = false) -> some View {
        Text("\(Text(verbatim: head))\(Text(verbatim: tail).foregroundStyle(hot ? Color.trove : Color.codeText))")
            .font(Theme.mono(12)).foregroundStyle(Color.codeText).lineLimit(1)
    }
}

/// ⌘V in una chat AI nel browser: Trove propone di oscurare il segreto. In un terminale l'immagine diventa un percorso.
private struct AgentScene: View {
    let still: Bool

    var body: some View {
        PhaseAnimator(still ? [2] : [0, 1, 2]) { p in
            HStack(spacing: 16) {
                FakeWindow(title: "claude.ai") { chat(p) }
                FakeWindow(title: "Terminale") { terminal(p >= 1) }.environment(\.colorScheme, .dark)
            }
        } animation: { p in .spring(duration: 0.55, bounce: 0.25).delay(p == 0 ? 2.4 : p == 1 ? 1.0 : 1.6) }
        .accessibilityHidden(true)
    }

    private func chat(_ p: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Spacer(); Key("⌘V", active: p == 1) }
            Spacer(minLength: 0)
            // lo stesso popup che compare vicino al cursore
            HStack(spacing: 6) {
                Image(systemName: "lock.fill").foregroundStyle(Color.trove)
                Text("Oscurare 1 dato sensibile?")
                Spacer(minLength: 0)
                Text("Oscura").foregroundStyle(.black).padding(.horizontal, 8).padding(.vertical, 3).background(Color.trove, in: Capsule())
                Text("No").padding(.horizontal, 8).padding(.vertical, 3).background(Color.primary.opacity(0.1), in: Capsule())
            }
            .font(Theme.ui(9, .semibold)).padding(7)
            .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.hairline))
            .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
            .opacity(p == 1 ? 1 : 0).offset(y: p == 1 ? 0 : 6)
            VStack(alignment: .leading, spacing: 3) {
                Text("Perché fallisce?").opacity(p >= 1 ? 1 : 0)
                Text("\(Text(verbatim: "ANTHROPIC_API_KEY=").foregroundStyle(Color.codeText))\(Text(verbatim: p == 2 ? "<ANTHROPIC_KEY_1>" : "sk-ant-api03-x8Fq2…").foregroundStyle(p == 2 ? Color.trove : Color.codeText))")
                    .font(Theme.mono(10)).opacity(p >= 1 ? 1 : 0)
            }
            .font(Theme.ui(11)).padding(8).frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func terminal(_ pasted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "~/trove % claude").foregroundStyle(.secondary)
            HStack(spacing: 0) {
                Text(verbatim: "> ")
                Text(verbatim: "~/Library/Caches/…/paste/8f3a.png").foregroundStyle(Color.trove).opacity(pasted ? 1 : 0)
            }
            Spacer(minLength: 0)
        }
        .font(Theme.mono(10))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [.teal, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 70, height: 46).overlay(Image(systemName: "photo").foregroundStyle(.white))
                .offset(y: pasted ? 10 : 60).scaleEffect(pasted ? 0.2 : 1).opacity(pasted ? 0 : 1)
        }
    }
}

/// Le quattro differenze, a cascata.
private struct WhyScene: View {
    @State private var shown = false
    private let tiles: [(String, LocalizedStringKey, LocalizedStringKey)] = [
        ("lock.laptopcomputer", "Resta sul tuo Mac", "Niente account né cloud. Il backup su Google Drive è facoltativo."),
        ("sparkle.magnifyingglass", "Una ricerca che capisce", "Per significato e dentro le immagini, on-device con Apple Intelligence."),
        ("wand.and.sparkles", "Pensato per chi usa l’AI", "Segreti e dati personali oscurati prima di finire in una chat, anche nel browser."),
        ("chevron.left.forwardslash.chevron.right", "Gratis e open source", "Licenza MIT: il codice è su GitHub, da leggere e migliorare."),
    ]

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow { tile(0); tile(1) }
            GridRow { tile(2); tile(3) }
        }
        .onAppear { shown = true }
    }

    private func tile(_ i: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tiles[i].0).font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.trove).frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(tiles[i].1).font(Theme.ui(13, .semibold))
                Text(tiles[i].2).font(Theme.ui(11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14).frame(width: 290, height: 84, alignment: .topLeading)
        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).strokeBorder(Color.hairline, lineWidth: 0.5))
        .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 16)
        .animation(.spring(duration: 0.5, bounce: 0.2).delay(Double(i) * 0.08), value: shown)
        .accessibilityElement(children: .combine)
    }
}

// MARK: pezzi

private struct Key: View {
    let text: String
    var active = false
    init(_ text: String, active: Bool = false) { self.text = text; self.active = active }

    var body: some View {
        Text(verbatim: text).font(Theme.ui(13, .semibold))
            .foregroundStyle(active ? Color.trove : .secondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(active ? Color.trove : Color.hairline, lineWidth: active ? 1.5 : 0.5))
            .scaleEffect(active ? 1.08 : 1)
    }
}

/// Card in miniatura, con lo stesso anello di selezione del pannello.
private struct Mini: View {
    let icon: String
    let text: LocalizedStringKey
    let app: LocalizedStringKey
    var selected = false
    var dim = false
    var badge: LocalizedStringKey?
    var image = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            Text(text).font(Theme.ui(11, .medium)).lineLimit(3)
            Spacer(minLength: 0)
            if let badge {
                Text(badge).font(Theme.ui(9, .semibold)).foregroundStyle(.black)
                    .padding(.horizontal, 5).padding(.vertical, 2).background(Color.trove, in: Capsule())
            }
            Text(app).font(Theme.ui(9)).opacity(0.7)
        }
        .foregroundStyle(image ? Color.white : Color.primary)
        .padding(10)
        .frame(width: 112, height: 124, alignment: .topLeading)
        .background {
            let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            if image { shape.fill(LinearGradient(colors: [.teal, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)) }
            else { shape.fill(Color.cardSurface) }
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).strokeBorder(Color.hairline, lineWidth: 0.5))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius + 3, style: .continuous)
            .strokeBorder(Color.trove, lineWidth: 2).padding(-3).opacity(selected ? 1 : 0))
        .opacity(dim ? 0.3 : 1)
        .scaleEffect(selected ? 1.04 : 1)
    }
}

private struct FakeWindow<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0.opacity(0.85)).frame(width: 8, height: 8) }
                Spacer()
                Text(title).font(Theme.ui(10, .semibold)).foregroundStyle(.secondary)
                Spacer()
                Color.clear.frame(width: 34, height: 1)
            }
            .padding(9)
            content.padding(.horizontal, 12).padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 290, height: 200)
        .background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
    }
}
