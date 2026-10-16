import AppKit
import SwiftUI

/// Tipografia, raggi e colori in un solo punto: SF Pro per interfaccia e prosa, SF Mono per il codice.
enum Theme {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    static func prose(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { ui(size, weight) }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .monospaced) }

    /// Raggi: il pannello contiene le card, le card contengono badge e campi. L'anello di selezione è concentrico alla card.
    static let panelRadius: CGFloat = 22
    static let cardRadius: CGFloat = 14
    static let fieldRadius: CGFloat = 10
    static let chipRadius: CGFloat = 5
}

extension Color {
    /// Chiaro / scuro: segue l'aspetto di sistema.
    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light })
    }

    /// Oro di Trove: l'unico accento. Solo wordmark, selezione, focus.
    static let trove = adaptive(light: NSColor(red: 0.72, green: 0.52, blue: 0.10, alpha: 1), dark: NSColor(red: 0.91, green: 0.71, blue: 0.29, alpha: 1))
    /// Superficie della card: contenuto, non vetro.
    static let cardSurface = adaptive(light: NSColor(white: 1, alpha: 0.92), dark: NSColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 0.94))
    /// Fondo del blocco codice, appena più scuro della card.
    static let codeSurface = adaptive(light: NSColor(white: 0, alpha: 0.035), dark: NSColor(white: 0, alpha: 0.22))
    static let hairline = Color(nsColor: .separatorColor)
    // Sintassi alla Xcode: rosa per le parole chiave, rosso/verde acqua per le stringhe, grigio per i commenti.
    static let codeKeyword = adaptive(light: NSColor(red: 0.61, green: 0.14, blue: 0.58, alpha: 1), dark: NSColor(red: 0.99, green: 0.37, blue: 0.64, alpha: 1))
    static let codeString = adaptive(light: NSColor(red: 0.77, green: 0.10, blue: 0.09, alpha: 1), dark: NSColor(red: 0.99, green: 0.42, blue: 0.36, alpha: 1))
    static let codeComment = Color(nsColor: .secondaryLabelColor)
    static let codeText = Color(nsColor: .labelColor)
}
