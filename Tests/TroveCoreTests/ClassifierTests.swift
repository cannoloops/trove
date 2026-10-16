import Testing
@testable import TroveCore

@Suite struct ClassifierTests {
    @Test func detectsLink() {
        #expect(Classifier.kind(forText: "https://apple.com") == .link)
        #expect(Classifier.kind(forText: "  http://x.it/a?b=1 \n") == .link)
        #expect(Classifier.kind(forText: "vai su https://apple.com") == .text)
    }
    @Test func detectsColor() {
        #expect(Classifier.kind(forText: "#ff8800") == .color)
        #expect(Classifier.kind(forText: "#F80") == .color)
        #expect(Classifier.kind(forText: "rgb(10, 20, 30)") == .color)
        #expect(Classifier.kind(forText: "#ff88") == .text)
    }
    @Test func plainText() { #expect(Classifier.kind(forText: "ciao") == .text) }
    @Test func parsesColor() {
        let c = Classifier.rgb(fromColorText: "#ff8000")!
        #expect(c.r == 1 && c.g > 0.5 && c.g < 0.51 && c.b == 0)
    }
}
