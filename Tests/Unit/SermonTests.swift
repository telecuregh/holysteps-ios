import XCTest
@testable import HolySteps

final class SermonTests: XCTestCase {
    func testLibraryLoads() {
        XCTAssertEqual(SermonLibrary.all.count, 181)
        XCTAssertEqual(SermonLibrary.books.count, 66)
        XCTAssertEqual(SermonLibrary.seasons.count, 22)
        XCTAssertEqual(SermonLibrary.narratedWeekly.count, 69)
        XCTAssertEqual(SermonLibrary.books.first?.subtitle, "Genesis · Book 1 of 66")
        XCTAssertNotNil(SermonLibrary.sermon("facing_01"))
    }

    func testNarrationKeysMatchServerPacks() {
        // Keys computed by Android's narrationKey and present in the server's am_onyx pack.
        XCTAssertEqual(Narration.key("Today's sermon is taken from First Thessalonians, chapter five."), "e4f6c9229014d9f9")
        XCTAssertEqual(Narration.spoken("The LORD — my God… 1/2 cup at 98°"), "The Lord, my God... 1 of 2 cup at 98 degrees")
        XCTAssertEqual(Narration.key("The LORD — my God… 1/2 cup at 98°"), "f9680294b54a4434")
    }

    func testParse() {
        let segs = Sermon.parse("First line\nsame paragraph.\n\n[PAUSE 3 SECONDS]\n[Music swells]\nSecond.")
        XCTAssertEqual(segs, [.speech("First line same paragraph."), .pause(3), .speech("Second.")])
    }

    func testWeekLogic() {
        XCTAssertEqual(SermonWeekLogic.dayOfWeek(0), 4, "1970-01-01 was a Thursday")
        XCTAssertEqual(SermonWeekLogic.dayOfWeek(SermonWeekLogic.bibleSeriesStart), 1, "Nov 16, 2026 is a Monday")
        XCTAssertEqual(SermonWeekLogic.booksReleased(SermonWeekLogic.bibleSeriesStart, 7, 66), 1)
        XCTAssertEqual(SermonWeekLogic.booksReleased(SermonWeekLogic.bibleSeriesStart + 70, 7, 66), 11)
        // The same sermon all week, a different one the next week.
        let sun = SermonWeekLogic.bibleSeriesStart + 6
        XCTAssertEqual(SermonWeekLogic.index(sun, 7, 69), SermonWeekLogic.index(sun + 6, 7, 69))
        XCTAssertNotEqual(SermonWeekLogic.index(sun, 7, 69), SermonWeekLogic.index(sun + 7, 7, 69))
        XCTAssertEqual(SermonWeekLogic.daysUntil(sun, 7), 0)
    }
}
