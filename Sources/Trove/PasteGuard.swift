import AppKit
import ApplicationServices
import SwiftUI
import TroveCore

/// ⌘V manuale in una chat AI (app o sito nel browser): se ciò che è stato incollato contiene segreti o dati personali,
/// propone vicino al cursore di sostituirlo con la versione oscurata (⌘Z + ⌘V).
@MainActor
enum PasteGuard {
    static let browsers: Set<String> = [
        "com.apple.Safari", "com.google.Chrome", "company.thebrowser.Browser", "com.brave.Browser", "com.microsoft.edgemac", "org.mozilla.firefox",
    ]
    static let aiHosts = ["claude.ai", "chatgpt.com", "chat.openai.com", "gemini.google.com", "perplexity.ai"]

    /// I ⌘V simulati da Trove non devono far partire il popup.
    static var ignoreUntil = Date.distantPast
    private static var panel: NSPanel?
    /// Ultimo tasto o clic visto: se arriva dopo il ⌘V, ⌘Z non annullerebbe più l'incolla.
    private static var lastEvent = Date.distantPast

    /// `onWrite`: chiamato dopo aver scritto sul pasteboard, per non ricatturare la versione oscurata nella history.
    static func start(onWrite: @escaping () -> Void) {
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { e in
            MainActor.assumeIsolated { handle(e, onWrite: onWrite) }
        }
    }

    private static func handle(_ e: NSEvent, onWrite: @escaping () -> Void) {
        hide() // un tasto o un clic dopo l'incolla: ⌘Z non annullerebbe più l'incolla
        lastEvent = Date()
        guard e.type == .keyDown, e.keyCode == 9, e.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
              Date() > ignoreUntil, Paster.redactForAI,
              // leggere gli appunti dopo il ⌘V di un'altra app fa chiedere il permesso da macOS a ogni incolla
              NSPasteboard.general.accessBehavior == .alwaysAllow,
              let app = NSWorkspace.shared.frontmostApplication, let bid = app.bundleIdentifier,
              Paster.aiApps.contains(bid) || browsers.contains(bid),
              let text = NSPasteboard.general.string(forType: .string) else { return }
        let pid = app.processIdentifier
        let ax = AXUIElementCreateApplication(pid)
        // Chromium costruisce l'albero AX (URL, cursore) solo se un client lo chiede
        AXUIElementSetAttributeValue(ax, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        let change = NSPasteboard.general.changeCount
        let started = Date()
        Task {
            // fuori dal main thread: un testo enorme non blocca Trove (né la cattura degli appunti)
            let r = await Task.detached(priority: .userInitiated) { Secrets.redact(text, pii: true) }.value
            guard !r.found.isEmpty else { return }
            // a incolla avvenuto il cursore è dopo il testo
            try? await Task.sleep(for: .seconds(max(0, 0.25 - Date().timeIntervalSince(started))))
            guard lastEvent < started, Paster.aiApps.contains(bid) || onAIHost(ax) else { return }
            show(count: r.found.count, at: caret(ax) ?? fromCocoa(NSEvent.mouseLocation)) {
                // l'utente può aver cambiato app (o Spazio) con il popup aperto: ⌘Z e ⌘V finirebbero altrove
                guard NSPasteboard.general.changeCount == change,
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(r.text, forType: .string) // resta negli appunti: i ⌘V successivi sono già oscurati
                onWrite()
                ignoreUntil = Date() + 1
                key(6) // ⌘Z
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { key(9) } // ⌘V
            }
        }
    }

    private static func key(_ code: CGKeyCode) {
        let src = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down)
            e?.flags = .maskCommand
            e?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    // MARK: Accessibilità

    private static func attr(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
    }

    private static func focused(_ app: AXUIElement) -> AXUIElement? {
        attr(app, kAXFocusedUIElementAttribute).map { $0 as! AXUIElement }
    }

    /// Risale dal campo con il focus fino all'area web e ne legge l'URL.
    private static func onAIHost(_ app: AXUIElement) -> Bool {
        var el = focused(app)
        for _ in 0..<60 {
            guard let e = el else { return false }
            if let url = attr(e, kAXURLAttribute) as? URL, let host = url.host {
                return aiHosts.contains { host == $0 || host.hasSuffix("." + $0) }
            }
            el = attr(e, kAXParentAttribute).map { $0 as! AXUIElement }
        }
        return false
    }

    /// Rettangolo del cursore di testo in coordinate AX (origine in alto a sinistra).
    private static func caret(_ app: AXUIElement) -> CGRect? {
        guard let e = focused(app), let range = attr(e, kAXSelectedTextRangeAttribute) else { return nil }
        var v: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(e, kAXBoundsForRangeParameterizedAttribute as CFString, range, &v) == .success,
              let v, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        var r = CGRect.zero
        AXValueGetValue(v as! AXValue, .cgRect, &r)
        return r.height > 0 ? r : nil
    }

    private static func fromCocoa(_ p: NSPoint) -> CGRect {
        CGRect(x: p.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - p.y, width: 0, height: 0)
    }

    // MARK: popup

    private static func show(count: Int, at caret: CGRect, onRedact: @escaping () -> Void) {
        hide()
        // superficie piena e pulsanti disegnati a mano: il vetro sbiadisce sulle pagine chiare
        // e i pulsanti di sistema sembrano disattivati in un pannello che non è mai key
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        let view = HStack(spacing: 12) {
            Image(systemName: "lock.fill").foregroundStyle(Color.trove)
            Text(count == 1 ? String(localized: "Oscurare 1 dato sensibile?") : String(localized: "Oscurare \(count) dati sensibili?"))
                .foregroundStyle(.primary)
            Button { hide(); onRedact() } label: {
                Text(String(localized: "Oscura")).foregroundStyle(.black)
                    .padding(.horizontal, 12).padding(.vertical, 5).background(Color.trove, in: Capsule())
            }.buttonStyle(.plain)
            Button { hide() } label: {
                Text(String(localized: "No")).foregroundStyle(.primary)
                    .padding(.horizontal, 12).padding(.vertical, 5).background(Color.primary.opacity(0.1), in: Capsule())
            }.buttonStyle(.plain)
        }
        .font(Theme.ui(13, .semibold))
        .padding(.leading, 14).padding(.trailing, 8).padding(.vertical, 8)
        .background(Color.cardSurface, in: shape)
        .overlay(shape.strokeBorder(Color.hairline))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        .padding(12) // spazio per l'ombra
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        // un pannello che non diventa key: il focus resta nella chat, dove andranno ⌘Z e ⌘V
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        p.level = .statusBar
        p.isOpaque = false
        p.hasShadow = false // l'ombra è quella SwiftUI: quella della finestra, calcolata sul bordo trasparente, viene seghettata
        p.backgroundColor = .clear
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.contentView = host
        // sotto il cursore, dentro lo schermo
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        var origin = NSPoint(x: caret.minX - 12, y: top - caret.maxY - size.height)
        if let vf = (NSScreen.screens.first { $0.frame.contains(origin) } ?? NSScreen.main)?.visibleFrame {
            if origin.y < vf.minY { origin.y = top - caret.minY } // niente spazio sotto: sopra il cursore
            origin.x = min(max(origin.x, vf.minX), vf.maxX - size.width)
        }
        p.setFrameOrigin(origin)
        p.orderFrontRegardless()
        panel = p
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { if panel === p { hide() } }
    }

    private static func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
