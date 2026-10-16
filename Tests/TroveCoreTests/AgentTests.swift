import Foundation
import Testing
@testable import TroveCore

@Suite struct CleanerTests {
    @Test func stripsAnsi() {
        #expect(Cleaner.clean("\u{1B}[31mred\u{1B}[0m text\u{1B}]8;;https://x\u{07}link\u{1B}]8;;\u{07}") == "red textlink")
    }
    @Test func trimsPaddingAndDedents() {
        #expect(Cleaner.clean("    foo   \n      bar  \n") == "foo\n  bar")
    }
    @Test func removesTuiFrameAndBullets() {
        #expect(Cleaner.clean("╭──────────╮\n│ hello    │\n╰──────────╯") == "hello")
        #expect(Cleaner.clean("⏺ Ho aggiornato il file.\n  ⎿  Updated Store.swift") == "Ho aggiornato il file.\nUpdated Store.swift")
    }
    @Test func unwrapsHardWrappedProse() {
        let wrapped = """
        Every visual line break becomes a hard newline in the clipboard and this is
        really annoying when you paste the answer into another document because it
        breaks.

        Second paragraph.
        """
        #expect(Cleaner.clean(wrapped) == "Every visual line break becomes a hard newline in the clipboard and this is really annoying when you paste the answer into another document because it breaks.\n\nSecond paragraph.")
    }
    @Test func keepsBackslashContinuationsAndCode() {
        let cmd = "docker run --rm -it \\\n  -v $(pwd):/app \\\n  node:22 npm test"
        #expect(Cleaner.clean(cmd) == cmd)
        let py = "def f(x):\n    if x:\n        return 1\n    return 0"
        #expect(Cleaner.clean(py) == py)
    }
    @Test func unwrapsClaudeCodeBulletParagraph() {
        let raw = "\u{1B}[32m⏺\u{1B}[0m Ho aggiornato Store.swift e aggiunto i test per il ripristino: ora la history locale resta intatta anche se il   \n  backup è corrotto.   \n  ⎿  Updated Sources/TroveCore/Store.swift"
        #expect(Cleaner.clean(raw) == "Ho aggiornato Store.swift e aggiunto i test per il ripristino: ora la history locale resta intatta anche se il backup è corrotto.\nUpdated Sources/TroveCore/Store.swift")
    }

    @Test func doesNotJoinConfigLines() {
        let env = "OPENAI_API_KEY=sk-proj-abcDEF1234567890abcdef1234567890XYZ\nDATABASE_URL=postgres://admin:s3cr3t@db.local/app"
        #expect(Cleaner.clean(env) == env)
        #expect(!Cleaner.needsCleaning(env))
    }

    @Test func cleanTextIsUnchanged() {
        #expect(!Cleaner.needsCleaning("Ciao, a domani."))
        #expect(Cleaner.needsCleaning("\u{1B}[1mbold\u{1B}[0m"))
    }
}

@Suite struct SecretsTests {
    @Test func redactsCommonKeys() {
        let s = """
        OPENAI_API_KEY=sk-proj-abcDEF1234567890abcdef1234567890XYZ
        anthropic: sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_abcd
        token ghp_1234567890abcdefghijABCDEFGHIJ123456 e di nuovo ghp_1234567890abcdefghijABCDEFGHIJ123456
        aws AKIAIOSFODNN7EXAMPLE
        DB_PASSWORD="hunter2-super"
        postgres://admin:s3cr3t@db.example.com:5432/app
        """
        let r = Secrets.redact(s)
        #expect(!r.text.contains("sk-proj-abc"))
        #expect(!r.text.contains("sk-ant-api03"))
        #expect(!r.text.contains("ghp_1234"))
        #expect(!r.text.contains("AKIAIOSFODNN7EXAMPLE"))
        #expect(!r.text.contains("hunter2"))
        #expect(!r.text.contains("s3cr3t"))
        #expect(r.text.contains("DB_PASSWORD=\"<PASSWORD_1>\""))
        #expect(r.text.contains("postgres://admin:<PASSWORD_2>@db.example.com"))
        #expect(r.text.components(separatedBy: "<GITHUB_TOKEN_1>").count == 3) // stesso segreto → stesso segnaposto
        #expect(r.found.count == 6)
    }
    @Test func redactsJwtPrivateKeyCardAndIban() {
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        let key = "-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAA\n-----END OPENSSH PRIVATE KEY-----"
        let r = Secrets.redact("bearer \(jwt)\n\(key)\ncarta 4111 1111 1111 1111\nIBAN IT60X0542811101000000123456")
        #expect(r.text == "bearer <JWT_1>\n<PRIVATE_KEY_1>\ncarta <CARD_1>\nIBAN <IBAN_1>")
    }
    @Test func noFalsePositives() {
        for s in ["Vado a sciare, sk-8 è il mio skate", "commit 3f9a2b1c4d5e6f708192a3b4c5d6e7f8091a2b3c",
                  "numero ordine 1234 5678 9012 3456", "password dimenticata? clicca qui", "ID 550e8400-e29b-41d4-a716-446655440000"] {
            #expect(Secrets.redact(s).found.isEmpty, "\(s)")
        }
    }
}

@Suite struct AgentPasteTests {
    @Test func imageBecomesPathWithoutSpaces() throws {
        let dir = tempDir(), cache = tempDir().appendingPathComponent("NoSpaces")
        let blob = dir.appendingPathComponent("abc.png")
        try Data([1, 2, 3]).write(to: blob)
        let p = try AgentPaste.imagePath(blob: blob, cacheDir: cache)
        #expect(p.lastPathComponent == "trove-abc.png")
        #expect(try Data(contentsOf: p) == Data([1, 2, 3]))
    }
    @Test func textIsCleanedAndRedacted() {
        let r = AgentPaste.text("\u{1B}[32m  export GITHUB_TOKEN=ghp_1234567890abcdefghijABCDEFGHIJ123456\u{1B}[0m  ")
        #expect(r == "export GITHUB_TOKEN=<GITHUB_TOKEN_1>")
    }
}
