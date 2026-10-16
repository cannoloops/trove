import Testing
@testable import TroveCore

@Suite struct SemanticTaggerTests {
    @Test func parseStripsLabelsAndDuplicates() {
        let r = SemanticTagger.parse("topic: art, synonyms: painting, Canvas, canvas,\n- brush.\nKeywords: colore")
        #expect(r == ["art", "painting", "canvas", "brush", "colore"])
    }
}
