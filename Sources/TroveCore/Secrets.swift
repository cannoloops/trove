import Foundation

/// Rileva chiavi, token, password e dati di pagamento e li sostituisce con segnaposto stabili (`<OPENAI_KEY_1>`).
public enum Secrets {
    public struct Result: Equatable {
        public var text: String
        public var found: [(kind: String, value: String)]
        /// Il testo supera `limit`: oltre quel punto non è stato analizzato.
        public var truncated = false
        public static func == (a: Result, b: Result) -> Bool { a.text == b.text && a.found.map(\.value) == b.found.map(\.value) }
    }

    /// (tipo, regex, gruppo da sostituire). L'ordine è la priorità quando due regole coprono lo stesso testo.
    /// Regole strette apposta: un falso positivo cambia ciò che l'utente incolla.
    static let rules: [(String, NSRegularExpression, Int)] = [
        ("PRIVATE_KEY", #"-----BEGIN [A-Z ]*PRIVATE KEY(?: BLOCK)?-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY(?: BLOCK)?-----"#, 0),
        ("ANTHROPIC_KEY", #"\bsk-ant-[A-Za-z0-9_\-]{20,}"#, 0),
        ("OPENAI_KEY", #"\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_\-]{20,}"#, 0),
        ("GITHUB_TOKEN", #"\b(?:gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,})"#, 0),
        ("GITLAB_TOKEN", #"\bglpat-[A-Za-z0-9_\-]{20,}"#, 0),
        ("HF_TOKEN", #"\bhf_[A-Za-z0-9]{30,}"#, 0),
        ("NPM_TOKEN", #"\bnpm_[A-Za-z0-9]{36}"#, 0),
        ("AWS_KEY", #"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"#, 0),
        ("SLACK_TOKEN", #"\bxox[abprs]-[A-Za-z0-9-]{10,}"#, 0),
        ("GOOGLE_KEY", #"\bAIza[0-9A-Za-z_\-]{35}|\bya29\.[A-Za-z0-9_\-]{20,}|\bGOCSPX-[A-Za-z0-9_\-]{28}"#, 0),
        ("SENDGRID_KEY", #"\bSG\.[A-Za-z0-9_\-]{22}\.[A-Za-z0-9_\-]{43}"#, 0),
        ("WEBHOOK", #"https://hooks\.slack\.com/services/[A-Za-z0-9/_\-]{20,}|https://(?:ptb\.|canary\.)?discord(?:app)?\.com/api/webhooks/\d+/[A-Za-z0-9_\-]{20,}"#, 0),
        ("AZURE_KEY", #"\b(?:AccountKey|SharedAccessKey)=([A-Za-z0-9+/]{30,}=*)"#, 1),
        ("STRIPE_KEY", #"\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{16,}"#, 0),
        ("JWT", #"\beyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"#, 0),
        ("TOKEN", #"\bBearer\s+([A-Za-z0-9._~+/\-]{16,}=*)"#, 1),
        ("TOKEN", #"(?i)\bAuthorization:\s*Basic\s+([A-Za-z0-9+/]{8,}=*)"#, 1),
        // variabili d'ambiente in maiuscolo che *finiscono* con la parola chiave: DB_PASSWORD=…, GITHUB_TOKEN=…, PGPASSWORD=…
        ("PASSWORD", #"\b[A-Z0-9_]{0,40}(?:PASSWORD|PASSWD|SECRET|TOKEN|API_?KEY|ACCESS_KEY)\s*[=:]\s*["']?([^\s"'<>(),;\[\]{}]{4,})"#, 1),
        // chiavi JSON/YAML con valore tra virgolette: "password": "…"
        ("PASSWORD", #"(?i)["']?\b(?:password|passwd|secret|client_secret|api_?key|access_?token|auth_?token)["']?\s*[:=]\s*["']([^"'\s]{4,})["']"#, 1),
        // YAML senza virgolette, riga intera: `password: hunter22`. Il valore deve avere una cifra o un simbolo (non prosa)
        ("PASSWORD", #"(?im)^\s*["']?(?:password|passwd|pwd|secret|client_secret|api_?key|access_?token|auth_?token)["']?\s*:\s*((?=[^\s"'#]*[^A-Za-z\s"'#])[^\s"'#]{4,})\s*$"#, 1),
        // riga di comando: --password x, --token=x; mysql -pSEGRETO
        ("PASSWORD", #"(?<!\S)--(?:password|passwd|token|api-key|secret)(?:=|\s+)([^\s"'\-][^\s"']{3,})"#, 1),
        ("PASSWORD", #"\b(?:mysql|mysqldump|mariadb)\b[^\n]{0,200}?\s-p([^\s"']{4,})"#, 1),
        ("PASSWORD", #"://[^\s:/@]{1,64}:([^\s/]{1,128})@[^\s@/]+"#, 1),
        ("CARD", #"\b\d{4}(?:[ -]\d{4}){3}(?:\d{1,3})?\b|\b3[47]\d{2}[ -]\d{6}[ -]\d{5}\b"#, 0),
        ("IBAN", #"\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){2,7}(?: ?[A-Z0-9]{1,4})?\b"#, 0),
    ].map { ($0.0, try! NSRegularExpression(pattern: $0.1), $0.2) }

    /// Dati personali italiani (regole e checksum dalla rete regex di rizzo-pii), solo con `pii: true`.
    /// Dopo i segreti: `admin:pass@host` resta PASSWORD, non EMAIL.
    static let piiRules: [(String, NSRegularExpression, Int)] = [
        // il lookbehind fa partire il match solo all'inizio di una sequenza: senza, un testo lungo senza @ costa O(n²)
        ("EMAIL", #"(?<![A-Za-z0-9._%+\-])[A-Za-z0-9._%+\-]{1,64}@[A-Za-z0-9.\-]{1,253}\.[A-Za-z]{2,24}\b"#, 0),
        // forma con omocodia (cifre sostituite da LMNPQRSTUV): il checksum decide
        ("CF", #"\b[A-Za-z]{6}[\dLMNPQRSTUVlmnpqrstuv]{2}[A-Za-z][\dLMNPQRSTUVlmnpqrstuv]{2}[A-Za-z][\dLMNPQRSTUVlmnpqrstuv]{3}[A-Za-z]\b"#, 0),
        ("PIVA", #"(?<!\d)\d{11}(?!\d)"#, 0),
        ("PHONE", #"(?<![\w.])(?:\+39[\s.\-]?)?(?:3\d{2}[\s.\-]?\d{3}[\s.\-]?\d{3,4}|0\d{1,3}[\s.\-]?\d{5,8})(?!\w)"#, 0),
    ].map { ($0.0, try! NSRegularExpression(pattern: $0.1), $0.2) }

    /// Oltre questo numero di caratteri il testo non viene analizzato (`Result.truncated`): le regex sono lineari, il tetto evita sorprese.
    public static let limit = 1_000_000

    public static func redact(_ s: String, pii: Bool = false) -> Result {
        let ns = s as NSString
        let scan = NSRange(location: 0, length: min(ns.length, limit))
        var taken: [(NSRange, String)] = []
        for (kind, re, group) in pii ? rules + piiRules : rules {
            for m in re.matches(in: s, range: scan) {
                let r = m.range(at: group)
                guard r.location != NSNotFound, !taken.contains(where: { NSIntersectionRange($0.0, r).length > 0 }) else { continue }
                let v = ns.substring(with: r)
                if kind == "CARD", !luhn(v) { continue }
                if kind == "IBAN", !iban(v.replacingOccurrences(of: " ", with: "")) { continue }
                if kind == "OPENAI_KEY", !v.contains(where: \.isNumber) { continue } // es. .sk-loading-spinner-container
                if kind == "PASSWORD", v.allSatisfy(\.isNumber) { continue }            // TTL, porte, conteggi
                if kind == "CF", !cf(v.uppercased()) { continue }
                if kind == "PIVA", !piva(v) { continue }
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
        return Result(text: out as String, found: found, truncated: ns.length > limit)
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

    static func piva(_ s: String) -> Bool {
        let d = s.compactMap(\.wholeNumberValue)
        guard d.count == 11 else { return false }
        let t = (0..<10).reduce(0) { acc, i in
            let x = i % 2 == 0 ? d[i] : d[i] * 2
            return acc + (x > 9 ? x - 9 : x)
        }
        return (10 - t % 10) % 10 == d[10]
    }

    /// Carattere di controllo del codice fiscale: valori tabellari per le posizioni dispari, A=0…Z=25 / 0…9 per le pari.
    static func cf(_ s: String) -> Bool {
        let odd = [1, 0, 5, 7, 9, 13, 15, 17, 19, 21, 2, 4, 18, 20, 11, 3, 6, 8, 12, 14, 16, 10, 22, 25, 24, 23] // A…Z (0…9 come A…J)
        let c = Array(s.utf8)
        guard c.count == 16 else { return false }
        var t = 0
        for (i, ch) in c.prefix(15).enumerated() {
            let v = ch >= 65 ? Int(ch) - 65 : Int(ch) - 48 // lettera o cifra → 0…25 / 0…9
            t += i % 2 == 0 ? odd[v] : v
        }
        return Int(c[15]) - 65 == t % 26
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
