import AppKit
import SwiftUI
import TroveCore

/// Pannello che non attiva l'app: l'app sotto resta in primo piano, così ⌘V arriva lì.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let height: CGFloat = 352
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

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 18
        blur.layer?.masksToBounds = true
        let host = NSHostingView(rootView: PanelView(model: model, actions: .init(
            paste: { [weak self] in self?.onPaste($0, $1) },
            copy: { [weak self] in self?.onCopy($0) },
            settings: { [weak self] in self?.onSettings() })))
        host.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: blur.leadingAnchor), host.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            host.topAnchor.constraint(equalTo: blur.topAnchor), host.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
        ])
        panel.contentView = blur
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main!
        let vf = screen.visibleFrame
        let target = NSRect(x: vf.minX + 8, y: vf.minY + 8, width: vf.width - 16, height: Self.height)
        model.resetForOpen()
        panel.setFrame(target.offsetBy(dx: 0, dy: -40), display: false)
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
        case 123: model.move(-1); return true // ←
        case 124: model.move(1); return true // →
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
