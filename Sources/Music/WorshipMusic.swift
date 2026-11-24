import Foundation

/// The worship songs that come with the app (Android's WorshipMusic.kt), bundled in Resources/music as .m4a. Matching
/// a song to a moment happens on this phone only, and nothing records which struggle a song was picked for.
enum MusicNeed: String, CaseIterable, Identifiable {
    case URGE, AFTER_SLIP, NIGHT, ANXIOUS, LONELY, GRIEF, SHAME, ACCOUNTABILITY, MONEY_WORK, MARRIAGE, HOPE, MORNING
    var id: String { rawValue }
    /// Shown on a filter chip, so it's worded to be fine to see over a shoulder.
    var label: String {
        switch self {
        case .URGE: return "When temptation hits"
        case .AFTER_SLIP: return "After a slip"
        case .NIGHT: return "Late at night"
        case .ANXIOUS: return "Anxious"
        case .LONELY: return "Lonely"
        case .GRIEF: return "Grieving"
        case .SHAME: return "Shame"
        case .ACCOUNTABILITY: return "Need support"
        case .MONEY_WORK: return "Money and work"
        case .MARRIAGE: return "Marriage"
        case .HOPE: return "Hope"
        case .MORNING: return "Morning"
        }
    }
    var emoji: String {
        switch self {
        case .URGE: return "🛡️"; case .AFTER_SLIP: return "🌅"; case .NIGHT: return "🌙"; case .ANXIOUS: return "🕊️"
        case .LONELY: return "🤝"; case .GRIEF: return "💧"; case .SHAME: return "🙏"; case .ACCOUNTABILITY: return "🫶"
        case .MONEY_WORK: return "🍞"; case .MARRIAGE: return "💍"; case .HOPE: return "⭐"; case .MORNING: return "☀️"
        }
    }
}

enum MusicFeel { case gentle, steady, lift }

struct WorshipTrack: Identifiable, Hashable {
    let id: String
    let title: String
    /// Why it's here, in a few words, shown under the title.
    let about: String
    /// The Bible passage the song is built on.
    let scripture: String
    let feel: MusicFeel
    /// Most fitting first.
    let needs: [MusicNeed]
    let seconds: Int

    var url: URL? { Bundle.main.url(forResource: id, withExtension: "m4a") }
    var item: MusicItem { MusicItem(id: "song:\(id)", title: title, subtitle: about, source: .bundled(id)) }

    static func == (a: WorshipTrack, b: WorshipTrack) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

private func t(_ id: String, _ title: String, _ about: String, _ scripture: String, _ feel: MusicFeel, _ needs: [MusicNeed], _ seconds: Int) -> WorshipTrack {
    WorshipTrack(id: id, title: title, about: about, scripture: scripture, feel: feel, needs: needs, seconds: seconds)
}

enum WorshipMusic {
    static let worship: [WorshipTrack] = [
        t("the_battle_is_not_mine", "The Battle Is Not Mine", "A song for the fight you're in tonight", "2 Chronicles 20:15", .lift, [.URGE, .ANXIOUS, .HOPE], 227),
        t("midnight_praise", "Midnight Praise", "For the long hours when sleep won't come", "Acts 16:25", .lift, [.NIGHT, .URGE, .GRIEF], 234),
        t("hold_up_my_arms", "Hold Up My Arms", "You were never meant to fight this alone", "Exodus 17:12", .steady, [.ACCOUNTABILITY, .URGE, .LONELY], 238),
        t("remember_me", "Remember Me", "Mercy for the one who has fallen", "Luke 23:42", .steady, [.AFTER_SLIP, .SHAME, .HOPE], 268),
        t("a_second_time", "A Second Time", "Failure is not your name", "Jonah 3:1", .lift, [.AFTER_SLIP, .SHAME, .HOPE], 224),
        t("he_called_my_name", "He Called My Name", "You are known, not just your mistakes", "Isaiah 43:1", .steady, [.SHAME, .LONELY, .HOPE], 232),
        t("he_sat_down_beside_me", "He Sat Down Beside Me", "For lonely and heavy days", "Psalm 34:18", .steady, [.LONELY, .GRIEF, .ANXIOUS], 229),
        t("count_the_stars", "Count the Stars", "A promise to hold on to while you wait", "Genesis 15:5", .steady, [.HOPE, .ANXIOUS, .NIGHT], 243),
        t("manna_in_the_morning", "Manna in the Morning", "Enough for today, when money is tight", "Exodus 16:4", .lift, [.MONEY_WORK, .MORNING, .ANXIOUS], 247),
        t("water_into_wine", "Water Into Wine", "For a marriage running dry", "John 2:1-11", .steady, [.MARRIAGE, .HOPE], 224),
    ]

    /// Sung hymns on Bible stories. Each has its original and a remix.
    static let sungHymns: [WorshipTrack] = [
        t("you_cannot_run", "You Cannot Run", "Jonah, and the God who comes after you", "Jonah 1–2", .steady, [.AFTER_SLIP, .HOPE], 165),
        t("you_cannot_run_2", "You Cannot Run (Remix)", "Jonah, and the God who comes after you", "Jonah 1–2", .steady, [.AFTER_SLIP, .HOPE], 152),
        t("i_will_arise", "I Will Arise", "The prodigal son comes home", "Luke 15:18", .steady, [.SHAME, .AFTER_SLIP], 149),
        t("i_will_arise_2", "I Will Arise (Remix)", "The prodigal son comes home", "Luke 15:18", .steady, [.SHAME, .AFTER_SLIP], 153),
        t("stand_still_and_see", "Stand Still and See", "God makes a way through the Red Sea", "Exodus 14:13", .lift, [.ANXIOUS, .HOPE], 149),
        t("stand_still_and_see_2", "Stand Still and See (Remix)", "God makes a way through the Red Sea", "Exodus 14:13", .lift, [.ANXIOUS, .HOPE], 153),
        t("by_grace_alone", "By Grace Alone", "Saved by grace, not by trying harder", "Ephesians 2:8", .steady, [.SHAME, .HOPE], 95),
        t("by_grace_alone_2", "By Grace Alone (Remix)", "Saved by grace, not by trying harder", "Ephesians 2:8", .steady, [.SHAME, .HOPE], 94),
        t("o_boundless_grace", "O Boundless Grace", "Grace that is enough when you are weak", "2 Corinthians 12:9", .gentle, [.HOPE, .AFTER_SLIP], 120),
        t("o_boundless_grace_2", "O Boundless Grace (Remix)", "Grace that is enough when you are weak", "2 Corinthians 12:9", .gentle, [.HOPE, .AFTER_SLIP], 113),
        t("come_home_today", "Come Home Today", "The Father runs to meet you", "Luke 15:20", .steady, [.AFTER_SLIP, .SHAME], 147),
        t("come_home_today_2", "Come Home Today (Remix)", "The Father runs to meet you", "Luke 15:20", .steady, [.AFTER_SLIP, .SHAME], 188),
        t("i_lift_my_eyes", "I Lift My Eyes Unto the Hills", "Where your help comes from", "Psalm 121:1-2", .gentle, [.ANXIOUS, .MORNING], 138),
        t("i_lift_my_eyes_2", "I Lift My Eyes Unto the Hills (Remix)", "Where your help comes from", "Psalm 121:1-2", .gentle, [.ANXIOUS, .MORNING], 140),
        t("around_the_table", "Around the Table", "Family, bread and thanks together", "Acts 2:46", .steady, [.MARRIAGE, .LONELY], 147),
        t("around_the_table_2", "Around the Table (Remix)", "Family, bread and thanks together", "Acts 2:46", .steady, [.MARRIAGE, .LONELY], 115),
        t("the_lions_roared", "The Lions Roared", "Daniel in the den, and the God who shut their mouths", "Daniel 6:22", .lift, [.ANXIOUS, .URGE], 189),
        t("the_lions_roared_2", "The Lions Roared (Remix)", "Daniel in the den, and the God who shut their mouths", "Daniel 6:22", .lift, [.ANXIOUS, .URGE], 167),
    ]

    /// Country gospel songs, their own section on the Hymns tab.
    static let countryGospel: [WorshipTrack] = [
        t("every_breath_is_praise", "Every Breath Is Praise", "Let everything that has breath praise the Lord", "Psalm 150:6", .lift, [.MORNING, .HOPE], 215),
        t("every_breath_is_praise_2", "Every Breath Is Praise (Remix)", "Let everything that has breath praise the Lord", "Psalm 150:6", .lift, [.MORNING, .HOPE], 218),
        t("kings_highway", "Moving On Up the King's Highway", "Walking the road home with God", "Isaiah 35:8", .lift, [.HOPE, .MORNING], 132),
        t("kings_highway_2", "Moving On Up the King's Highway (Remix)", "Walking the road home with God", "Isaiah 35:8", .lift, [.HOPE, .MORNING], 136),
        t("that_bright_morning", "That Bright Morning", "No more tears on that day", "Revelation 21:4", .steady, [.GRIEF, .HOPE], 135),
        t("that_bright_morning_2", "That Bright Morning (Remix)", "No more tears on that day", "Revelation 21:4", .steady, [.GRIEF, .HOPE], 135),
        t("that_bright_morning_3", "That Bright Morning (Remix 2)", "No more tears on that day", "Revelation 21:4", .steady, [.GRIEF, .HOPE], 149),
        t("ebenezer_thus_far", "Ebenezer, Thus Far", "Hitherto hath the Lord helped us", "1 Samuel 7:12", .steady, [.HOPE, .MONEY_WORK], 168),
        t("ebenezer_thus_far_2", "Ebenezer, Thus Far (Remix)", "Hitherto hath the Lord helped us", "1 Samuel 7:12", .steady, [.HOPE, .MONEY_WORK], 176),
    ]

    static var all: [WorshipTrack] { worship + sungHymns + countryGospel }

    /// Every worship song that fits `need`, the best fit first.
    static func forNeed(_ need: MusicNeed) -> [WorshipTrack] {
        worship.filter { $0.needs.contains(need) }.sorted { ($0.needs.firstIndex(of: need) ?? 9) < ($1.needs.firstIndex(of: need) ?? 9) }
    }

    /// Android's recommendTracks for the general case: a need the person chose, or the time of day.
    static func recommend(asked: MusicNeed? = nil, hour: Int = Calendar.current.component(.hour, from: Date()), limit: Int = 3) -> [WorshipTrack] {
        func score(_ t: WorshipTrack) -> Double {
            var s = 0.0
            func need(_ n: MusicNeed, _ w: Double) {
                if let r = t.needs.firstIndex(of: n) { s += w * (r == 0 ? 1.0 : (r == 1 ? 0.7 : 0.4)) }
            }
            if let asked { need(asked, 20) }
            else if hour >= 22 || hour < 5 { need(.NIGHT, 3) }
            else if (5...9).contains(hour) { need(.MORNING, 3) }
            return s
        }
        let day = SermonWeekLogic.today()
        // Ties are settled by a small daily rotation, the same on every launch (a stable sum, not hashValue).
        func tie(_ t: WorshipTrack) -> Double {
            let sum = t.id.unicodeScalars.reduce(0) { acc, u in acc + Int(u.value) }
            return Double((sum + day) % 7) * 0.01
        }
        let scored = worship.map { track in (track, score(track) + tie(track)) }
        return scored.sorted { a, b in a.1 != b.1 ? a.1 > b.1 : a.0.id < b.0.id }.prefix(limit).map { $0.0 }
    }
}
