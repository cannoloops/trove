import Foundation
import Testing
@testable import TroveCore

@Suite struct RedactionGapTests {
    private func kinds(_ s: String, pii: Bool = false) -> [String] { Secrets.redact(s, pii: pii).found.map(\.kind) }

    @Test func formatsThatUsedToSlipThrough() {
        #expect(Secrets.redact("password: hunter22").text == "password: <PASSWORD_1>")
        #expect(Secrets.redact("PGPASSWORD=s3cretpw psql").text == "PGPASSWORD=<PASSWORD_1> psql")
        #expect(Secrets.redact("pg_dump --password s3cretpw db").text == "pg_dump --password <PASSWORD_1> db")
        #expect(Secrets.redact("cli --token=abcd1234").text == "cli --token=<PASSWORD_1>")
        #expect(Secrets.redact("mysql -u root -ps3cretpw app").text == "mysql -u root -p<PASSWORD_1> app")
        #expect(kinds("-----BEGIN PGP PRIVATE KEY BLOCK-----\nlQOYBF\n-----END PGP PRIVATE KEY BLOCK-----") == ["PRIVATE_KEY"])
        #expect(kinds("https://hooks.slack.com/services/T0000/B0000/XXXXXXXXXXXXXXXXXXXXXXXX") == ["WEBHOOK"])
        #expect(kinds("https://discord.com/api/webhooks/123456789/abcdefghijklmnopqrstuvwxyz012345") == ["WEBHOOK"])
        // costruita a runtime: scritta per intero, la push protection di GitHub la blocca come chiave vera
        #expect(kinds(["SG", String(repeating: "a", count: 22), String(repeating: "b", count: 43)].joined(separator: ".")) == ["SENDGRID_KEY"])
        #expect(kinds("GOCSPX-abcdefghijklmnopqrstuvwxyz12") == ["GOOGLE_KEY"])
        #expect(Secrets.redact("DefaultEndpointsProtocol=https;AccountKey=abcdEFGHijklMNOPqrstUVWXyz0123456789+/ab==;").text
                == "DefaultEndpointsProtocol=https;AccountKey=<AZURE_KEY_1>;")
        #expect(Secrets.redact("Authorization: Basic dXNlcjpwYXNzd29yZA==").text == "Authorization: Basic <TOKEN_1>")
    }

    @Test func proseAndCommandsStayUntouched() {
        #expect(kinds("Password: required") == [])          // prosa: solo lettere
        #expect(kinds("mkdir -p build/release") == [])      // -p fuori da mysql
        #expect(kinds("git push --force-with-lease") == [])
        #expect(kinds("TOKENS=5") == [])
        #expect(kinds("scrivimi a mario.rossi@example.com", pii: true) == ["EMAIL"])
    }

    /// Le regex devono restare lineari: input patologici grandi quanto il limite in pochi secondi (prima: minuti).
    @Test func pathologicalInputIsFast() {
        for s in [String(repeating: "a", count: Secrets.limit), String(repeating: "a.", count: Secrets.limit / 2),
                  String(repeating: "1", count: Secrets.limit), String(repeating: "A_", count: Secrets.limit / 2),
                  String(repeating: "a@", count: Secrets.limit / 2)] {
            let t = Date()
            _ = Secrets.redact(s, pii: true)
            #expect(Date().timeIntervalSince(t) < 3, "\(s.prefix(4))… troppo lento")
        }
    }

    @Test func reportsTruncation() {
        #expect(!Secrets.redact("x").truncated)
        #expect(Secrets.redact(String(repeating: "a", count: Secrets.limit + 1)).truncated)
    }
}
