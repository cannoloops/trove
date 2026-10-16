import Testing
@testable import TroveCore

@Suite struct EmbedderTests {
    // le VM di CI non hanno gli asset di embedding di NaturalLanguage
    @Test(.enabled(if: Embedder.embed("prova") != nil)) func concurrentEmbedIsSafe() async {
        await withTaskGroup(of: Int.self) { g in
            for i in 0..<64 { g.addTask { Embedder.embed("frase numero \(i) per il test di concorrenza")?.vec.count ?? 0 } }
            for await n in g { #expect(n > 0) }
        }
    }
}
