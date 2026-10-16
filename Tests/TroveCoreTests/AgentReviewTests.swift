import Foundation
import Testing
@testable import TroveCore

@Suite struct SecretsReviewTests {
    @Test func ordinaryCodeAndProseAreNotSecrets() {
        for s in ["token = request.headers.get(\"x\")", "max_tokens: 1024", "TOKEN_TTL=3600", "Il token: scade domani",
                  "password: dimenticata", "tokenizer = AutoTokenizer.from_pretrained(name)", ".sk-loading-spinner-container { }",
                  "ordine 4000000000000002", "chiamami al 3331234567"] {
            #expect(Secrets.redact(s).found.isEmpty, "\(s)")
        }
    }
    @Test func catchesMoreRealFormats() {
        let s = """
        {"password": "hunter2!", "api_key": "abcd1234efgh"}
        Authorization: Bearer abcDEF123456ghiJKL789mno
        IBAN IT60 X054 2811 1010 0000 0123 456
        glpat-AbCdEfGhIjKlMnOpQrSt hf_abcdefghijklmnopqrstuvwxyzABCDEF npm_abcdefghijklmnopqrstuvwxyz0123456789
        https://user:p@ss@host.example.com/x
        """
        let r = Secrets.redact(s)
        for leak in ["hunter2", "abcd1234efgh", "abcDEF123456", "X054 2811", "glpat-AbC", "hf_abc", "npm_abc", "p@ss"] {
            #expect(!r.text.contains(leak), "\(leak) → \(r.text)")
        }
        #expect(r.text.contains("@host.example.com"))
    }
    @Test func fastOnPathologicalInput() {
        let s = String(repeating: "token_", count: 7000) + "=x"
        let t0 = Date()
        _ = Secrets.redact(s)
        #expect(Date().timeIntervalSince(t0) < 0.2)
    }
}

@Suite struct CleanerReviewTests {
    @Test func leavesOrdinaryTextAlone() {
        let samples = [
            "2026-10-16 12:00:01 INFO server started on port 8080 with 4 workers ready\n2026-10-16 12:00:02 INFO connected to database at localhost:5432 pool=10\n2026-10-16 12:00:03 WARN cache miss ratio above threshold, consider tuning",
            "● primo punto dell'elenco con un po' di testo in più per allungarlo\n● secondo punto dell'elenco con un po' di testo in più per allungarlo",
            "Titolo\n══════",
            "src\n│   ├── main.swift\n│   └── util.swift",
            "riga con a capo forzato markdown  \nseconda riga",
            "    let a = 1\n    let b = 2",
            "name: trove-ci-pipeline-for-the-macos-clipboard-manager-app\nruns-on: macos-latest-xlarge-runner-with-extra-memory-please",
        ]
        for s in samples {
            #expect(Cleaner.clean(s) == s, "\(s)")
            #expect(!Cleaner.needsCleaning(s), "\(s)")
        }
    }
    @Test func terminalSourceUnwrapsProseButNotCommands() {
        let prose = "Every visual line break becomes a hard newline in the clipboard and this is\nreally annoying when you paste the answer into another document because it\nbreaks."
        #expect(Cleaner.clean(prose, fromTerminal: true) == "Every visual line break becomes a hard newline in the clipboard and this is really annoying when you paste the answer into another document because it breaks.")
        #expect(Cleaner.clean(prose) == prose) // senza prove di terminale non si tocca
        let script = "git add Sources/TroveCore/Cleaner.swift Sources/TroveCore/Secrets.swift Tests/x.swift\ngit commit -m \"fix: pulizia testo solo con prove di terminale e niente join\"\ngit push origin trove-v1"
        #expect(Cleaner.clean(script, fromTerminal: true) == script)
    }
}
