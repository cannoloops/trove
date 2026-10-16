import AppKit
import SwiftUI

/// Avviso breve in basso al centro, senza rubare il focus.
@MainActor
enum Toast {
    private static var panel: NSPanel?

    static func show(_ title: String, detail: String) {
        panel?.orderOut(nil)
        let view = VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: "lock.fill").font(Theme.ui(13, .semibold)).foregroundStyle(Color.trove)
            Text(detail).font(Theme.ui(11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .padding(12) // spazio per l'ombra del vetro
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.contentView = host
        if let vf = NSScreen.main?.visibleFrame { p.setFrameOrigin(NSPoint(x: vf.midX - size.width / 2, y: vf.minY + 40)) }
        p.orderFrontRegardless()
        panel = p
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { if panel === p { p.orderOut(nil); panel = nil } }
    }
}
