import Foundation
import Testing
@testable import TroveCore

@Suite struct LinkTitleTests {
    private func fetches(_ s: String) -> Bool { Enricher.titleURL(for: s, enabled: true) != nil }

    @Test func neverOpensLocalNetwork() {
        for u in ["http://localhost:8080/", "http://127.0.0.1/admin", "http://192.168.1.1/", "http://10.0.0.5/x", "http://172.20.3.4/",
                  "http://169.254.169.254/latest/meta-data", "http://[::1]/", "http://[fd00::1]/", "http://router/", "http://nas.local/",
                  "http://100.64.0.1/", "file:///etc/passwd", "ftp://example.com/"] {
            #expect(!fetches(u), "\(u)")
        }
    }

    @Test func skipsTokensInPath() {
        #expect(!fetches("https://example.com/reset/8f3a9c1e2b7d4a6f0c11"))
        #expect(!fetches("https://app.example.com/magic/eyJhbGciOiJIUzI1NiJ9abc"))
    }

    @Test func stillFetchesOrdinaryPages() {
        for u in ["https://developer.apple.com/documentation/foundationmodels", "https://www.youtube.com/watch/dQw4w9WgXcQ",
                  "https://it.wikipedia.org/wiki/Bolletta_elettrica", "https://172.217.0.1/", "https://example.com/blog/my-2024-post-title"] {
            #expect(fetches(u), "\(u)")
        }
    }
}
