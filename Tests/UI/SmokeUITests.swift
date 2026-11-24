import XCTest

/// Runs the app on the simulator, walks through the Bible reader in English and Spanish, and saves screenshots so
/// each build can be checked by eye (CI uploads them).
final class SmokeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let s = app.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? s.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = args + ["-sermonAskedNotify", "YES"]
        app.launch()
        return app
    }

    private func button(_ app: XCUIApplication, containing s: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", s)).firstMatch
    }

    func testEnglishBible() {
        let app = launch(["-hs_lang", "en", "-bibleTranslation", "KJV", "-bibleLastBook", "John", "-bibleLastCh", "1"])
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 20))
        shot(app, "01-home")
        app.tabBars.buttons["Faith"].tap()
        shot(app, "02-faith")
        button(app, containing: "Continue reading").tap()
        let verse = app.buttons["verse-1"]
        let found = verse.waitForExistence(timeout: 90)
        shot(app, "03a-after-open")
        if !found { print("UI TREE:\n" + app.debugDescription) }
        XCTAssertTrue(found, "KJV should download and open John 1")
        shot(app, "03-reader-john1")
        verse.tap()
        XCTAssertTrue(app.buttons["Gold highlight"].waitForExistence(timeout: 5))
        app.buttons["Gold highlight"].tap()
        shot(app, "04-verse-actions")
        button(app, containing: "References").tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        sleep(1)
        shot(app, "05-cross-references")
        app.navigationBars.buttons["Close"].tap()
        app.buttons["Search the Bible"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("love one another")
        sleep(3)
        shot(app, "06-search")
        app.navigationBars.buttons["Close"].tap()
        app.buttons["Text size and style"].tap()
        sleep(1)
        shot(app, "07-text-settings")
        app.navigationBars.buttons["Done"].tap()
        app.buttons["Places on this chapter's map"].tap()
        sleep(3)
        shot(app, "08-map")
        app.navigationBars.buttons["Close"].tap()
        app.buttons["Listen to this chapter"].tap()
        sleep(3)
        shot(app, "09-listening")
    }

    func testSermon() {
        let app = launch(["-hs_lang", "en", "-sermonAskedNotify", "YES"])
        XCTAssertTrue(app.tabBars.buttons["Faith"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Faith"].tap()
        shot(app, "20-faith-with-sermon")
        button(app, containing: "What you're facing").tap()
        sleep(1)
        shot(app, "21-sermon-topics")
        button(app, containing: "Anxiety and worry").tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        shot(app, "22-topic-alert")
        app.alerts.buttons["Listen now"].tap()
        sleep(20)   // the preacher's voice pack downloads, then the first paragraphs play
        shot(app, "23-sermon-player")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Preacher' OR label CONTAINS 'phone'")).firstMatch.exists)
    }

    func testSpanishBible() {
        let app = launch(["-hs_lang", "es", "-bibleTranslation", "RVES", "-bibleLastBook", "Psalms", "-bibleLastCh", "23"])
        XCTAssertTrue(app.tabBars.buttons["Inicio"].waitForExistence(timeout: 30))
        shot(app, "10-es-home")
        app.tabBars.buttons["Fe"].tap()
        shot(app, "11-es-faith")
        button(app, containing: "Seguir leyendo").tap()
        let verse = app.buttons.matching(NSPredicate(format: "label CONTAINS 'pastor'")).firstMatch
        let found = verse.waitForExistence(timeout: 90)
        shot(app, "12a-after-open")
        if !found { print("UI TREE:\n" + app.debugDescription) }
        XCTAssertTrue(found, "RVES should download and open Salmos 23")
        shot(app, "12-es-reader-psalm23")
    }
}
