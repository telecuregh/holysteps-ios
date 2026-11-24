import XCTest
@testable import HolySteps

final class BibleTests: XCTestCase {
    private func sample() throws -> Bible.Text {
        let json = """
        {"id":"T","name":"Test","books":[
          {"n":"Genesis","d":"Génesis","c":[["In the beginning God created the heaven and the earth.","And the earth was without form."]]},
          {"n":"Psalms","d":"Salmos","c":[["Blessed is the man."],["Why do the heathen rage?"]]},
          {"n":"John","d":"San Juan","c":[["In the beginning was the Word."],["x"],["For God so loved the world, that he gave his only begotten Son.","For God sent not his Son."]]},
          {"n":"1 Corinthians","d":"1 Corintios","c":[["a"],["b"],["c"],["d"],["e"],["f"],["g"],["h"],["i"],["j"],["k"],["l"],["Charity suffereth long, and is kind."]]}
        ]}
        """
        return try Bible.parse(Data(json.utf8))
    }

    func testFold() {
        XCTAssertEqual(Bible.fold("Génesis"), "genesis")
        XCTAssertEqual(Bible.fold("1 Cor."), "1cor")
        XCTAssertEqual(Bible.foldWords("For God, so loved!"), " for god so loved ")
    }

    func testParseRef() throws {
        let t = try sample()
        XCTAssertEqual(Bible.parseRef("John 3:16", in: t), Bible.Ref(book: "John", ch: 3, v: nil), "a verse past the end opens the chapter")
        XCTAssertEqual(Bible.parseRef("jn 3 1", in: t), Bible.Ref(book: "John", ch: 3, v: 1))
        XCTAssertEqual(Bible.parseRef("Salmos 2", in: t), Bible.Ref(book: "Psalms", ch: 2, v: nil))
        XCTAssertEqual(Bible.parseRef("ps 1", in: t), Bible.Ref(book: "Psalms", ch: 1, v: nil))
        XCTAssertEqual(Bible.parseRef("1 cor 13:1", in: t), Bible.Ref(book: "1 Corinthians", ch: 13, v: 1))
        XCTAssertEqual(Bible.parseRef("gen 1", in: t), Bible.Ref(book: "Genesis", ch: 1, v: nil))
        XCTAssertNil(Bible.parseRef("peace", in: t))
        XCTAssertNil(Bible.parseRef("John 99", in: t))
    }

    func testSearch() throws {
        let t = try sample()
        let hits = Bible.search(t, "loved world")
        XCTAssertEqual(hits.map(\.id), ["John|3|1"])
        XCTAssertEqual(Bible.search(t, "begin").count, 2, "a word matches the start of a word")
        XCTAssertTrue(Bible.search(t, "art").isEmpty, "art must not match heart/earth")
        XCTAssertEqual(t.display("Psalms"), "Salmos")
    }

    func testHighlights() {
        let h = Highlight(book: "John", ch: 3, v: 16, color: .GOLD, text: "For God so loved", translation: "KJV", atMs: 1)
        var list = Highlights.toggle([], h)
        XCTAssertEqual(list.count, 1)
        list = Highlights.withNote(list, book: "John", ch: 3, v: 16, verseText: "", translation: "KJV", note: "  mine  ", nowMs: 2)
        XCTAssertEqual(list.first?.note, "mine")
        list = Highlights.toggle(list, h)                     // same color again: color off, note kept
        XCTAssertEqual(list.first?.noteOnly, true)
        list = Highlights.withNote(list, book: "John", ch: 3, v: 16, verseText: "", translation: "KJV", note: "", nowMs: 3)
        XCTAssertTrue(list.isEmpty, "clearing a note-only verse removes it")
        // Same JSON keys as Android.
        let data = try! JSONEncoder().encode([Highlight(book: "John", ch: 1, v: 1, color: .SKY, text: "t", translation: "KJV", atMs: 5, note: "n", noteOnly: true)])
        let s = String(data: data, encoding: .utf8)!
        XCTAssertTrue(s.contains("\"b\":\"John\"") && s.contains("\"k\":\"SKY\"") && s.contains("\"o\":1"), s)
    }

    func testPlan() {
        XCTAssertEqual(BiblePlan.totalChapters, 1189)
        XCTAssertEqual(BiblePlan.reading(day: 1), "Genesis 1-3")
        XCTAssertEqual((1...365).map { BiblePlan.chapters(day: $0).count }.reduce(0, +), 1189)
        XCTAssertEqual(BiblePlan.chapters(day: 365).last?.book, "Revelation")
        XCTAssertEqual(BiblePlan.chapters(day: 366).first?.book, "Genesis")
    }

    func testBundledData() {
        let refs = CrossRefs.forVerse(book: "John", ch: 3, v: 16)
        XCTAssertFalse(refs.isEmpty)
        XCTAssertTrue(refs.allSatisfy { Bible.canonNames.contains($0.book) })
        let places = BiblePlaces.forChapter(book: "Genesis", ch: 2)
        XCTAssertTrue(places.contains { $0.name == "Babylon" }, "\(places)")
        let range = CrossRefs.parseTarget("13.36.22-14.1.4")
        XCTAssertEqual(range?.label(), "2 Chronicles 36:22 – Ezra 1:4")
        XCTAssertEqual(CrossRefs.parseTarget("42.1.1-1.3")?.label(), "John 1:1–3")
    }

    func testSpanish() {
        let i = I18n.shared
        i.setChoice(.es)
        defer { i.setChoice(.en) }
        XCTAssertEqual(tr("Search the Bible"), "Buscar en la Biblia")
        XCTAssertEqual(tr("Day 5 of 365"), "Día 5 de 365")
        XCTAssertEqual(tr("1 Corinthians 13:4"), "1 Corintios 13:4")
        XCTAssertEqual(tr("Back"), "Atrás", "iOS table overrides Android's 'Espalda'")
        XCTAssertEqual(tr("  Close  "), "  Cerrar  ")
        XCTAssertEqual(tr("Faith"), "Fe")
        XCTAssertEqual(tr("Samuel"), "Samuel", "unknown text comes back unchanged")
        XCTAssertEqual(tr("Good morning, Samuel"), tr("Good morning") + ", Samuel")
        i.setChoice(.en)
        XCTAssertEqual(tr("Search the Bible"), "Search the Bible")
    }
}
