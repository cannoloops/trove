import AppKit
import SwiftUI
import TroveCore

/// Lato dello schermo da cui esce il pannello.
enum PanelEdge: String, CaseIterable {
    case bottom, top, left, right
    static var current: PanelEdge { UserDefaults.standard.string(forKey: "panelEdge").flatMap(PanelEdge.init) ?? .right }
    var isVertical: Bool { self == .left || self == .right }
}

/// Pannello che non attiva l'app: l'app sotto resta in primo piano, così ⌘V arriva lì.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let height: CGFloat = 352
    static let sideWidth: CGFloat = 320
    let panel: KeyPanel
    private let model: AppModel
    private var keyMonitor: Any?
    var onPaste: (ClipItem, PasteMode) -> Void = { _, _ in }
    var onCopy: (ClipItem) -> Void = { _ in }
    var onSettings: () -> Void = {}

    init(model: AppModel) {
        self.model = model
        panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 1200, height: Self.height),
                         styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView], backing: .buffered, defer: false)
        super.init()
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.delegate = self

        // Liquid Glass: il pannello è livello di controllo; le card sopra restano superfici piene.
        let glass = NSGlassEffectView()
        glass.cornerRadius = Theme.panelRadius
        let host = NSHostingView(rootView: PanelView(model: model, actions: .init(
            paste: { [weak self] in self?.onPaste($0, $1) },
            copy: { [weak self] in self?.onCopy($0) },
            settings: { [weak self] in self?.onSettings() })))
        glass.contentView = host
        panel.contentView = glass
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main!
        // visibleFrame esclude già barra dei menu e Dock (se visibile)
        let vf = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let edge = PanelEdge.current
        let target: NSRect, slide: (CGFloat, CGFloat)
        switch edge {
        case .bottom: target = NSRect(x: vf.minX, y: vf.minY, width: vf.width, height: Self.height); slide = (0, -40)
        case .top: target = NSRect(x: vf.minX, y: vf.maxY - Self.height, width: vf.width, height: Self.height); slide = (0, 40)
        case .left: target = NSRect(x: vf.minX, y: vf.minY, width: Self.sideWidth, height: vf.height); slide = (-40, 0)
        case .right: target = NSRect(x: vf.maxX - Self.sideWidth, y: vf.minY, width: Self.sideWidth, height: vf.height); slide = (40, 0)
        }
        model.resetForOpen()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.setFrame(reduceMotion ? target : target.offsetBy(dx: slide.0, dy: slide.1), display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
        installKeyMonitor()
    }

    func hide() {
        guard panel.isVisible else { return }
        model.previewing = false
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        // una popover di anteprima è una finestra figlia: non chiudere per quella
        if model.previewing { return }
        hide()
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, self.panel.isVisible else { return e }
            return self.handle(e) ? nil : e
        }
    }

    /// true = evento consumato.
    private func handle(_ e: NSEvent) -> Bool {
        let f = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch Int(e.keyCode) {
        case 53: // esc
            if model.previewing { model.previewing = false } else if !model.query.isEmpty { model.query = "" } else { hide() }
            return true
        // orizzontale: ←→ scorrono le card; verticale: ↑↓ (←→ restano al campo di ricerca)
        case 123 where !PanelEdge.current.isVertical, 126 where PanelEdge.current.isVertical: model.move(-1); return true
        case 124 where !PanelEdge.current.isVertical, 125 where PanelEdge.current.isVertical: model.move(1); return true
        case 36, 76: // ↩
            if let it = model.selected { onPaste(it, f.contains(.option) ? .agent : f.contains(.shift) ? .plain : .normal) }
            return true
        case 49 where model.query.isEmpty || model.previewing: // spazio
            model.previewing.toggle(); return true
        case 51 where f.contains(.command): // ⌘⌫
            if let it = model.selected { model.delete(it) }
            return true
        default: break
        }
        if f.contains(.command), let c = e.charactersIgnoringModifiers {
            if let n = Int(c), (1...9).contains(n), model.results.count >= n { onPaste(model.results[n - 1], f.contains(.shift) ? .plain : .normal); return true }
            if c == "c", let it = model.selected, !(panel.firstResponder is NSTextView && hasTextSelection) { onCopy(it); return true }
            if c == "," { onSettings(); return true }
        }
        return false
    }

    private var hasTextSelection: Bool { ((panel.firstResponder as? NSTextView)?.selectedRange().length ?? 0) > 0 }
}
