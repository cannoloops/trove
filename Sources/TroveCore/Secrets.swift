import Foundation

/// Rileva chiavi, token, password e dati di pagamento e li sostituisce con segnaposto stabili (`<OPENAI_KEY_1>`).
public enum Secrets {
    public struct Result: Equatable {
        public var text: String
        public var found: [(kind: String, value: String)]
        public static func == (a: Result, b: Result) -> Bool { a.text == b.text && a.found.map(\.value) == b.found.map(\.value) }
    }

    /// (tipo, regex, gruppo da sostituire). L'ordine è la priorità quando due regole coprono lo stesso testo.
    static let rules: [(String, NSRegularExpression, Int)] = [
        ("PRIVATE_KEY", #"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----"#, 0),
        ("ANTHROPIC_KEY", #"\bsk-ant-[A-Za-z0-9_\-]{20,}"#, 0),
        ("OPENAI_KEY", #"\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_\-]{20,}"#, 0),
        ("GITHUB_TOKEN", #"\b(?:gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,})"#, 0),
        ("AWS_KEY", #"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"#, 0),
        ("SLACK_TOKEN", #"\bxox[abprs]-[A-Za-z0-9-]{10,}"#, 0),
        ("GOOGLE_KEY", #"\bAIza[0-9A-Za-z_\-]{35}"#, 0),
        ("STRIPE_KEY", #"\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{16,}"#, 0),
        ("JWT", #"\beyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"#, 0),
        ("PASSWORD", #"(?i)\b[A-Z0-9_]*(?:PASSWORD|PASSWD|SECRET|TOKEN|API_?KEY|ACCESS_KEY)[A-Z0-9_]*\s*[=:]\s*["']?([^\s"'<]{4,})"#, 1),
        ("PASSWORD", #"://[^\s:/@]+:([^\s@/]+)@"#, 1),
        ("CARD", #"\b(?:\d[ -]?){12,18}\d\b"#, 0),
        ("IBAN", #"\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b"#, 0),
    ].map { ($0.0, try! NSRegularExpression(pattern: $0.1), $0.2) }

    public static func redact(_ s: String) -> Result {
        let ns = s as NSString
        var taken: [(NSRange, String)] = []
        for (kind, re, group) in rules {
            for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
                let r = m.range(at: group)
                guard r.location != NSNotFound, !taken.contains(where: { NSIntersectionRange($0.0, r).length > 0 }) else { continue }
                let v = ns.substring(with: r)
                if kind == "CARD", !luhn(v) { continue }
                if kind == "IBAN", !iban(v) { continue }
                taken.append((r, kind))
            }
        }
        taken.sort { $0.0.location < $1.0.location }
        var counters: [String: Int] = [:], names: [String: String] = [:]
        var found: [(String, String)] = []
        for (r, kind) in taken {
            let v = ns.substring(with: r)
            if names[v] == nil {
                counters[kind, default: 0] += 1
                names[v] = "<\(kind)_\(counters[kind]!)>"
                found.append((kind, v))
            }
        }
        let out = NSMutableString(string: s)
        for (r, _) in taken.reversed() { out.replaceCharacters(in: r, with: names[ns.substring(with: r)]!) }
        return Result(text: out as String, found: found)
    }

    public static func contains(_ s: String) -> Bool { !redact(String(s.prefix(20000))).found.isEmpty }

    static func luhn(_ s: String) -> Bool {
        let d = s.compactMap(\.wholeNumberValue)
        guard (13...19).contains(d.count) else { return false }
        let sum = d.reversed().enumerated().reduce(0) { acc, e in
            let x = e.offset % 2 == 1 ? e.element * 2 : e.element
            return acc + (x > 9 ? x - 9 : x)
        }
        return sum % 10 == 0
    }

    static func iban(_ s: String) -> Bool {
        let r = String(s.dropFirst(4) + s.prefix(4))
        var rem = 0
        for ch in r {
            let v = ch.isNumber ? String(ch) : String(Int(ch.asciiValue!) - 55)
            for digit in v { rem = (rem * 10 + digit.wholeNumberValue!) % 97 }
        }
        return rem == 1
    }
}
