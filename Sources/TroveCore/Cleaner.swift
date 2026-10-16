import Foundation

/// Pulizia deterministica del testo copiato da terminali e TUI di agenti (Claude Code, Codex…):
/// escape ANSI, cornici e simboli dei TUI, padding a fine riga, rientro comune, righe spezzate dal wrap.
public enum Cleaner {
    public static func needsCleaning(_ s: String) -> Bool { clean(s) != s.trimmingCharacters(in: .newlines) }

    public static func clean(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: "\r\n", with: "\n")
        for p in ansiPatterns { s = s.replacingOccurrences(of: p, with: "", options: .regularExpression) }
        var lines: [String] = []
        var tuiEvidence = false // simboli o padding del TUI: il testo è stato impaginato dal terminale
        var hang = 0            // rientro delle righe di continuazione sotto un simbolo ⏺/⎿
        for var line in s.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty, t.allSatisfy(boxChars.contains) { continue } // bordo della cornice
            line = line.replacingOccurrences(of: #"^\s*[│┃║]\s?"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s*[│┃║]\s*$"#, with: "", options: .regularExpression)
            if let r = line.range(of: #"^\s*[⏺⎿●✻⏵]\s*"#, options: .regularExpression) {
                hang = line.distance(from: line.startIndex, to: r.upperBound)
                line.removeSubrange(r)
                tuiEvidence = true
            } else if hang > 0, line.hasPrefix(String(repeating: " ", count: hang)) {
                line.removeFirst(hang)
            } else if !line.hasPrefix(" ") {
                hang = 0
            }
            if line.range(of: #"\S {2,}$"#, options: .regularExpression) != nil { tuiEvidence = true }
            lines.append(line.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression))
        }
        while lines.first?.isEmpty == true { lines.removeFirst() }
        while lines.last?.isEmpty == true { lines.removeLast() }
        lines = dedent(lines)
        return unwrap(lines, evidence: tuiEvidence).joined(separator: "\n")
    }

    static let ansiPatterns = [
        "\u{1B}\\][^\u{07}\u{1B}]*(?:\u{07}|\u{1B}\\\\)", // OSC (link, titoli)
        "\u{1B}\\[[0-?]*[ -/]*[@-~]",                    // CSI (colori, cursore)
        "\u{1B}[@-Z\\\\-_]",                             // altri escape a 2 byte
    ]
    static let boxChars = Set("─━═╭╮╰╯┌┐└┘├┤┬┴┼│┃║╔╗╚╝")

    static func dedent(_ lines: [String]) -> [String] {
        let indents = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { $0.prefix { $0 == " " || $0 == "\t" }.count }
        guard let common = indents.min(), common > 0 else { return lines }
        return lines.map { $0.count >= common ? String($0.dropFirst(common)) : $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Riunisce le righe spezzate dal terminale: servono almeno due righe "piene" (prova di wrap)
    /// e non si toccano codice indentato, fence, liste, righe con `\` finale o che chiudono una frase.
    static func unwrap(_ lines: [String], evidence: Bool) -> [String] {
        let width = lines.map(\.count).max() ?? 0
        guard width >= 40 else { return lines }
        // solo prosa: il TUI va a capo sugli spazi, quindi una riga spezzata contiene parole
        let full = { (l: String) in l.count >= width - 15 && l.contains(" ") }
        guard lines.filter(full).count >= (evidence ? 1 : 2) else { return lines }
        var out: [String] = []
        var inFence = false
        for line in lines {
            if line.hasPrefix("```") { inFence.toggle(); out.append(line); continue }
            if !inFence, let prev = out.last, full(prev), !prev.hasSuffix("\\"), !line.isEmpty,
               prev.last.map({ !".:;!?".contains($0) }) ?? false,
               !line.hasPrefix(" "), !line.hasPrefix("\t"), !line.hasPrefix("```"),
               line.range(of: #"^([-*+•]|\d+[.)])\s"#, options: .regularExpression) == nil,
               !prev.hasPrefix(" "), !prev.hasPrefix("\t") {
                out[out.count - 1] = prev + " " + line
            } else {
                out.append(line)
            }
        }
        return out
    }
}
