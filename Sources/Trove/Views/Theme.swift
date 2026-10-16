import SwiftUI

/// Tipografia in un solo punto: SF Pro per interfaccia e prosa, SF Mono per il codice.
enum Theme {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    static func prose(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { ui(size, weight) }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .monospaced) }
}
