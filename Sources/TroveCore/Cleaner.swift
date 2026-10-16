import Foundation

/// Pulizia deterministica del testo copiato da terminali e TUI di agenti (Claude Code, Codex…):
/// escape ANSI, cornici e simboli dei TUI, padding a fine riga, rientro comune, righe spezzate dal wrap.
/// Senza prove di impaginazione da terminale il testo non viene toccato: un falso positivo cambia ciò che si incolla.
public enum Cleaner {
    public static func needsCleaning(_ s: String, fromTerminal: Bool = false) -> Bool {
        clean(s, fromTerminal: fromTerminal) != s
    }

    /// `fromTerminal`: il testo è stato copiato da un'app terminale (vale come prova di impaginazione).
    public static func clean(_ raw: String, fromTerminal: Bool = false) -> String {
        var s = raw.replacingOccurrences(of: "\r\n", with: "\n")
        for p in ansiPatterns { s = s.replacingOccurrences(of: p, with: "", options: .regularExpression) }
        let original = s.components(separatedBy: "\n")
        let framed = original.contains { $0.range(of: #"^\s*[│┃║].*[│┃║]\s*$"#, options: .regularExpression) != nil }
            || original.contains { $0.contains(where: cornerChars.contains) && isBoxLine($0) }
        let marked = original.contains { $0.range(of: marker, options: .regularExpression) != nil }
        let padded = original.contains { $0.range(of: #"\S {3,}$"#, options: .regularExpression) != nil }
        guard fromTerminal || s != raw || framed || marked || padded else { return raw }

        var lines: [String] = []
        var hang = 0 // rientro delle righe di continuazione sotto un simbolo ⏺/⎿
        for var line in original {
            if framed, isBoxLine(line) { continue }
            if framed, line.range(of: #"^\s*[│┃║].*[│┃║]\s*$"#, options: .regularExpression) != nil {
                line = line.replacingOccurrences(of: #"^\s*[│┃║]\s?"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\s*[│┃║]\s*$"#, with: "", options: .regularExpression)
            }
            if let r = line.range(of: marker, options: .regularExpression) {
                hang = line.distance(from: line.startIndex, to: r.upperBound)
                line.removeSubrange(r)
            } else if hang > 0, line.hasPrefix(String(repeating: " ", count: hang)) {
                line.removeFirst(hang)
            } else if !line.hasPrefix(" ") {
                hang = 0
            }
            lines.append(line.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression))
        }
        while lines.first?.isEmpty == true { lines.removeFirst() }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return unwrap(dedent(lines)).joined(separator: "\n")
    }

    static let ansiPatterns = [
        "\u{1B}\\][^\u{07}\u{1B}]*(?:\u{07}|\u{1B}\\\\)", // OSC (link, titoli)
        "\u{1B}\\[[0-?]*[ -/]*[@-~]",                    // CSI (colori, cursore)
        "\u{1B}[@-Z\\\\-_]",                             // altri escape a 2 byte
    ]
    static let marker = #"^\s*[⏺⎿✻⏵]\s*"#
    static let boxChars = Set("─━═╭╮╰╯┌┐└┘├┤┬┴┼│┃║╔╗╚╝")
    static let cornerChars = Set("╭╮╰╯┌┐└┘╔╗╚╝")

    static func isBoxLine(_ l: String) -> Bool {
        let t = l.trimmingCharacters(in: .whitespaces)
        return !t.isEmpty && t.allSatisfy(boxChars.contains) && t.contains(where: cornerChars.contains)
    }

    static func dedent(_ lines: [String]) -> [String] {
        let indents = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { $0.prefix { $0 == " " || $0 == "\t" }.count }
        guard let common = indents.min(), common > 0 else { return lines }
        return lines.map { $0.count >= common ? String($0.dropFirst(common)) : $0.trimmingCharacters(in: .whitespaces) }
    }

    static let commands: Set<String> = ["git", "npm", "npx", "pnpm", "yarn", "cd", "ls", "cat", "echo", "export", "sudo", "brew", "docker",
        "kubectl", "swift", "python", "python3", "pip", "uv", "uvx", "curl", "make", "cargo", "go", "node", "rm", "mv", "cp", "mkdir", "claude", "codex"]

    /// Righe che non vanno mai unite: log con data/ora, comandi, chiavi YAML, markdown strutturale.
    static func isStructural(_ l: String) -> Bool {
        if l.range(of: #"^(\d{2,4}[-/:.]|\$ |[#>|\[{]|[-*+•] |\d+[.)] |[\w.-]+:\s|```)"#, options: .regularExpression) != nil { return true }
        return commands.contains(String(l.split(separator: " ").first ?? ""))
    }

    /// Riunisce le righe di prosa spezzate dal terminale (il TUI va a capo sugli spazi).
    static func unwrap(_ lines: [String]) -> [String] {
        let width = lines.map(\.count).max() ?? 0
        guard width >= 40 else { return lines }
        let full = { (l: String) in l.count >= width - 15 && l.contains(" ") && !isStructural(l) }
        var out: [String] = []
        var inFence = false
        for line in lines {
            if line.hasPrefix("```") { inFence.toggle(); out.append(line); continue }
            if !inFence, let prev = out.last, full(prev), !prev.hasSuffix("\\"), !line.isEmpty,
               prev.last.map({ !".:;!?".contains($0) }) ?? false,
               !line.hasPrefix(" "), !line.hasPrefix("\t"), !isStructural(line), !prev.hasPrefix(" "), !prev.hasPrefix("\t") {
                out[out.count - 1] = prev + " " + line
            } else {
                out.append(line)
            }
        }
        return out
    }
}
