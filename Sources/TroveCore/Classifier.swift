import CryptoKit
import Foundation

public enum Classifier {
    public static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func kind(forText raw: String) -> ClipKind {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if rgb(fromColorText: s) != nil { return .color }
        if !s.contains(where: \.isWhitespace), let u = URL(string: s), let sc = u.scheme?.lowercased(),
           ["http", "https"].contains(sc), u.host != nil { return .link }
        return .text
    }

    /// Colore da `#RGB`, `#RRGGBB` o `rgb(r, g, b)`; componenti 0…1.
    public static func rgb(fromColorText raw: String) -> (r: Double, g: Double, b: Double)? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.hasPrefix("#") {
            var hex = String(s.dropFirst())
            guard [3, 6].contains(hex.count), hex.allSatisfy(\.isHexDigit) else { return nil }
            if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
            let v = Int(hex, radix: 16)!
            return (Double(v >> 16 & 0xff) / 255, Double(v >> 8 & 0xff) / 255, Double(v & 0xff) / 255)
        }
        if s.hasPrefix("rgb("), s.hasSuffix(")") {
            let parts = s.dropFirst(4).dropLast().split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count == 3, parts.allSatisfy({ (0...255).contains($0) }) else { return nil }
            return (parts[0] / 255, parts[1] / 255, parts[2] / 255)
        }
        return nil
    }
}
