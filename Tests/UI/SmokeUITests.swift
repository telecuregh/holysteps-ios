import XCTest

/// Runs the app on the simulator, walks through the main screens in English and Spanish, and saves screenshots so
/// each build can be checked by eye against Android (CI uploads them).
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
        let all = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", s))
        _ = all.firstMatch.waitForExistence(timeout: 5)
        return all.allElementsBoundByIndex.first { $0.isHittable } ?? all.firstMatch
    }

    /// The visible button with this label (hidden tabs keep their own buttons with the same names).
    private func tab(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        let all = app.buttons.matching(NSPredicate(format: "label == %@", label))
        _ = all.firstMatch.waitForExistence(timeout: 10)
        return all.allElementsBoundByIndex.first { $0.isHittable } ?? all.firstMatch
    }

    private func dump(_ app: XCUIApplication, _ ok: Bool) { if !ok { print("UI TREE:\n" + app.debugDescription) } }

    func testEnglishBible() {
        let app = launch(["-hs_lang", "en", "-bibleTranslation", "KJV", "-bibleLastBook", "John", "-bibleLastCh", "1"])
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 20))
        shot(app, "01-home")
        tab(app, "Faith").tap()
        shot(app, "02-faith")
        tab(app, "Bible").tap()
        shot(app, "02c-faith-bible-tab")
        button(app, containing: "Read the Bible").tap()
        let verse = app.buttons["verse-1"]
        let found = verse.waitForExistence(timeout: 90)
        shot(app, "03-reader-john1")
        dump(app, found)
        XCTAssertTrue(found, "KJV should download and open John 1")
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
        sleep(1)   // the field is focused when the search opens
        app.typeText("love one another")
        sleep(3)
        shot(app, "06-search")
        app.navigationBars.buttons["Close"].tap()
        app.buttons["Places on this chapter's map"].tap()
        sleep(3)
        shot(app, "08-map")
        app.navigationBars.buttons["Close"].tap()
        app.buttons["Listen to this chapter"].tap()
        sleep(3)
        shot(app, "09-listening")
    }

    func testFaithTabs() {
        let app = launch(["-hs_lang", "en"])
        XCTAssertTrue(tab(app, "Faith").waitForExistence(timeout: 20))
        tab(app, "Faith").tap()
        app.swipeUp()
        shot(app, "20b-faith-today-scrolled")
        app.swipeDown(); app.swipeDown()
        tab(app, "Bible").tap()
        button(app, containing: "Devotional Plans").tap()
        sleep(1)
        shot(app, "19-devotional")
        app.navigationBars.buttons.firstMatch.tap()
        tab(app, "Listen").tap()
        shot(app, "25-faith-listen")
        button(app, containing: "Gospel songs").tap()
        let song = button(app, containing: "Midnight Praise")
        let found = song.waitForExistence(timeout: 10)
        dump(app, found)
        XCTAssertTrue(found)
        song.tap()
        sleep(3)
        shot(app, "24-music-playing")
        app.navigationBars.buttons.firstMatch.tap()
        tab(app, "Mind").tap()
        shot(app, "26-faith-mind")
        button(app, containing: "Sermons for what you're facing").tap()
        sleep(1)
        shot(app, "21-sermon-topics")
        button(app, containing: "Anxiety and worry").tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["Listen now"].tap()
        sleep(20)   // the preacher's voice pack downloads, then the first paragraphs play
        shot(app, "23-sermon-player")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Preacher' OR label CONTAINS 'phone'")).firstMatch.exists)
    }

    func testSpanishBible() {
        let app = launch(["-hs_lang", "es", "-bibleTranslation", "RVES", "-bibleLastBook", "Psalms", "-bibleLastCh", "23"])
        XCTAssertTrue(tab(app, "Inicio").waitForExistence(timeout: 30))
        shot(app, "10-es-home")
        tab(app, "Fe").tap()
        shot(app, "11-es-faith")
        tab(app, "Biblia").tap()
        button(app, containing: "Leer la Biblia").tap()
        let verse = app.buttons.matching(NSPredicate(format: "label CONTAINS 'pastor'")).firstMatch
        let found = verse.waitForExistence(timeout: 90)
        shot(app, "12-es-reader-psalm23")
        dump(app, found)
        XCTAssertTrue(found, "RVES should download and open Salmos 23")
    }

    /// Light and Pearl (Profile › Appearance), with a switch back to Dark from the toggle.
    func testThemes() {
        for mode in ["light", "pearl"] {
            let app = launch(["-hs_lang", "en", "-themeMode", mode])
            XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 20))
            shot(app, "30-\(mode)-home")
            tab(app, "Faith").tap()
            shot(app, "31-\(mode)-faith")
            tab(app, "Profile").tap()
            shot(app, "32-\(mode)-profile")
            app.terminate()
        }
        let app = launch(["-hs_lang", "en", "-themeMode", "pearl"])
        tab(app, "Profile").tap()
        let dark = app.buttons["theme-dark"]
        let found = dark.waitForExistence(timeout: 10)
        dump(app, found)
        XCTAssertTrue(found)
        if !dark.isHittable { app.swipeUp() }
        dark.tap()
        XCTAssertTrue(app.buttons["theme-dark"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["theme-dark"].isSelected)
        shot(app, "33-back-to-dark")
    }

    /// The clarity-plan Home: first week, rings, verse, tiles, search, Sleep and the weekly recap.
    func testHomePlan() {
        let app = launch(["-hs_lang", "en"])
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 20))
        sleep(2)
        shot(app, "40-home-top")
        app.swipeUp()
        shot(app, "41-home-middle")
        app.swipeUp()
        sleep(1)
        shot(app, "42-home-bottom")
        let sleepTile = button(app, containing: "Stories and night prayers")
        XCTAssertTrue(sleepTile.waitForExistence(timeout: 5))
        sleepTile.tap()
        sleep(2)
        shot(app, "43-sleep")
        let back = app.navigationBars.buttons.allElementsBoundByIndex.first { $0.isHittable }
        back?.tap()
        app.swipeDown(); app.swipeDown(); sleep(1)
        tab(app, "Search").tap()
        sleep(1)
        app.typeText("sleep")
        shot(app, "44-search")
        let recap = button(app, containing: "Your week")
        if recap.waitForExistence(timeout: 3) { recap.tap(); sleep(2); shot(app, "45-recap") }
    }
}
