import AppKit
import Foundation
import Testing
@testable import TroveCore

@Suite struct SearchTests {
    @Test func parseFilters() {
        let q = Query.parse("type:image app:Safari fattura oggi", now: Date(timeIntervalSince1970: 1_000_000))
        #expect(q.kinds == [.image])
        #expect(q.app == "safari")
        #expect(q.text == "fattura")
        #expect(q.since == Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_000_000)))
        #expect(Query.parse("tipo:link settimana").kinds == [.link])
        #expect(Query.parse("tipo:link settimana").since != nil)
        #expect(Query.parse("type:nonsense ciao").text == "type:nonsense ciao")
    }

    @Test func fuzzyTypoFinds() throws {
        let s = try Store(directory: tempDir())
        try s.insert(textItem("apple pie recipe"))
        try s.insert(textItem("banana bread"))
        for typo in ["aple", "appel", "recpie", "APPLE"] {
            let r = Search.run(Query.parse(typo), store: s)
            #expect(r.first?.text == "apple pie recipe", "query \(typo)")
            #expect(!r.contains { $0.text == "banana bread" }, "query \(typo)")
        }
    }

    @Test func exactBeforeWordsBeforeFuzzy() throws {
        let s = try Store(directory: tempDir())
        let now = Date()
        try s.insert(textItem("Fattura Enel di ottobre", at: now.addingTimeInterval(-300)))
        try s.insert(textItem("enel: la fattura arriva domani", at: now.addingTimeInterval(-200)))
        try s.insert(textItem("fatura enell", at: now.addingTimeInterval(-100))) // più recente, ma solo per assonanza
        try s.insert(textItem("banana bread", at: now))
        #expect(Search.run(Query.parse("fattura enel"), store: s).map(\.text)
                == ["Fattura Enel di ottobre", "enel: la fattura arriva domani", "fatura enell"])
        #expect(Search.run(Query.parse("\"fattura enel\""), store: s).map(\.text) == ["Fattura Enel di ottobre"])
    }

    @Test func accentInsensitive() throws {
        let s = try Store(directory: tempDir())
        try s.insert(textItem("perché è così"))
        #expect(Search.run(Query.parse("perche"), store: s).count == 1)
    }

    @Test func filtersByKindAppAndDate() throws {
        let s = try Store(directory: tempDir())
        let old = Date().addingTimeInterval(-86400 * 30)
        try s.insert(textItem("https://apple.com", kind: .link, app: "Safari"))
        try s.insert(textItem("apple notes", app: "Notes"))
        try s.insert(textItem("apple old", app: "Notes", at: old))
        #expect(Search.run(Query.parse("type:link"), store: s).map(\.text) == ["https://apple.com"])
        #expect(Search.run(Query.parse("app:notes apple"), store: s).map(\.text) == ["apple notes", "apple old"])
        #expect(Search.run(Query.parse("apple oggi"), store: s).count == 2)
        #expect(Search.run(Query(text: "", kinds: [.text]), store: s).count == 2)
    }

    @Test func emptyQueryReturnsRecent() throws {
        let s = try Store(directory: tempDir())
        try s.insert(textItem("a", at: Date(timeIntervalSince1970: 1)))
        try s.insert(textItem("b", at: Date(timeIntervalSince1970: 2)))
        #expect(Search.run(Query.parse(""), store: s).map(\.text) == ["b", "a"])
    }

    @Test func expansionTermsMatch() throws {
        let s = try Store(directory: tempDir())
        try s.insert(textItem("visita odontoiatrica martedì"))
        try s.insert(textItem("pizza margherita"))
        let r = Search.run(Query.parse("dentista"), store: s, expansions: ["odontoiatra", "odontoiatrica", "denti"])
        #expect(r.map(\.text) == ["visita odontoiatrica martedì"])
    }

    @Test func ocrReadsImageText() async throws {
        let img = NSImage(size: NSSize(width: 600, height: 120), flipped: false) { r in
            NSColor.white.setFill(); r.fill()
            ("Fattura Enel 4521" as NSString).draw(at: NSPoint(x: 20, y: 40),
                withAttributes: [.font: NSFont.systemFont(ofSize: 44), .foregroundColor: NSColor.black])
            return true
        }
        let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let text = try await Enricher.ocr(cg)
        #expect(text.localizedCaseInsensitiveContains("Fattura"))
        #expect(text.contains("4521"))
    }

    @Test(.enabled(if: SemanticTagger.isAvailable))
    func semanticFindsByMeaning() async throws {
        let s = try Store(directory: tempDir())
        for t in ["Ricordati la visita odontoiatrica martedì alle 15", "Ricetta della pizza margherita con mozzarella",
                  "git push origin main --force", "Meeting with the sales team tomorrow at 10",
                  "Bolletta Enel scadenza 12 novembre"] {
            let id = try s.insert(textItem(t))
            await Enricher.enrich(s.get(id)!, store: s)
        }
        for (q, want) in [("dentista", "odontoiatrica"), ("dentist appointment", "odontoiatrica"),
                          ("riunione commerciale", "sales team"), ("cucina", "pizza"), ("elettricità", "Enel")] {
            let exp = await SemanticTagger.expand(query: q)
            let r = Search.run(Query.parse(q), store: s, expansions: exp)
            let tags = s.all().first { $0.text.contains(want) }?.tags ?? "-"
            #expect(r.first?.text.contains(want) == true, "\(q) → \(r.map(\.text)) exp=\(exp) tags=\(tags)")
        }
    }
}

@Suite struct SemanticImageTests {
    @Test(.enabled(if: SemanticTagger.isAvailable))
    func meaningFindsImageByOCR() async throws {
        let s = try Store(directory: tempDir())
        var img = textItem("700×160", kind: .image); img.hash = "img"
        let id = try s.insert(img)
        s.update(ocr: "Bolletta Enel scadenza 12 novembre", title: nil, embedding: nil, lang: nil, for: id)
        await Enricher.enrich(s.get(id)!, store: s)
        try s.insert(textItem("Ricetta della pizza margherita"))
        let exp = await SemanticTagger.expand(query: "elettricità")
        let r = Search.run(Query.parse("elettricità"), store: s, corpus: s.all(), expansions: exp)
        #expect(r.first?.id == id, "exp=\(exp) tags=\(s.get(id)?.tags ?? "-") r=\(r.map(\.text))")
    }
}
