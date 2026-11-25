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
        app.launchArguments = args + ["-uiTestReset", "-sermonAskedNotify", "YES"] + (args.contains("-onboarded") ? [] : ["-onboarded", "YES"])
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

    /// First launch: setup for a woman, from welcome to the ready plan, then into the app.
    func testOnboarding() {
        let app = launch(["-onboarded", "NO", "-AppleLanguages", "(en)"])
        shot(app, "onb-01-welcome")
        button(app, containing: "Get Started").tap()
        button(app, containing: "a Woman").tap()
        button(app, containing: "Continue").tap()
        app.textFields.firstMatch.tap(); app.textFields.firstMatch.typeText("Ama\n")
        button(app, containing: "Continue").tap()
        button(app, containing: "I have periods").tap()
        shot(app, "onb-02-season")
        button(app, containing: "Continue").tap()
        button(app, containing: "Today").tap()
        button(app, containing: "Continue").tap()
        button(app, containing: "Continue").tap()                        // cycle details: keep the defaults
        button(app, containing: "Track my period").tap(); button(app, containing: "Continue").tap()
        button(app, containing: "Growing").tap(); button(app, containing: "Continue").tap()
        button(app, containing: "Protestant").tap(); button(app, containing: "Continue").tap()
        button(app, containing: "Lightly active").tap(); button(app, containing: "Continue").tap()
        button(app, containing: "prayer life").tap(); button(app, containing: "Continue").tap()
        button(app, containing: "No reminders").tap(); button(app, containing: "Continue").tap()
        let ready = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "your plan")).firstMatch.waitForExistence(timeout: 5)
        shot(app, "onb-03-ready")
        dump(app, ready)
        XCTAssertTrue(ready)
        button(app, containing: "Start My Journey").tap()
        XCTAssertTrue(tab(app, "Faith").waitForExistence(timeout: 10))
    }

    /// Phase 2 and 3 screens: the prayer garden, calm check, breathing pace, body & energy, men's plan and the plans.
    func testNewScreens() {
        let app = launch(["-hs_lang", "en"])
        XCTAssertTrue(tab(app, "Faith").waitForExistence(timeout: 20))
        tab(app, "Faith").tap()
        button(app, containing: "Your prayer garden").tap(); sleep(1)
        shot(app, "60-garden-empty")
        button(app, containing: "Plant a prayer").tap()
        app.textFields.firstMatch.tap(); app.textFields.firstMatch.typeText("Healing for Mum")
        button(app, containing: "Plant").tap(); sleep(1)
        shot(app, "61-garden-planted")
        XCTAssertTrue(app.staticTexts["A new sprout is in your garden."].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap(); sleep(1)
        tab(app, "Mind").tap(); app.swipeUp()
        button(app, containing: "Calm check").tap(); sleep(1)
        shot(app, "62-calm-check")
        app.navigationBars.buttons.firstMatch.tap(); sleep(1)
        button(app, containing: "Breathing pace").tap(); sleep(1)
        shot(app, "63-breath-pace")
        app.navigationBars.buttons.firstMatch.tap(); sleep(1)
        tab(app, "Cycle").tap(); sleep(1)
        tab(app, "More").tap(); sleep(1)
        button(app, containing: "menopause, arthritis").tap(); sleep(1)
        shot(app, "64-body-energy")
        button(app, containing: "Arthritis").tap()
        button(app, containing: "Save").tap(); sleep(1)
        shot(app, "65-body-energy-log")
        button(app, containing: "Close").tap(); sleep(1)
        button(app, containing: "A new baby in your life").tap(); sleep(1)
        shot(app, "69-new-parents")
        tab(app, "Learn").tap(); sleep(1)
        shot(app, "70-new-parents-learn")
        tab(app, "Support").tap(); sleep(1)
        button(app, containing: "Baby log").tap(); sleep(1)
        button(app, containing: "Add your baby").tap(); sleep(1)
        app.textFields.firstMatch.tap(); app.textFields.firstMatch.typeText("Kofi")
        button(app, containing: "Save").tap(); sleep(1)
        button(app, containing: "Diaper").tap(); sleep(1)
        button(app, containing: "Save").tap(); sleep(1)
        shot(app, "71-baby-log")
        app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
        button(app, containing: "Temperature").tap(); sleep(1)
        app.textFields.firstMatch.tap(); app.textFields.firstMatch.typeText("101.2")
        button(app, containing: "Check").tap(); sleep(1)
        shot(app, "72-temperature")
        app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
        button(app, containing: "Close").tap(); sleep(1)
        button(app, containing: "Headache diary").tap(); sleep(1)
        button(app, containing: "Log a headache").tap(); sleep(1)
        button(app, containing: "Stress").tap()
        button(app, containing: "Save").tap(); sleep(1)
        shot(app, "73-headache")
        button(app, containing: "Close").tap(); sleep(1)
        tab(app, "Profile").tap(); sleep(1)
        button(app, containing: "Your plan").tap(); sleep(1)
        shot(app, "66-account")
        button(app, containing: "See plans").tap(); sleep(2)
        shot(app, "67-plans")
        app.swipeUp(); shot(app, "68-plans-more")
    }

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
        // Terminate any lingering instance before launching to avoid CI timeout
        let prev = XCUIApplication(); prev.terminate()
        let app = launch(["-hs_lang", "en"])
        XCTAssertTrue(tab(app, "Faith").waitForExistence(timeout: 60))
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
        // A Home button that switches tabs, then one that pushes a screen.
        let faithTile = button(app, containing: "Pray, read and listen")
        faithTile.tap()
        let faithShown = app.staticTexts["Daily Devotion"].waitForExistence(timeout: 5)
        shot(app, "42b-faith-from-home")
        tab(app, "Home").tap()
        sleep(1)
        let open = tab(app, "Open")
        open.tap()
        let reader = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'verse-'")).firstMatch.waitForExistence(timeout: 60)
        shot(app, "42c-verse-open")
        tab(app, "Back").tap()
        sleep(1)
        XCTAssertTrue(faithShown, "The Faith tile should open Faith")
        XCTAssertTrue(reader, "Open should show the verse in the Bible")
        let sleepTile = button(app, containing: "Stories and night prayers")
        XCTAssertTrue(sleepTile.waitForExistence(timeout: 5))
        sleepTile.tap()
        let opened = app.staticTexts["Rest well tonight"].waitForExistence(timeout: 5)
        shot(app, "43-sleep")
        dump(app, opened)
        XCTAssertTrue(opened, "Sleep should open from Home")
        tab(app, "Back").tap()
        sleep(1)

        app.swipeDown(); app.swipeDown(); sleep(1)
        tab(app, "Search").tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("sleep")
        shot(app, "44-search")
        let recap = button(app, containing: "Your week")
        if recap.waitForExistence(timeout: 3) { recap.tap(); sleep(2); shot(app, "45-recap") }
    }

    /// Fitness, Cycle and Profile, rebuilt to match Android; and the men's Wellness tab.
    func testTabs() {
        let app = launch(["-hs_lang", "en"])
        XCTAssertTrue(tab(app, "Home").waitForExistence(timeout: 20))
        tab(app, "Fitness").tap(); sleep(1)
        shot(app, "50-fitness-today")
        tab(app, "Train").tap(); sleep(1)
        shot(app, "51-fitness-train")
        button(app, containing: "Log a Walk").tap()
        let log = button(app, containing: "Log walk")
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        log.tap(); sleep(1)
        tab(app, "Progress").tap(); sleep(1)
        shot(app, "52-fitness-progress")
        tab(app, "Cycle").tap(); sleep(1)
        shot(app, "53-cycle-empty")
        button(app, containing: "Log my last period").tap()
        let save = button(app, containing: "Log period start")
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap(); sleep(1)
        shot(app, "54-cycle-today")
        XCTAssertTrue(app.staticTexts["Day 1"].waitForExistence(timeout: 5))
        tab(app, "Plan").tap(); sleep(1)
        shot(app, "55-cycle-plan")
        tab(app, "Insights").tap(); sleep(1)
        shot(app, "56-cycle-insights")
        tab(app, "Profile").tap(); sleep(1)
        shot(app, "57-profile")
        app.swipeUp(); sleep(1)
        shot(app, "58-profile-more")
        app.terminate()
        let man = launch(["-hs_lang", "en", "-gender", "male"])
        XCTAssertTrue(tab(man, "Wellness").waitForExistence(timeout: 20))
        tab(man, "Wellness").tap(); sleep(1)
        shot(man, "59-mens-wellness")
        button(man, containing: "Good").tap()
        button(man, containing: "Save Today's Check-in").tap(); sleep(1)
        tab(man, "Plan").tap(); sleep(1)
        shot(man, "59b-mens-plan")
    }
}
