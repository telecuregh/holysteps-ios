import Foundation

// Faith + fitness programs (ported from Android data/Programs.kt): a few weeks of short workouts, each day with a
// passage to read and one line to carry, and a prayer for the week. Scripture is given as references (the Bible opens
// the text). Wellness users get the same workouts with a plain daily thought. The first FREE_DAYS days are free.

struct ProgramDay: Hashable { let ref: String; let line: String }
struct ProgramWeek: Hashable { let theme, wellnessTheme, prayer: String; let days: [ProgramDay] }   // day 7 is the rest walk

struct Program: Identifiable, Hashable {
    enum Kind: Hashable { case general, strength, postpartum, midlife }
    let id, emoji, title, wellnessTitle, blurb, wellnessBlurb: String
    let kind: Kind
    let minutes: String
    let note: String?
    let weeks: [ProgramWeek]

    var dayCount: Int { weeks.reduce(0) { $0 + $1.days.count } }
    func title(faith: Bool) -> String { faith ? title : wellnessTitle }
    func blurb(faith: Bool) -> String { faith ? blurb : wellnessBlurb }
    func week(_ day: Int) -> ProgramWeek { weeks[min(max(0, (day - 1) / 7), weeks.count - 1)] }
    func dayInfo(_ day: Int) -> ProgramDay { week(day).days[min(max(0, (day - 1) % 7), 6)] }
    func isRest(_ day: Int) -> Bool { day % 7 == 0 }
}

/// One step of a workout: a move (a trainer key such as SQUAT) for `seconds`, or a rest before `move`.
struct ProgramStep: Hashable { let move: String; let seconds: Int; var rest = false; var round = 0; var rounds = 0 }

enum Programs {
    static let freeDays = 3

    static func moveName(_ m: String) -> String {
        names[m] ?? m.lowercased().replacingOccurrences(of: "_", with: " ").capitalized
    }
    private static let names: [String: String] = [
        "MARCH": "March in place", "WALK": "Walk", "SQUAT": "Squat", "SUMO_SQUAT": "Sumo squat",
        "LUNGE_LEFT": "Lunge, left leg", "LUNGE_RIGHT": "Lunge, right leg", "SIDE_LUNGE_LEFT": "Side lunge, left",
        "SIDE_LUNGE_RIGHT": "Side lunge, right", "CURTSY_LUNGE": "Curtsy lunge", "DEADLIFT": "Deadlift",
        "ROMANIAN_DEADLIFT": "Romanian deadlift", "GLUTE_BRIDGE": "Glute bridge", "HIP_THRUST": "Hip thrust",
        "CALF_RAISE": "Calf raise", "STEP_UP": "Step-up", "WALL_SIT": "Wall sit", "PUSH_UP": "Push-up",
        "WIDE_PUSH_UP": "Wide push-up", "DIAMOND_PUSH_UP": "Diamond push-up", "PIKE_PUSH_UP": "Pike push-up",
        "DIPS": "Dips", "PLANK": "Plank", "SIDE_PLANK_LEFT": "Side plank, left", "SIDE_PLANK_RIGHT": "Side plank, right",
        "MOUNTAIN_CLIMBER": "Mountain climber", "BURPEE_DOWN": "Burpee", "BIRD_DOG": "Bird dog", "DEAD_BUG": "Dead bug",
        "SUPERMAN": "Superman", "JUMP_JACK": "Jumping jacks", "HIGH_KNEES": "High knees", "BUTT_KICK": "Butt kicks",
        "SKATER": "Skater", "INCHWORM": "Inchworm", "BEAR_CRAWL": "Bear crawl", "STRETCH": "Stretch", "SQUAT_JUMP": "Squat jump",
        "RUSSIAN_TWIST": "Russian twist", "BICYCLE_CRUNCH": "Bicycle crunch", "LATERAL_SHUFFLE": "Side shuffle",
    ]

    // Moves per program kind and week (index 0 = week 1). Postpartum leaves out crunch-type and jumping moves.
    private static let circuits: [Program.Kind: [[String]]] = [
        .general: [
            ["SQUAT", "MARCH", "GLUTE_BRIDGE", "BIRD_DOG", "CALF_RAISE"],
            ["SQUAT", "JUMP_JACK", "LUNGE_LEFT", "LUNGE_RIGHT", "PLANK"],
            ["SUMO_SQUAT", "HIGH_KNEES", "PUSH_UP", "GLUTE_BRIDGE", "MOUNTAIN_CLIMBER", "DEAD_BUG"],
        ],
        .strength: [
            ["SQUAT", "PUSH_UP", "GLUTE_BRIDGE", "BIRD_DOG", "PLANK"],
            ["LUNGE_LEFT", "LUNGE_RIGHT", "WIDE_PUSH_UP", "ROMANIAN_DEADLIFT", "SIDE_PLANK_LEFT", "SIDE_PLANK_RIGHT"],
            ["SQUAT_JUMP", "PUSH_UP", "HIP_THRUST", "DIPS", "MOUNTAIN_CLIMBER", "SUPERMAN"],
            ["BURPEE_DOWN", "DIAMOND_PUSH_UP", "CURTSY_LUNGE", "PIKE_PUSH_UP", "BEAR_CRAWL", "PLANK"],
        ],
        .postpartum: [
            ["MARCH", "GLUTE_BRIDGE", "BIRD_DOG", "CALF_RAISE", "STRETCH"],
            ["MARCH", "SQUAT", "GLUTE_BRIDGE", "DEAD_BUG", "BIRD_DOG"],
        ],
        .midlife: [
            ["SQUAT", "CALF_RAISE", "GLUTE_BRIDGE", "WALL_SIT", "BIRD_DOG"],
            ["STEP_UP", "DEADLIFT", "PUSH_UP", "SIDE_LUNGE_LEFT", "SIDE_LUNGE_RIGHT", "PLANK"],
            ["SUMO_SQUAT", "ROMANIAN_DEADLIFT", "WIDE_PUSH_UP", "CURTSY_LUNGE", "HIP_THRUST", "SUPERMAN"],
        ],
    ]

    enum Tune { case normal, lighter, stronger }

    /// Jumping and very hard moves are swapped for gentler ones on a lighter day.
    private static let gentler: [String: String] = [
        "JUMP_JACK": "MARCH", "HIGH_KNEES": "MARCH", "SQUAT_JUMP": "SQUAT", "BURPEE_DOWN": "SQUAT",
        "MOUNTAIN_CLIMBER": "BIRD_DOG", "BEAR_CRAWL": "BIRD_DOG", "DIAMOND_PUSH_UP": "PUSH_UP", "PIKE_PUSH_UP": "PUSH_UP",
        "SKATER": "SIDE_LUNGE_LEFT",
    ]

    /// The workout for one day: warm-up, the week's circuit (more rounds and longer work as the weeks go), cool-down.
    static func workout(_ p: Program, day: Int, tune: Tune = .normal) -> [ProgramStep] {
        if p.isRest(day) { return [ProgramStep(move: "WALK", seconds: tune == .lighter ? 15 * 60 : 20 * 60), ProgramStep(move: "STRETCH", seconds: 120)] }
        let weekIdx = (day - 1) / 7
        let list = circuits[p.kind] ?? []
        let base = list[min(weekIdx, list.count - 1)]
        var moves: [String] = []
        for m in (tune == .lighter ? base.map { gentler[$0] ?? $0 } : base) where !moves.contains(m) { moves.append(m) }
        let gentle = p.kind == .postpartum
        let baseWork = gentle ? 30 + weekIdx * 5 : 30 + weekIdx * 5 + ((day - 1) % 7) / 3 * 5
        let work = tune == .lighter ? max(20, baseWork - 10) : tune == .stronger ? baseWork + 5 : baseWork
        let baseRest = gentle ? 30 : max(12, 20 - weekIdx * 2)
        let rest = tune == .lighter ? baseRest + 10 : baseRest
        let baseRounds = gentle ? 2 : min(3, 2 + weekIdx / 2)
        let rounds = tune == .lighter ? max(1, baseRounds - 1) : baseRounds
        var out = [ProgramStep(move: "MARCH", seconds: 60), ProgramStep(move: "STRETCH", seconds: 45)]
        for r in 1...rounds {
            for (i, m) in moves.enumerated() {
                out.append(ProgramStep(move: m, seconds: m == "STRETCH" ? 45 : work, round: r, rounds: rounds))
                if !(r == rounds && i == moves.count - 1) {
                    out.append(ProgramStep(move: i + 1 < moves.count ? moves[i + 1] : moves[0], seconds: rest, rest: true, round: r, rounds: rounds))
                }
            }
        }
        out.append(ProgramStep(move: "WALK", seconds: 120))
        out.append(ProgramStep(move: "STRETCH", seconds: 60))
        return out
    }

    static func minutes(_ steps: [ProgramStep]) -> Int { max(1, (steps.reduce(0) { $0 + $1.seconds } + 30) / 60) }

    // Progress is stored as "id:day" keys.
    static func doneDays(_ p: Program, _ done: Set<String>) -> Int { (1...p.dayCount).filter { done.contains("\(p.id):\($0)") }.count }
    static func nextDay(_ p: Program, _ done: Set<String>) -> Int { (1...p.dayCount).first { !done.contains("\(p.id):\($0)") } ?? p.dayCount + 1 }
    static func finished(_ p: Program, _ done: Set<String>) -> Bool { nextDay(p, done) > p.dayCount }
    static func byId(_ id: String) -> Program? { all.first { $0.id == id } }

    /// Men don't see the postpartum or menopause programs, which are written for women.
    static func forGender(_ g: String) -> [Program] { g == "male" ? all.filter { $0.kind != .postpartum && $0.kind != .midlife } : all }

    /// Plain daily thoughts for Wellness users (cycled across days).
    private static let wellnessLines = [
        "Show up for the next ten minutes. That's enough.",
        "Breathe out longer than you breathe in.",
        "Good form first. Speed later.",
        "Notice one thing your body did well today.",
        "Small and steady beats big and rare.",
        "Drink some water before and after.",
        "Rest is part of training, not a break from it.",
    ]
    static func wellnessLine(_ day: Int) -> String { wellnessLines[(day - 1) % wellnessLines.count] }

    static let all: [Program] = [
        Program(id: "walk_pray_21", emoji: "🙏", title: "21 Days of Walk & Pray", wellnessTitle: "21 Days of Move & Breathe",
                blurb: "Short workouts for any level, a passage each day and a prayer for each week. A gentle way to build a habit with God.",
                wellnessBlurb: "Short workouts for any level and one thought a day. A gentle way to build a habit that lasts.",
                kind: .general, minutes: "15–25 min", note: nil, weeks: [
            ProgramWeek(theme: "Begin", wellnessTheme: "Begin", prayer: "Lord, I give You this body and these three weeks. Meet me in every step.", days: [
                    ProgramDay(ref: "Psalm 139:13-14", line: "You were made with care. Move today with thanks."),
                    ProgramDay(ref: "Isaiah 40:31", line: "Strength comes to those who wait on the Lord."),
                    ProgramDay(ref: "Matthew 11:28-30", line: "Bring Him what is heavy. His yoke is light."),
                    ProgramDay(ref: "Lamentations 3:22-23", line: "New mercies this morning. Start again, gently."),
                    ProgramDay(ref: "Philippians 4:13", line: "Not by your own strength alone."),
                    ProgramDay(ref: "Psalm 23:1-3", line: "He leads you beside still waters. Slow down and breathe."),
                    ProgramDay(ref: "Psalm 46:10", line: "Rest walk: be still and know that He is God.")
            ]),
            ProgramWeek(theme: "Keep going", wellnessTheme: "Keep going", prayer: "Father, when I want to stop, remind me why I started. Keep me faithful in small things.", days: [
                    ProgramDay(ref: "Galatians 6:9", line: "Do not grow weary. The harvest comes in time."),
                    ProgramDay(ref: "Hebrews 12:1-2", line: "Run with endurance, eyes on Jesus."),
                    ProgramDay(ref: "1 Corinthians 9:24-27", line: "Train with purpose, not just effort."),
                    ProgramDay(ref: "Joshua 1:9", line: "Be strong and courageous. He is with you."),
                    ProgramDay(ref: "Romans 5:3-5", line: "Endurance grows character, and character grows hope."),
                    ProgramDay(ref: "Proverbs 3:5-6", line: "Trust Him with the path you can't see yet."),
                    ProgramDay(ref: "Psalm 121", line: "Rest walk: your help comes from the Lord.")
            ]),
            ProgramWeek(theme: "Finish strong", wellnessTheme: "Finish strong", prayer: "Jesus, thank You for every day of this. Let what I built here last long after it ends.", days: [
                    ProgramDay(ref: "2 Timothy 4:7", line: "Finish the race you started."),
                    ProgramDay(ref: "1 Corinthians 6:19-20", line: "Your body is a temple. Honor Him with it."),
                    ProgramDay(ref: "Colossians 3:23", line: "Work at it with all your heart, as for the Lord."),
                    ProgramDay(ref: "3 John 1:2", line: "He cares that you are well, body and soul."),
                    ProgramDay(ref: "Psalm 18:32-33", line: "He makes your feet steady on high places."),
                    ProgramDay(ref: "Philippians 1:6", line: "He who began a good work will finish it."),
                    ProgramDay(ref: "Psalm 100", line: "Rest walk: walk in with thanksgiving.")
            ])
        ]),
        Program(id: "strong_in_lord_28", emoji: "💪", title: "Strong in the Lord", wellnessTitle: "Strong from Within",
                blurb: "Four weeks of bodyweight strength that grows harder each week, with Scripture about real strength.",
                wellnessBlurb: "Four weeks of bodyweight strength that grows harder each week, with one thought a day on staying steady.",
                kind: .strength, minutes: "20–30 min", note: nil, weeks: [
            ProgramWeek(theme: "Foundations", wellnessTheme: "Foundations", prayer: "Lord, build me on the rock. Teach me patience with my body and with myself.", days: [
                    ProgramDay(ref: "Ephesians 6:10", line: "Be strong in the Lord and in His mighty power."),
                    ProgramDay(ref: "Matthew 7:24-25", line: "Build on the rock. Good form first."),
                    ProgramDay(ref: "Psalm 28:7", line: "The Lord is my strength and my shield."),
                    ProgramDay(ref: "Nehemiah 8:10", line: "The joy of the Lord is your strength."),
                    ProgramDay(ref: "Zechariah 4:10", line: "Don't despise small beginnings."),
                    ProgramDay(ref: "2 Corinthians 12:9", line: "His power shows up in weakness."),
                    ProgramDay(ref: "Psalm 62:1-2", line: "Rest walk: He alone is my rock.")
            ]),
            ProgramWeek(theme: "Discipline", wellnessTheme: "Discipline", prayer: "Father, train my habits as well as my muscles. Make me faithful when no one is watching.", days: [
                    ProgramDay(ref: "1 Timothy 4:8", line: "Training has value. Godliness has more."),
                    ProgramDay(ref: "Hebrews 12:11", line: "Discipline is hard now and fruitful later."),
                    ProgramDay(ref: "Proverbs 24:16", line: "Fall seven times, rise again."),
                    ProgramDay(ref: "Galatians 5:22-23", line: "Self-control is fruit of the Spirit."),
                    ProgramDay(ref: "Proverbs 16:3", line: "Commit your work to the Lord."),
                    ProgramDay(ref: "James 1:2-4", line: "Let perseverance finish its work."),
                    ProgramDay(ref: "Isaiah 30:15", line: "Rest walk: in quietness and trust is your strength.")
            ]),
            ProgramWeek(theme: "Courage", wellnessTheme: "Courage", prayer: "God, make me brave in the hard set and in the hard conversation. You go before me.", days: [
                    ProgramDay(ref: "Deuteronomy 31:6", line: "He will never leave you nor forsake you."),
                    ProgramDay(ref: "Psalm 27:1", line: "Whom shall I fear?"),
                    ProgramDay(ref: "Isaiah 41:10", line: "He will strengthen you and help you."),
                    ProgramDay(ref: "1 Corinthians 16:13", line: "Stand firm. Be strong."),
                    ProgramDay(ref: "2 Timothy 1:7", line: "Not a spirit of fear, but of power."),
                    ProgramDay(ref: "Psalm 31:24", line: "Be strong and take heart."),
                    ProgramDay(ref: "Psalm 16:8", line: "Rest walk: with Him at your right hand you won't be shaken.")
            ]),
            ProgramWeek(theme: "Endurance", wellnessTheme: "Endurance", prayer: "Jesus, keep me going to the end, and keep me humble when I get there.", days: [
                    ProgramDay(ref: "Isaiah 40:29", line: "He gives power to the faint."),
                    ProgramDay(ref: "Romans 12:1", line: "Offer your body as a living sacrifice."),
                    ProgramDay(ref: "Philippians 3:13-14", line: "Forget what is behind. Press on."),
                    ProgramDay(ref: "Habakkuk 3:19", line: "He makes your feet like a deer's."),
                    ProgramDay(ref: "1 Peter 5:10", line: "He will restore you and make you strong."),
                    ProgramDay(ref: "Micah 6:8", line: "Walk humbly with your God."),
                    ProgramDay(ref: "Psalm 103:1-5", line: "Rest walk: remember all His benefits.")
            ])
        ]),
        Program(id: "gentle_return_14", emoji: "🤱", title: "Gentle Return", wellnessTitle: "Gentle Return",
                blurb: "Two weeks of very gentle movement after having a baby: breathing, the core from the inside out, short walks. Grace over pace.",
                wellnessBlurb: "Two weeks of very gentle movement after having a baby: breathing, the core from the inside out, short walks. Kindness over pace.",
                kind: .postpartum, minutes: "10–15 min", note: "Start only after your doctor or midwife says you're cleared to exercise (often around 6 weeks after birth). Stop if you feel pain, heaviness or bleeding gets heavier.", weeks: [
            ProgramWeek(theme: "Rest and receive", wellnessTheme: "Rest and receive", prayer: "Lord, I'm tired and I'm grateful. Hold me while I hold this little one.", days: [
                    ProgramDay(ref: "Psalm 127:3", line: "Children are a gift. So is rest."),
                    ProgramDay(ref: "Isaiah 40:11", line: "He gently leads those who have young."),
                    ProgramDay(ref: "Matthew 11:28", line: "Come to Him, all who are weary."),
                    ProgramDay(ref: "Psalm 116:7", line: "Return to your rest, my soul."),
                    ProgramDay(ref: "Zephaniah 3:17", line: "He rejoices over you with singing."),
                    ProgramDay(ref: "Psalm 4:8", line: "Lie down in peace. He keeps you safe."),
                    ProgramDay(ref: "Psalm 131", line: "Rest walk: a quieted soul, like a child with its mother.")
            ]),
            ProgramWeek(theme: "Strength returns", wellnessTheme: "Strength returns", prayer: "Father, rebuild me slowly and well. Let me not compare, only receive.", days: [
                    ProgramDay(ref: "Isaiah 66:13", line: "As a mother comforts her child, so He comforts you."),
                    ProgramDay(ref: "2 Corinthians 4:16", line: "Inwardly being renewed day by day."),
                    ProgramDay(ref: "Psalm 73:26", line: "God is the strength of my heart."),
                    ProgramDay(ref: "Proverbs 31:25", line: "Clothed with strength and dignity."),
                    ProgramDay(ref: "Ecclesiastes 3:1", line: "A season for everything. This one too."),
                    ProgramDay(ref: "1 Peter 5:7", line: "Cast every worry on Him."),
                    ProgramDay(ref: "Numbers 6:24-26", line: "Rest walk: the Lord bless you and keep you.")
            ])
        ]),
        Program(id: "peace_in_change_21", emoji: "🌸", title: "Peace in the Change", wellnessTitle: "Steady Through the Change",
                blurb: "Three weeks of strength and walking for women in perimenopause and menopause: bones, balance, sleep and peace.",
                wellnessBlurb: "Three weeks of strength and walking for women in perimenopause and menopause: bones, balance, sleep and calm.",
                kind: .midlife, minutes: "15–25 min", note: "Strength work and walking help bones and sleep. If you have a health condition, check with your doctor first.", weeks: [
            ProgramWeek(theme: "Rooted", wellnessTheme: "Rooted", prayer: "Lord, my body is changing and You do not change. Root me in You.", days: [
                    ProgramDay(ref: "Malachi 3:6", line: "He does not change."),
                    ProgramDay(ref: "Psalm 92:12-14", line: "Still bearing fruit in old age, fresh and green."),
                    ProgramDay(ref: "Jeremiah 17:7-8", line: "Like a tree planted by water."),
                    ProgramDay(ref: "Isaiah 46:4", line: "Even to your gray hairs He will carry you."),
                    ProgramDay(ref: "Psalm 90:12", line: "Teach us to number our days."),
                    ProgramDay(ref: "Hebrews 13:8", line: "Jesus is the same yesterday, today and forever."),
                    ProgramDay(ref: "Psalm 1:1-3", line: "Rest walk: planted, steady, in season.")
            ]),
            ProgramWeek(theme: "Strong bones, steady heart", wellnessTheme: "Strong bones, steady heart", prayer: "Father, strengthen my bones and quiet my heart. Give me sleep that restores.", days: [
                    ProgramDay(ref: "Isaiah 58:11", line: "He will strengthen your frame."),
                    ProgramDay(ref: "Proverbs 3:7-8", line: "Health to your body, nourishment to your bones."),
                    ProgramDay(ref: "Psalm 127:2", line: "He gives sleep to those He loves."),
                    ProgramDay(ref: "Philippians 4:6-7", line: "Peace that guards your heart and mind."),
                    ProgramDay(ref: "Psalm 34:4", line: "He delivered me from all my fears."),
                    ProgramDay(ref: "John 14:27", line: "Peace I leave with you."),
                    ProgramDay(ref: "Psalm 23", line: "Rest walk: He restores my soul.")
            ]),
            ProgramWeek(theme: "New season", wellnessTheme: "New season", prayer: "God, thank You for this season. Show me the good work You still have for me.", days: [
                    ProgramDay(ref: "Isaiah 43:18-19", line: "See, He is doing a new thing."),
                    ProgramDay(ref: "Titus 2:3-5", line: "Your wisdom is needed by younger women."),
                    ProgramDay(ref: "2 Corinthians 5:17", line: "The new has come."),
                    ProgramDay(ref: "Ruth 1:16", line: "Faithful in every season."),
                    ProgramDay(ref: "Proverbs 31:30", line: "A woman who fears the Lord is to be praised."),
                    ProgramDay(ref: "Psalm 71:17-18", line: "Declare His power to the next generation."),
                    ProgramDay(ref: "Psalm 145:1-5", line: "Rest walk: praise from one generation to the next.")
            ])
        ])
    ]
}
