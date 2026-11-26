import Foundation

// Season walks: a road walked through a church season, with a verse, a reflection, a prayer and a way to pray on the
// walk for each day. Port of Android's SeasonWalks.kt. The walk itself (steps) is free; the daily readings after
// `freeDays` come with the Faith plan. Verses are King James Version (public domain).

struct SeasonDay {
    let title: String, reference: String, verse: String, reflection: String, prayer: String, walk: String
    init(_ title: String, _ reference: String, _ verse: String, _ reflection: String, _ prayer: String, _ walk: String) {
        self.title = title; self.reference = reference; self.verse = verse
        self.reflection = reflection; self.prayer = prayer; self.walk = walk
    }
}

struct SeasonStop { let atKm: Double; let name: String }

struct SeasonWalk: Identifiable {
    let id: String
    let title: String
    let emoji: String
    let season: String
    /// The first day, yyyy-MM-dd.
    let start: String
    let routeKm: Double
    let stops: [SeasonStop]
    let days: [SeasonDay]
    var announceDays = 21
    var afterDays = 13
    var destination = ""
    var fromTo = ""
    var pitch = ""
    var arriveBy = ""
    var celebrate = ""
    /// Days free for everyone; later days need a Faith plan. 0 = every day free.
    var freeDays = 0

    var dayCount: Int { days.count }
    var end: String { SeasonDates.plusDays(start, dayCount - 1) }
    var dailyKm: Double { routeKm / Double(dayCount) }
    func dayNumber(_ today: String) -> Int { SeasonDates.daysBetween(start, today) + 1 }
    func visible(_ today: String) -> Bool {
        let n = dayNumber(today)
        return n >= 1 - announceDays && n <= dayCount + afterDays
    }
    func dateOf(_ day: Int) -> String { SeasonDates.plusDays(start, day - 1) }
}

struct SeasonProgress {
    let walk: SeasonWalk
    let dayNumber: Int
    let km: Double
    let todayKm: Double
    let plannedKm: Double
    let near: SeasonStop
    let next: SeasonStop?
    var started: Bool { dayNumber >= 1 }
    var ended: Bool { dayNumber > walk.dayCount }
    var arrived: Bool { km >= walk.routeKm }
    var fraction: Double { min(1, max(0, km / walk.routeKm)) }
    var today: SeasonDay? { (1...max(1, walk.dayCount)).contains(dayNumber) ? walk.days[dayNumber - 1] : nil }
    var aheadKm: Double { km - plannedKm }
}

enum SeasonWalks {
    static let strideKm = 0.000762

    static let advent2026 = SeasonWalk(
        id: "advent_2026", title: "Walk to Bethlehem", emoji: "⭐", season: "Advent", start: "2026-11-29", routeKm: 145,
        stops: [SeasonStop(atKm: 0, name: "Nazareth"), SeasonStop(atKm: 20, name: "the Jezreel Valley"),
                SeasonStop(atKm: 40, name: "Beth-shean"), SeasonStop(atKm: 75, name: "the Jordan River"),
                SeasonStop(atKm: 112, name: "Jericho"), SeasonStop(atKm: 136, name: "Jerusalem"),
                SeasonStop(atKm: 145, name: "Bethlehem")],
        days: ADVENT_DAYS,
        destination: "Bethlehem", fromTo: "From Nazareth to Bethlehem",
        pitch: "Walk the road Mary and Joseph took, from Nazareth to Bethlehem",
        arriveBy: "Christmas Eve", celebrate: "Merry Christmas!")

    static let newYear2027 = SeasonWalk(
        id: "newyear_2027", title: "21 Days of Prayer and Movement", emoji: "🌅", season: "New Year", start: "2027-01-01", routeKm: 150,
        stops: [SeasonStop(atKm: 0, name: "Kadesh-barnea"), SeasonStop(atKm: 45, name: "Mount Hor"),
                SeasonStop(atKm: 85, name: "the plains of Moab"), SeasonStop(atKm: 115, name: "Mount Nebo"),
                SeasonStop(atKm: 135, name: "the Jordan River"), SeasonStop(atKm: 150, name: "the Promised Land")],
        days: NEW_YEAR_DAYS, afterDays: 0,
        destination: "the Promised Land", fromTo: "From the wilderness to the Promised Land",
        pitch: "Start the year with 21 days of prayer and walking, from the wilderness to the Promised Land",
        arriveBy: "January 21", celebrate: "You finished the 21 days!", freeDays: 7)

    static let stressWeek2027 = SeasonWalk(
        id: "stress_week_2027", title: "Stress to Peace Week", emoji: "🕊️", season: "Peace", start: "2027-01-25", routeKm: 21,
        stops: [SeasonStop(atKm: 0, name: "the storm"), SeasonStop(atKm: 5, name: "the shore"),
                SeasonStop(atKm: 10, name: "green pastures"), SeasonStop(atKm: 16, name: "still waters"),
                SeasonStop(atKm: 21, name: "perfect peace")],
        days: STRESS_WEEK_DAYS, afterDays: 0,
        destination: "perfect peace", fromTo: "From the storm to still waters",
        pitch: "Spend a week turning stress into peace: a short prayer, a breath, and a Calm check every day",
        arriveBy: "January 31", celebrate: "You made it to still waters!", freeDays: 3)

    static let lent2027 = SeasonWalk(
        id: "lent_2027", title: "Walk to Jerusalem", emoji: "✝️", season: "Lent", start: "2027-02-10", routeKm: 190,
        stops: [SeasonStop(atKm: 0, name: "Capernaum"), SeasonStop(atKm: 12, name: "Magdala"),
                SeasonStop(atKm: 60, name: "Beth-shean"), SeasonStop(atKm: 110, name: "the Jordan crossing"),
                SeasonStop(atKm: 160, name: "Jericho"), SeasonStop(atKm: 182, name: "Bethany"),
                SeasonStop(atKm: 190, name: "Jerusalem")],
        days: LENT_DAYS, afterDays: 0,
        destination: "Jerusalem", fromTo: "From Capernaum to Jerusalem",
        pitch: "Walk with Jesus on His last journey, from Galilee to Jerusalem",
        arriveBy: "Holy Saturday", celebrate: "He is risen tomorrow!")

    static let easter2027 = SeasonWalk(
        id: "easter_2027", title: "Road to Emmaus", emoji: "🌅", season: "Easter", start: "2027-03-28", routeKm: 22,
        stops: [SeasonStop(atKm: 0, name: "Jerusalem"), SeasonStop(atKm: 5, name: "the road west"),
                SeasonStop(atKm: 11, name: "Emmaus"), SeasonStop(atKm: 17, name: "the road home"),
                SeasonStop(atKm: 22, name: "Jerusalem")],
        days: EASTER_DAYS, announceDays: 0,
        destination: "Emmaus and back", fromTo: "From Jerusalem to Emmaus and back",
        pitch: "Walk the road to Emmaus, where the risen Jesus walked beside two friends",
        arriveBy: "next Saturday", celebrate: "He is risen indeed!")

    static let all: [SeasonWalk] = [advent2026, newYear2027, stressWeek2027, lent2027, easter2027]

    /// The season walk to show around `today`: one under way first, then the next one coming, then the last one ended.
    static func current(_ today: String) -> SeasonWalk? {
        let shown = all.filter { $0.visible(today) }
        if let w = shown.first(where: { (1...$0.dayCount).contains($0.dayNumber(today)) }) { return w }
        if let w = shown.filter({ $0.dayNumber(today) < 1 }).max(by: { $0.dayNumber(today) < $1.dayNumber(today) }) { return w }
        return shown.min(by: { $0.dayNumber(today) < $1.dayNumber(today) })
    }

    static func progress(_ walk: SeasonWalk, history: [String: Int], todaySteps: Int, today: String) -> SeasonProgress {
        let n = walk.dayNumber(today)
        var steps = 0
        if n >= 1 {
            for i in 0..<min(n, walk.dayCount) {
                let date = walk.dateOf(i + 1)
                let counted = history[date] ?? 0
                steps += max(0, date == today ? max(counted, todaySteps) : counted)
            }
        }
        let km = Double(steps) * strideKm
        let todayKm = (1...walk.dayCount).contains(n) ? Double(max(0, max(history[today] ?? 0, todaySteps))) * strideKm : 0
        let planned = walk.dailyKm * Double(min(max(n, 0), walk.dayCount))
        let along = min(km, walk.routeKm)
        let near = walk.stops.last(where: { $0.atKm <= along }) ?? walk.stops[0]
        let next = walk.stops.first(where: { $0.atKm > along })
        return SeasonProgress(walk: walk, dayNumber: n, km: km, todayKm: todayKm, plannedKm: planned, near: near, next: next)
    }

    static func stepsFor(km: Double) -> Int { Int(km / strideKm) }
}

/// yyyy-MM-dd arithmetic in the proleptic Gregorian calendar (days since 1970-01-01).
enum SeasonDates {
    static func epochDay(_ ymd: String) -> Int {
        let p = ymd.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return 0 }
        let y = p[0], m = p[1], d = p[2]
        let yy = m <= 2 ? y - 1 : y
        let era = (yy >= 0 ? yy : yy - 399) / 400
        let yoe = yy - era * 400
        let mp = (m + 9) % 12
        let doy = (153 * mp + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }
    static func ofEpochDay(_ day: Int) -> String {
        let z = day + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        let y = yoe + era * 400 + (m <= 2 ? 1 : 0)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
    static func plusDays(_ ymd: String, _ n: Int) -> String { ofEpochDay(epochDay(ymd) + n) }
    static func daysBetween(_ from: String, _ to: String) -> Int { epochDay(to) - epochDay(from) }

    private static let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private static let weekdays = ["Thursday", "Friday", "Saturday", "Sunday", "Monday", "Tuesday", "Wednesday"]
    static func longDay(_ ymd: String) -> String {
        let p = ymd.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return ymd }
        let wd = weekdays[((epochDay(ymd) % 7) + 7) % 7]
        return "\(wd), \(months[p[1] - 1]) \(p[2])"
    }
    static func shortDay(_ ymd: String) -> String {
        let p = ymd.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return ymd }
        return "\(months[p[1] - 1].prefix(3)) \(p[2])"
    }
}

/// Keeps the best step count seen for each day, so a 21-day walk survives HealthKit's short look-back and relaunches.
@MainActor final class SeasonSteps: ObservableObject {
    static let shared = SeasonSteps()
    @Published private(set) var history: [String: Int] = UserDefaults.standard.dictionary(forKey: "seasonSteps") as? [String: Int] ?? [:]
    func absorb(_ byDay: [String: Int], today: Int) {
        var h = history
        for (k, v) in byDay where v > (h[k] ?? 0) { h[k] = v }
        let t = AppStore.dayKey()
        if today > (h[t] ?? 0) { h[t] = today }
        guard h != history else { return }
        history = h
        UserDefaults.standard.set(h.filter { $0.key >= SeasonDates.plusDays(t, -400) }, forKey: "seasonSteps")
    }
}

let LENT_DAYS: [SeasonDay] = [
    SeasonDay("Set Your Face", "Luke 9:51",
        "And it came to pass, when the time was come that he should be received up, he stedfastly set his face to go to Jerusalem.",
        "Lent begins where Jesus' last journey began: in Galilee, with His face set toward Jerusalem. Forty days of walking with Him start with one decision to go.",
        "Jesus, I set my face to follow You this Lent, all the way to the cross and the empty tomb. Amen.",
        "As you walk today, tell God one thing you want to leave behind this Lent."),
    SeasonDay("He Remembers We Are Dust", "Psalm 103:14",
        "For he knoweth our frame; he remembereth that we are dust.",
        "The ashes of yesterday aren't meant to shame you. God knows exactly what you're made of, and He still calls you to walk with Him.",
        "Father, You know how weak I am. Thank You for being patient with me. Amen.",
        "Walk slowly for a few minutes and thank God for the breath in your lungs."),
    SeasonDay("Rend Your Heart", "Joel 2:13",
        "And rend your heart, and not your garments, and turn unto the LORD your God: for he is gracious and merciful, slow to anger, and of great kindness, and repenteth him of the evil.",
        "Lent isn't about looking holy. It's about turning your heart back toward a God who is slow to anger and quick to welcome you home.",
        "Lord, turn my heart toward You again. I trust Your kindness. Amen.",
        "With each corner you turn today, pray: \"Lord, I turn back to You.\""),
    SeasonDay("Into the Wilderness", "Matthew 4:1",
        "Then was Jesus led up of the Spirit into the wilderness to be tempted of the devil.",
        "Before Jesus did anything public, He spent forty days in the wilderness. Hard places aren't proof God has left you. Sometimes He leads you there to make you strong.",
        "Jesus, walk with me through my wilderness. Make me strong where I am weak. Amen.",
        "Notice a quiet, empty place on your walk. Ask God to meet you in the empty places of your life."),
    SeasonDay("Not by Bread Alone", "Matthew 4:4",
        "But he answered and said, It is written, Man shall not live by bread alone, but by every word that proceedeth out of the mouth of God.",
        "Jesus answered temptation with Scripture. What you feed your soul matters as much as what you feed your body.",
        "Lord, feed me with Your Word today. Let it be enough for me. Amen.",
        "Pick one verse from this week and repeat it in step with your walking."),
    SeasonDay("Follow Me", "Matthew 4:19",
        "And he saith unto them, Follow me, and I will make you fishers of men.",
        "By the Sea of Galilee, Jesus called fishermen with two words: follow me. He didn't hand them a plan, just an invitation to walk with Him.",
        "Jesus, I'll follow You today, even when I can't see where the road goes. Amen.",
        "Pray for one person you'd love to walk with you in faith."),
    SeasonDay("Our Father", "Matthew 6:9",
        "After this manner therefore pray ye, Our Father which art in heaven, Hallowed be thy name.",
        "Jesus taught His friends to pray to God as Father. You don't need fancy words to come close, only honest ones.",
        "Our Father, hallowed be Your name. Your kingdom come in my life today. Amen.",
        "Pray the Lord's Prayer slowly as you walk, one line per block or one line per minute."),
    SeasonDay("Where Your Treasure Is", "Matthew 6:21",
        "For where your treasure is, there will your heart be also.",
        "What we spend our time and money on shows what we love. Lent is a good time to look honestly and choose again.",
        "Lord, be my treasure. Loosen my grip on what I can't keep. Amen.",
        "As you pass homes and shops, thank God for one thing money can't buy."),
    SeasonDay("Enough for Today", "Matthew 6:34",
        "Take therefore no thought for the morrow: for the morrow shall take thought for the things of itself. Sufficient unto the day is the evil thereof.",
        "Worry borrows trouble from a day that hasn't come. Jesus gives you today, and grace for today.",
        "Father, I give You tomorrow. Help me walk well in today. Amen.",
        "Each time a worry comes up on your walk, hand it to God and take the next step."),
    SeasonDay("Ask, Seek, Knock", "Matthew 7:7",
        "Ask, and it shall be given you; seek, and ye shall find; knock, and it shall be opened unto you:",
        "Jesus invites persistence. Keep asking, keep seeking, keep knocking. Your Father loves to be asked.",
        "Lord, here is what I'm asking for today. I trust You with the answer. Amen.",
        "Name one request to God for every door you pass."),
    SeasonDay("Peace, Be Still", "Mark 4:39",
        "And he arose, and rebuked the wind, and said unto the sea, Peace, be still. And the wind ceased, and there was a great calm.",
        "The storm on the Sea of Galilee frightened even fishermen. One word from Jesus calmed it. He's in the boat with you too.",
        "Jesus, speak peace to the storm in me today. Amen.",
        "Breathe in for four steps and out for four steps, praying \"Peace, be still.\""),
    SeasonDay("Come and Rest", "Matthew 11:28",
        "Come unto me, all ye that labour and are heavy laden, and I will give you rest.",
        "It's Sunday, a day for rest. Jesus doesn't only call you to walk; He calls you to rest in Him.",
        "Jesus, I bring You what is heavy. Give me Your rest. Amen.",
        "Take a gentle walk today. Let it be a walk of rest, not of effort."),
    SeasonDay("Go in Peace", "Mark 5:34",
        "And he said unto her, Daughter, thy faith hath made thee whole; go in peace, and be whole of thy plague.",
        "A woman pushed through a crowd just to touch Jesus' clothes. He stopped everything to call her daughter. You are never just part of the crowd to Him.",
        "Jesus, I reach for You today. Make me whole. Amen.",
        "Pray for someone who is sick and tired of waiting for healing."),
    SeasonDay("The Bread of Life", "John 6:35",
        "And Jesus said unto them, I am the bread of life: he that cometh to me shall never hunger; and he that believeth on me shall never thirst.",
        "Jesus fed five thousand by the lake, then told them He was the bread they really needed. What are you hungry for today?",
        "Jesus, You are the bread I need. Satisfy my soul. Amen.",
        "If you pass a bakery, shop or kitchen, pray for families who don't have enough to eat."),
    SeasonDay("Be Not Afraid", "Matthew 14:27",
        "But straightway Jesus spake unto them, saying, Be of good cheer; it is I; be not afraid.",
        "Jesus came to His friends walking on the water in the dark. The thing that scared them was Him coming close.",
        "Jesus, when I'm afraid, help me hear You say, \"It is I.\" Amen.",
        "Walk somewhere near water if you can, and remember who walks with you."),
    SeasonDay("Who Do You Say I Am?", "Matthew 16:15-16",
        "He saith unto them, But whom say ye that I am? And Simon Peter answered and said, Thou art the Christ, the Son of the living God.",
        "Everyone had opinions about Jesus. He asked His friends for their own answer. Faith becomes yours when you answer for yourself.",
        "Jesus, You are the Christ, the Son of the living God. You are my Lord. Amen.",
        "Say out loud, or in your heart, who Jesus is to you as you walk."),
    SeasonDay("Take Up Your Cross", "Luke 9:23",
        "And he said to them all, If any man will come after me, let him deny himself, and take up his cross daily, and follow me.",
        "Following Jesus is a daily walk, not a one-time decision. Every day there's a small way to put others first.",
        "Lord, show me today's cross, and help me carry it with love. Amen.",
        "Look for one small sacrifice you can make for someone today."),
    SeasonDay("Hear Him", "Luke 9:35",
        "And there came a voice out of the cloud, saying, This is my beloved Son: hear him.",
        "On the mountain, the Father spoke only a few words: this is my Son; listen to Him. So much noise competes for your attention. Today, listen.",
        "Father, quiet the noise around me so I can hear Your Son. Amen.",
        "Walk part of today without headphones, listening for God."),
    SeasonDay("Like a Child", "Mark 10:14",
        "But when Jesus saw it, he was much displeased, and said unto them, Suffer the little children to come unto me, and forbid them not: for of such is the kingdom of God.",
        "The disciples thought children were a distraction. Jesus said they were the picture of His kingdom: trusting, open and close.",
        "Jesus, give me a child's trust in You. Bless the children in my life. Amen.",
        "Pray for the children you know by name as you walk."),
    SeasonDay("Seventy Times Seven", "Matthew 18:21-22",
        "Then came Peter to him, and said, Lord, how oft shall my brother sin against me, and I forgive him? till seven times? Jesus saith unto him, I say not unto thee, Until seven times: but, Until seventy times seven.",
        "Forgiveness isn't a score you keep. It's a road you keep walking, one choice at a time.",
        "Lord, help me forgive the person I'm thinking of right now. Amen.",
        "With each step, release a little of a hurt you've been carrying."),
    SeasonDay("Love God, Love Your Neighbor", "Luke 10:27",
        "And he answering said, Thou shalt love the Lord thy God with all thy heart, and with all thy soul, and with all thy strength, and with all thy mind; and thy neighbour as thyself.",
        "Jesus answered a lawyer's question with the story of the Good Samaritan. Your neighbor is whoever is in front of you and needs help.",
        "Lord, open my eyes to the neighbor who needs me today. Amen.",
        "Smile at, greet or help one person on your walk today."),
    SeasonDay("The Good Part", "Luke 10:41-42",
        "And Jesus answered and said unto her, Martha, Martha, thou art careful and troubled about many things: But one thing is needful: and Mary hath chosen that good part, which shall not be taken away from her.",
        "Martha was busy serving; Mary sat at Jesus' feet. Being busy for God can crowd out being with God.",
        "Jesus, I set aside my list for a while. I just want to be with You. Amen.",
        "Stop for one minute during your walk and simply be still with God."),
    SeasonDay("You Are Known", "Luke 12:7",
        "But even the very hairs of your head are all numbered. Fear not therefore: ye are of more value than many sparrows.",
        "God keeps count of what no one else notices. If He knows the number of hairs on your head, He knows what you're carrying.",
        "Father, thank You for knowing me completely and loving me anyway. Amen.",
        "Watch for birds on your walk, and remember how much more you are worth to God."),
    SeasonDay("Consider the Lilies", "Luke 12:27",
        "Consider the lilies how they grow: they toil not, they spin not; and yet I say unto you, that Solomon in all his glory was not arrayed like one of these.",
        "Jesus pointed at flowers to teach about trust. Creation is full of reminders that God provides.",
        "Lord, You care for the flowers. I trust You to care for me. Amen.",
        "Stop and really look at one plant or flower today, and thank God for it."),
    SeasonDay("The One Who Was Lost", "Luke 15:4",
        "What man of you, having an hundred sheep, if he lose one of them, doth not leave the ninety and nine in the wilderness, and go after that which is lost, until he find it?",
        "God doesn't give up on the one who wandered away. If that's you, He's already looking for you.",
        "Good Shepherd, find the ones I love who have wandered from You. Amen.",
        "Pray by name for someone far from God."),
    SeasonDay("The Father Ran", "Luke 15:20",
        "And he arose, and came to his father. But when he was yet a great way off, his father saw him, and had compassion, and ran, and fell on his neck, and kissed him.",
        "The son had a speech ready. The father didn't wait to hear it; he ran. That's how God welcomes you home.",
        "Father, thank You for running to meet me. I'm coming home. Amen.",
        "Walk a little faster for one stretch today and remember the Father who ran."),
    SeasonDay("The One Who Came Back", "Luke 17:15",
        "And one of them, when he saw that he was healed, turned back, and with a loud voice glorified God,",
        "Ten were healed; one came back to say thank you. Gratitude turns a blessing into a relationship.",
        "Lord, thank You for what You've done for me, especially for this: ... Amen.",
        "Count ten blessings on your walk, one for each of the ten who were healed."),
    SeasonDay("Be Merciful to Me", "Luke 18:13",
        "And the publican, standing afar off, would not lift up so much as his eyes unto heaven, but smote upon his breast, saying, God be merciful to me a sinner.",
        "The prayer God heard wasn't the impressive one. It was the honest one. You can pray it too.",
        "God, be merciful to me, a sinner. Amen.",
        "Pray this short prayer each time you stop to cross a street."),
    SeasonDay("Strong and Courageous", "Joshua 1:9",
        "Have not I commanded thee? Be strong and of a good courage; be not afraid, neither be thou dismayed: for the LORD thy God is with thee whithersoever thou goest.",
        "You're crossing the Jordan today, where Israel once crossed into the promised land. God gave Joshua courage for new ground, and He gives it to you.",
        "Lord, give me courage for what's ahead. You go with me. Amen.",
        "Take a route you don't usually walk, and pray for courage in something new."),
    SeasonDay("The Good Shepherd", "John 10:11",
        "I am the good shepherd: the good shepherd giveth his life for the sheep.",
        "A hired hand runs when danger comes. The Good Shepherd stays, and gives His life. Jesus is walking toward Jerusalem to do exactly that.",
        "Jesus, my Shepherd, thank You for laying down Your life for me. Amen.",
        "Pray Psalm 23 from memory, or as much as you know, while you walk."),
    SeasonDay("The Resurrection and the Life", "John 11:25",
        "Jesus said unto her, I am the resurrection, and the life: he that believeth in me, though he were dead, yet shall he live:",
        "Jesus said these words to Martha at her brother's grave, before He called Lazarus out. Death doesn't get the last word.",
        "Jesus, You are the resurrection and the life. I put my hope in You. Amen.",
        "Pray for someone grieving a loss this year."),
    SeasonDay("Jesus Wept", "John 11:35",
        "Jesus wept.",
        "The shortest verse in the Bible may be the most tender. Jesus knew He would raise Lazarus, and He still cried with His friends. Your tears matter to Him.",
        "Jesus, thank You for weeping with those who weep. Comfort the hurting today. Amen.",
        "If you're carrying sorrow, let yourself feel it on this walk, with Jesus beside you."),
    SeasonDay("What Do You Want?", "Mark 10:51",
        "And Jesus answered and said unto him, What wilt thou that I should do unto thee? The blind man said unto him, Lord, that I might receive my sight.",
        "Near Jericho, blind Bartimaeus shouted until Jesus stopped. Then Jesus asked him a simple question. He asks you the same one.",
        "Lord, here is what I want You to do for me: ... Amen.",
        "Answer Jesus' question honestly as you walk today."),
    SeasonDay("To Serve", "Mark 10:45",
        "For even the Son of man came not to be ministered unto, but to minister, and to give his life a ransom for many.",
        "The disciples argued about who was greatest. Jesus, on His way to the cross, showed them greatness looks like serving.",
        "Jesus, make me a servant like You. Show me who to serve today. Amen.",
        "Do one helpful thing for someone today, without being asked."),
    SeasonDay("Come Down Today", "Luke 19:5",
        "And when Jesus came to the place, he looked up, and saw him, and said unto him, Zacchaeus, make haste, and come down; for to day I must abide at thy house.",
        "Zacchaeus climbed a tree in Jericho just to see Jesus. Jesus stopped, looked up and called him by name.",
        "Jesus, come to my house today. Make Yourself at home in my life. Amen.",
        "If you pass a tree on your walk, remember Jesus sees you and calls you by name."),
    SeasonDay("Seeking the Lost", "Luke 19:10",
        "For the Son of man is come to seek and to save that which was lost.",
        "Everyone in Jericho had given up on Zacchaeus. Jesus came looking for him. No one is too far gone for Jesus.",
        "Lord, use me to bring someone home to You. Amen.",
        "Pray for your city as you walk, street by street."),
    SeasonDay("I Lift My Eyes", "Psalm 121:1-2",
        "I will lift up mine eyes unto the hills, from whence cometh my help. My help cometh from the LORD, which made heaven and earth.",
        "The road from Jericho climbs steeply toward Jerusalem. Pilgrims sang this psalm on the way up. Your help comes from the Lord too.",
        "Lord, my help comes from You. Carry me up the hard climbs. Amen.",
        "Find a hill or some stairs today, and pray Psalm 121 on the climb."),
    SeasonDay("The Way", "John 14:6",
        "Jesus saith unto him, I am the way, the truth, and the life: no man cometh unto the Father, but by me.",
        "When the disciples didn't know the way, Jesus told them He was the way. You don't need a map when you're walking with Him.",
        "Jesus, You are my way. Lead me to the Father. Amen.",
        "Walk without planning your route today, and trust God with every turn."),
    SeasonDay("My Peace I Give You", "John 14:27",
        "Peace I leave with you, my peace I give unto you: not as the world giveth, give I unto you. Let not your heart be troubled, neither let it be afraid.",
        "You're nearly at Bethany, just over the hill from Jerusalem. Jesus knew what was coming, and still He gave His friends peace.",
        "Jesus, let Your peace guard my heart this week. Amen.",
        "Get ready for Holy Week: pray for a heart that is quiet and open."),
    SeasonDay("Palm Sunday", "Matthew 21:9",
        "And the multitudes that went before, and that followed, cried, saying, Hosanna to the Son of David: Blessed is he that cometh in the name of the Lord; Hosanna in the highest.",
        "Jesus rode into Jerusalem on a donkey while the crowd waved palms and shouted Hosanna, which means \"save us.\" He came to do exactly that.",
        "Hosanna, Jesus! Blessed is He who comes in the name of the Lord. Save us. Amen.",
        "Wave a hand or lift your eyes as you walk, and welcome Jesus as King."),
    SeasonDay("A House of Prayer", "Matthew 21:13",
        "And said unto them, It is written, My house shall be called the house of prayer; but ye have made it a den of thieves.",
        "Jesus cleared the temple so people could pray again. He wants to clear what crowds out prayer in your life too.",
        "Lord, clear out what crowds You out of my heart. Make me a house of prayer. Amen.",
        "Pray for your church as you walk past any church today."),
    SeasonDay("All She Had", "Mark 12:43",
        "And he called unto him his disciples, and saith unto them, Verily I say unto you, That this poor widow hath cast more in, than all they which have cast into the treasury:",
        "Jesus noticed the smallest gift in the temple because it was everything she had. God measures love, not amounts.",
        "Lord, I give You all I have today, small as it is. Amen.",
        "Give something today: time, money or kindness, with your whole heart."),
    SeasonDay("A Good Work", "Mark 14:6",
        "And Jesus said, Let her alone; why trouble ye her? she hath wrought a good work on me.",
        "In Bethany, a woman poured costly perfume on Jesus. Others called it a waste. Jesus called it beautiful. Love that costs something is never wasted.",
        "Jesus, may my love for You be extravagant, not careful. Amen.",
        "Do something generous today that only God will see."),
    SeasonDay("Love One Another", "John 13:34",
        "A new commandment I give unto you, That ye love one another; as I have loved you, that ye also love one another.",
        "On the night before He died, Jesus washed His friends' feet, shared bread and wine, and gave them one command: love one another as I have loved you.",
        "Jesus, thank You for the bread and the cup, and for loving me to the end. Teach me to love like You. Amen.",
        "Walk slowly tonight and remember Jesus praying in the garden of Gethsemane."),
    SeasonDay("Good Friday", "Luke 23:34",
        "Then said Jesus, Father, forgive them; for they know not what they do.",
        "From the cross, Jesus prayed for the people putting Him there. This is the love you've been walking toward all Lent.",
        "Jesus, thank You for the cross. Thank You for forgiving me. Amen.",
        "Take a quiet walk today. At three o'clock, stop for a moment of silence."),
    SeasonDay("Waiting at the Tomb", "Lamentations 3:22-23",
        "It is of the LORD'S mercies that we are not consumed, because his compassions fail not. They are new every morning: great is thy faithfulness.",
        "Holy Saturday is a day of silence and waiting. The disciples didn't know what tomorrow would bring. You do: morning is coming.",
        "Lord, in the silence and the waiting, I trust Your faithfulness. Amen.",
        "Walk at dusk if you can, and watch for tomorrow's morning in your heart.")
]

let EASTER_DAYS: [SeasonDay] = [
    SeasonDay("He Is Risen", "Matthew 28:6",
        "He is not here: for he is risen, as he said. Come, see the place where the Lord lay.",
        "The tomb is empty! Everything you walked toward through Lent comes to this: Jesus is alive. This week, walk the road where two friends met Him.",
        "Risen Jesus, You are alive and You are with me. Hallelujah! Amen.",
        "Walk in the morning light today and celebrate: He is risen!"),
    SeasonDay("He Drew Near", "Luke 24:15",
        "And it came to pass, that, while they communed together and reasoned, Jesus himself drew near, and went with them.",
        "Two friends walked away from Jerusalem, heartbroken and confused. Jesus joined them on the road, even though they didn't recognize Him.",
        "Jesus, walk with me, even when I don't recognize You. Amen.",
        "Invite a friend to walk with you, and talk about what God is doing."),
    SeasonDay("All the Scriptures", "Luke 24:27",
        "And beginning at Moses and all the prophets, he expounded unto them in all the scriptures the things concerning himself.",
        "On a seven-mile walk, Jesus taught the whole Bible, and every page pointed to Him.",
        "Lord, open the Scriptures to me, and show me Jesus on every page. Amen.",
        "Listen to a Bible passage on your walk today."),
    SeasonDay("Abide With Us", "Luke 24:29",
        "But they constrained him, saying, Abide with us: for it is toward evening, and the day is far spent. And he went in to tarry with them.",
        "As evening came, they begged the stranger to stay. Jesus always says yes to that prayer.",
        "Jesus, stay with me. It's toward evening, and I need You. Amen.",
        "Take an evening walk and invite Jesus into your home tonight."),
    SeasonDay("Known in the Breaking of Bread", "Luke 24:30-31",
        "And it came to pass, as he sat at meat with them, he took bread, and blessed it, and brake it, and gave to them. And their eyes were opened, and they knew him; and he vanished out of their sight.",
        "They recognized Jesus when He broke the bread, just as He had at the Last Supper. He often shows Himself in ordinary moments.",
        "Lord, open my eyes to see You in my ordinary days. Amen.",
        "Share a meal with someone this week and thank God together."),
    SeasonDay("Hearts on Fire", "Luke 24:32",
        "And they said one to another, Did not our heart burn within us, while he talked with us by the way, and while he opened to us the scriptures?",
        "Looking back, they realized their hearts had been burning the whole way. God is often at work before we notice.",
        "Jesus, set my heart on fire for You again. Amen.",
        "Think back over your walks this Lent and Easter: where was God at work?"),
    SeasonDay("The Lord Is Risen Indeed", "Luke 24:33-34",
        "And they rose up the same hour, and returned to Jerusalem, and found the eleven gathered together, and them that were with them, Saying, The Lord is risen indeed, and hath appeared to Simon.",
        "They couldn't wait until morning. They walked all the way back to Jerusalem that night to tell the others. Good news makes you walk fast.",
        "Lord, give me courage to tell someone what You've done. You are risen indeed! Amen.",
        "Tell one person this week why Easter matters to you.")
]

let NEW_YEAR_DAYS: [SeasonDay] = [
    SeasonDay("Be Strong and Courageous", "Joshua 1:9",
        "Have not I commanded thee? Be strong and of a good courage; be not afraid, neither be thou dismayed: for the LORD thy God is with thee whithersoever thou goest.",
        "A new year is a road you have never walked. God does not hand you a map for all of it. He promises something better: He goes with you, every step.",
        "Lord, I start this year with You beside me. Make me brave for what I cannot see yet. Amen.",
        "Take your first steps slowly and say out loud, \"God is with me.\""),
    SeasonDay("New Every Morning", "Lamentations 3:22-23",
        "It is of the LORD'S mercies that we are not consumed, because his compassions fail not. They are new every morning: great is thy faithfulness.",
        "Yesterday's mistakes do not follow you into this morning. Mercy arrives fresh each day, before you have done anything to earn it.",
        "Father, thank You that Your mercy is new today. Help me begin again without shame. Amen.",
        "As you walk, name one thing God forgave you for, and leave it behind on the road."),
    SeasonDay("Ordered Steps", "Psalm 37:23",
        "The steps of a good man are ordered by the LORD: and he delighteth in his way.",
        "You do not have to see the whole path. God orders the steps, one at a time, and He is pleased to walk with the one who follows.",
        "Lord, order my steps today. I trust You with the next one. Amen.",
        "Pray for the very next step in front of you, then take it."),
    SeasonDay("Strength That Renews", "Isaiah 40:31",
        "But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.",
        "Tired is not the end of the story. Waiting on God is not wasted time. It is where strength comes back.",
        "God, I am tired in places I do not say out loud. Renew my strength today. Amen.",
        "Pause halfway, breathe slowly three times, and ask God for fresh strength."),
    SeasonDay("Trust Him With All", "Proverbs 3:5-6",
        "Trust in the LORD with all thine heart; and lean not unto thine own understanding. In all thy ways acknowledge him, and he shall direct thy paths.",
        "Trusting God is not turning off your mind. It is deciding that His wisdom is bigger than your worry, and handing Him the steering wheel.",
        "Lord, I give You the thing I keep trying to control. Direct my path. Amen.",
        "Name one worry as you walk, and hand it to God with every step."),
    SeasonDay("Forgetting What Is Behind", "Philippians 3:13-14",
        "Brethren, I count not myself to have apprehended: but this one thing I do, forgetting those things which are behind, and reaching forth unto those things which are before, I press toward the mark for the prize of the high calling of God in Christ Jesus.",
        "Paul had a past he could have been stuck in. He chose to press on. You can too: the road is in front of you.",
        "Jesus, free me from what is behind me. Help me press on today. Amen.",
        "Walk a little faster for the last few minutes, as a picture of pressing forward."),
    SeasonDay("A Lamp for Your Feet", "Psalm 119:105",
        "Thy word is a lamp unto my feet, and a light unto my path.",
        "A lamp does not light the whole road. It lights enough for the next steps. God's Word works the same way.",
        "Lord, give me enough light for today. Let Your Word guide me. Amen.",
        "Read today's verse slowly once before you start, and carry one line with you."),
    SeasonDay("A Way in the Wilderness", "Isaiah 43:19",
        "Behold, I will do a new thing; now it shall spring forth; shall ye not know it? I will even make a way in the wilderness, and rivers in the desert.",
        "Maybe this season feels like a desert. God specializes in making roads where there are none and water where it is dry.",
        "God, I am looking for the way You are making. Open my eyes to it. Amen.",
        "Look for something small and alive on your walk, a bird, a bud, a patch of green, and thank God for it."),
    SeasonDay("First Things First", "Matthew 6:33",
        "But seek ye first the kingdom of God, and his righteousness; and all these things shall be added unto you.",
        "Most of us give God what is left of the day. Jesus says to start with Him, and trust the rest to fall into place.",
        "Lord, You come first today. Order everything else around You. Amen.",
        "Pray before you check your phone, then walk."),
    SeasonDay("Your Body Is a Temple", "1 Corinthians 6:19-20",
        "What? know ye not that your body is the temple of the Holy Ghost which is in you, which ye have of God, and ye are not your own? For ye are bought with a price: therefore glorify God in your body, and in your spirit, which are God's.",
        "Looking after your body is not vanity. It is stewardship of the home God has given you.",
        "Father, help me care for this body as a gift from You. Amen.",
        "Walk today as an act of worship, and thank God for each part that carries you."),
    SeasonDay("Rest and Safety", "Psalm 4:8",
        "I will both lay me down in peace, and sleep: for thou, LORD, only makest me dwell in safety.",
        "Sleep is an act of trust. When you lay it all down, you are saying that God is awake so you do not have to be.",
        "Lord, teach me to rest. I give You tonight, and everything in it. Amen.",
        "Take a slow, gentle walk today, and pray one line before bed: \"You hold tonight.\""),
    SeasonDay("Pray About Everything", "Philippians 4:6-7",
        "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God. And the peace of God, which passeth all understanding, shall keep your hearts and minds through Christ Jesus.",
        "Worry and prayer can't live in the same place for long. Tell God everything, with thanks, and His peace will stand guard over your heart.",
        "God, here is everything on my mind. I give it to You, with thanks. Guard me with Your peace. Amen.",
        "Pray out loud as you walk, one request for every few minutes, and end each with \"thank You.\""),
    SeasonDay("Do Not Grow Weary", "Galatians 6:9",
        "And let us not be weary in well doing: for in due season we shall reap, if we faint not.",
        "You are almost two weeks in. This is the point where many stop. Small, faithful steps are exactly how harvests happen.",
        "Lord, keep me going when the excitement fades. I will keep walking. Amen.",
        "Finish today's walk even if you have to shorten it. Showing up is the win."),
    SeasonDay("Better Together", "Ecclesiastes 4:9-10",
        "Two are better than one; because they have a good reward for their labour. For if they fall, the one will lift up his fellow: but woe to him that is alone when he falleth; for he hath not another to help him up.",
        "God never meant the walk of faith to be solo. Someone near you needs a hand up, or is ready to give you one.",
        "Lord, send me someone to walk with, and show me someone to lift. Amen.",
        "Invite a friend or family member to walk with you, or send them today's verse."),
    SeasonDay("Eyes to the Hills", "Psalm 121:1-2",
        "I will lift up mine eyes unto the hills, from whence cometh my help. My help cometh from the LORD, which made heaven and earth.",
        "When life feels heavy, we look down. This psalm says look up. Your help is bigger than the problem.",
        "Lord, I lift my eyes to You. You are my help. Amen.",
        "Look up at the sky or the horizon for a full minute, and pray with your eyes open."),
    SeasonDay("Be Still", "Psalm 46:10",
        "Be still, and know that I am God: I will be exalted among the heathen, I will be exalted in the earth.",
        "Sometimes the most faithful thing is to stop. In the stillness, you remember who is God, and that it isn't you.",
        "God, I stop. I know You are God. Quiet my heart. Amen.",
        "Walk without music or your phone, and listen to the sounds around you."),
    SeasonDay("Work as for the Lord", "Colossians 3:23",
        "And whatsoever ye do, do it heartily, as to the Lord, and not unto men;",
        "Ordinary work becomes holy when it is done for God. Your job, your home and your habits can all be worship.",
        "Lord, I offer today's work to You. Let me do it with all my heart. Amen.",
        "Choose one ordinary task today and do it as if Jesus were watching, because He is."),
    SeasonDay("Renewed Mind", "Romans 12:2",
        "And be not conformed to this world: but be ye transformed by the renewing of your mind, that ye may prove what is that good, and acceptable, and perfect, will of God.",
        "Change starts in the mind. The more you fill it with God's truth, the less the world's noise gets to say who you are.",
        "Father, renew my mind. Replace the lies I believe with Your truth. Amen.",
        "Every time a negative thought comes up on your walk, answer it with today's verse."),
    SeasonDay("He Will Not Forsake You", "Deuteronomy 31:6",
        "Be strong and of a good courage, fear not, nor be afraid of them: for the LORD thy God, he it is that doth go with thee; he will not fail thee, nor forsake thee.",
        "Three weeks ago you set out. He has not left you for a single step. He will not fail you, and He will not leave you.",
        "Lord, thank You for walking with me this whole way. I will not fear. Amen.",
        "Look back at where you started on your route and thank God for how far you have come."),
    SeasonDay("Forget Not His Benefits", "Psalm 103:2",
        "Bless the LORD, O my soul, and forget not all his benefits:",
        "Gratitude turns a walk into worship. Counting blessings does not make problems vanish, but it shows you who is carrying them with you.",
        "Lord, I bless You. Remind me of every good thing You have done. Amen.",
        "Name one thing you are thankful for every minute of your walk."),
    SeasonDay("All Came to Pass", "Joshua 21:45",
        "There failed not ought of any good thing which the LORD had spoken unto the house of Israel; all came to pass.",
        "You made it. Twenty-one days of prayer and movement, and God was faithful in every one. Carry this habit into the rest of the year.",
        "Lord, thank You for walking with me through these twenty-one days. Keep me walking with You all year. Amen.",
        "Take a victory walk today. Thank God out loud, and decide what your next small step will be.")
]

let STRESS_WEEK_DAYS: [SeasonDay] = [
    SeasonDay("The Shepherd Leads You", "Psalm 23:1-2",
        "The LORD is my shepherd; I shall not want. He maketh me to lie down in green pastures: he leadeth me beside the still waters.",
        "Stress tells you that you have to carry everything. The shepherd says lie down. Today is about letting Someone else lead.",
        "Lord, You are my shepherd. Lead me to rest today. Amen.",
        "Open Calm check and take a 30-second reading before you pray, then another after. Then walk slowly and say, \"I shall not want.\""),
    SeasonDay("Come and Rest", "Matthew 11:28",
        "Come unto me, all ye that labour and are heavy laden, and I will give you rest.",
        "Jesus does not say, \"Fix yourself, then come.\" He says come as you are, heavy and tired, and He gives rest.",
        "Jesus, I am tired. I come to You, just as I am. Give me rest. Amen.",
        "Open Calm check and take a 30-second reading before you pray, then another after. Take a gentle ten-minute walk, and name what feels heavy."),
    SeasonDay("Hand Over Your Cares", "1 Peter 5:7",
        "Casting all your care upon him; for he careth for you.",
        "To cast is to throw. You are allowed to hand your worries over, because He cares about you, and not only about the problem.",
        "Father, I hand You my worries one at a time. Thank You for caring about me. Amen.",
        "Open Calm check and take a 30-second reading before you pray, then another after. With each step, drop one worry into God's hands."),
    SeasonDay("Peace, Be Still", "Mark 4:39",
        "And he arose, and rebuked the wind, and said unto the sea, Peace, be still. And the wind ceased, and there was a great calm.",
        "The storm was real and the disciples were afraid. One word from Jesus brought a great calm. He can speak into yours too.",
        "Jesus, speak peace into my storm. Quiet my heart. Amen.",
        "Open Calm check and take a 30-second reading before you pray, then another after. Use the breath pacer for two minutes, then walk slowly with your shoulders relaxed."),
    SeasonDay("Perfect Peace", "Isaiah 26:3",
        "Thou wilt keep him in perfect peace, whose mind is stayed on thee: because he trusteth in thee.",
        "Peace is not the absence of problems. It is a mind that keeps coming back to God. Each time you turn back, you practice peace.",
        "Lord, keep my mind on You. When it wanders, bring me back. Amen.",
        "Open Calm check and take a 30-second reading before you pray, then another after. Each time your mind races on your walk, whisper \"You keep me in peace\" and keep walking."),
    SeasonDay("Peace I Leave With You", "John 14:27",
        "Peace I leave with you, my peace I give unto you: not as the world giveth, give I unto you. Let not your heart be troubled, neither let it be afraid.",
        "The world's peace depends on things going well. This peace is a gift that stays when they do not.",
        "Jesus, thank You for Your peace. I receive it today. Amen.",
        "Open Calm check and take a 30-second reading before you pray, then another after. Walk outside if you can, and breathe in slowly for four steps and out for six."),
    SeasonDay("The Lord Gives Peace", "Numbers 6:24-26",
        "The LORD bless thee, and keep thee: The LORD make his face shine upon thee, and be gracious unto thee: The LORD lift up his countenance upon thee, and give thee peace.",
        "You made it through a week of stopping to breathe and pray. Look at your Calm checks. Notice what calmed you, and keep that habit.",
        "Lord, bless me and keep me. Give me Your peace, today and all year. Amen.",
        "Open Calm check and take a 30-second reading before you pray, then another after. Compare your first and last readings, then take a thankful walk.")
]

let ADVENT_DAYS: [SeasonDay] = [
    SeasonDay("A Light in the Dark", "Isaiah 9:2",
        "The people that walked in darkness have seen a great light: they that dwell in the land of the shadow of death, upon them hath the light shined.",
        "Advent begins in the dark, on purpose. Before the manger there was a long night of waiting, and God promised it would end in light. Whatever feels dark for you this year, the promise is the same.",
        "Lord, I start this road in the dark places of my life. Be the light I walk toward. Amen.",
        "As you walk today, look for light: a window, a streetlamp, the sky. Each one is a small promise."),
    SeasonDay("God With Us", "Isaiah 7:14",
        "Therefore the Lord himself shall give you a sign; Behold, a virgin shall conceive, and bear a son, and shall call his name Immanuel.",
        "Immanuel means God with us. Not God watching from far away, but God close enough to walk beside you. Mary and Joseph didn't take a single step of their journey alone, and neither do you.",
        "Immanuel, thank You for being with me on every road. Help me notice You today. Amen.",
        "Walk today as if Someone is walking next to you, and talk to Him like a friend."),
    SeasonDay("Little Bethlehem", "Micah 5:2",
        "But thou, Bethlehem Ephratah, though thou be little among the thousands of Judah, yet out of thee shall he come forth unto me that is to be ruler in Israel; whose goings forth have been from of old, from everlasting.",
        "God chose a small town for the biggest moment in history. Bethlehem was easy to overlook, and God picked it anyway. If you feel small or unnoticed, you are exactly the kind of place God loves to work.",
        "Father, use the small, ordinary parts of my life for Your glory. Amen.",
        "Notice something small on your walk today that you would usually pass by."),
    SeasonDay("Walk and Not Faint", "Isaiah 40:31",
        "But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.",
        "This verse ends with walking. Not running, not flying: walking, steady and ordinary, one step after another. Long journeys aren't finished on bursts of strength, but by God renewing you along the way.",
        "Lord, renew my strength for today's steps, in my body and in my faith. Amen.",
        "When you feel tired today, say it under your breath: they shall walk, and not faint."),
    SeasonDay("An Expected End", "Jeremiah 29:11",
        "For I know the thoughts that I think toward you, saith the LORD, thoughts of peace, and not of evil, to give you an expected end.",
        "God spoke these words to people far from home, in a season they didn't choose. His thoughts toward them were peace, and He had an end in mind. Your road has a destination too, even when you can't see it yet.",
        "God, I trust that You know where my road leads. Give me peace for the miles I can't see. Amen.",
        "Pick a point ahead of you on your walk, and pray for your future as you walk toward it."),
    SeasonDay("A Branch from the Stump", "Isaiah 11:1",
        "And there shall come forth a rod out of the stem of Jesse, and a Branch shall grow out of his roots.",
        "Jesse's family tree looked cut down to a stump, with nothing left to hope for. But God grew something new from what looked dead. Nothing in your life is too far gone for Him to bring back to life.",
        "Lord, breathe new life into whatever in me feels cut down. Amen.",
        "Look for something green or growing today, and thank God for new beginnings."),
    SeasonDay("Waiting Well", "Psalm 130:5",
        "I wait for the LORD, my soul doth wait, and in his word do I hope.",
        "Waiting is most of the Christmas story. Israel waited for centuries, Mary waited nine months, and Simeon waited a lifetime. Waiting isn't wasted time when your hope is in God's word.",
        "Lord, teach me to wait with hope instead of worry. Amen.",
        "Walk a little slower today, and use the pace to be still with God."),
    SeasonDay("Prince of Peace", "Isaiah 9:6",
        "For unto us a child is born, unto us a son is given: and the government shall be upon his shoulder: and his name shall be called Wonderful, Counsellor, The mighty God, The everlasting Father, The Prince of Peace.",
        "Every name in this verse answers a need: wisdom when you're lost, strength when you're weak, a Father when you feel alone, peace when you're anxious. Which name do you need most this week?",
        "Prince of Peace, rule over the anxious places in my heart. Amen.",
        "Take one name of Jesus from this verse on your walk, and pray it with every few steps."),
    SeasonDay("Prepare the Way", "Isaiah 40:3",
        "The voice of him that crieth in the wilderness, Prepare ye the way of the LORD, make straight in the desert a highway for our God.",
        "Before Jesus came, God sent a voice to prepare the way. Roads were made straight so the King could come. Advent asks what needs clearing in our own hearts so He can come in.",
        "Lord, show me what stands between You and me, and help me clear it. Amen.",
        "As you walk, ask God to show you one thing to set right this week."),
    SeasonDay("Your Prayer Is Heard", "Luke 1:13",
        "But the angel said unto him, Fear not, Zacharias: for thy prayer is heard; and thy wife Elisabeth shall bear thee a son, and thou shalt call his name John.",
        "Zacharias and Elisabeth had prayed for a child for years, and the answer came when they were old. God heard every one of those prayers, even the ones that seemed to go nowhere. Your long prayers are heard too.",
        "Father, I bring You the prayer I've prayed the longest. Thank You that You hear it. Amen.",
        "Use today's walk for one long prayer you haven't given up on."),
    SeasonDay("Nothing Impossible", "Luke 1:37",
        "For with God nothing shall be impossible.",
        "The angel said this to a young woman facing the impossible. Mary didn't need to understand how; she needed to know who was promising. What feels impossible in your life is not too hard for God.",
        "Lord, I give You what feels impossible. I trust You with it. Amen.",
        "If you can, add a few minutes to today's walk, and thank God for every one of them."),
    SeasonDay("Be It unto Me", "Luke 1:38",
        "And Mary said, Behold the handmaid of the Lord; be it unto me according to thy word. And the angel departed from her.",
        "Mary's yes cost her a lot: her reputation, her plans, her comfort. She said it anyway, because she trusted the One who asked. Saying yes to God rarely makes life easier, but it always makes it fuller.",
        "Lord, here I am. Let it be to me according to Your word. Amen.",
        "Ask God on your walk where He is asking for your yes."),
    SeasonDay("Perfect Peace", "Isaiah 26:3",
        "Thou wilt keep him in perfect peace, whose mind is stayed on thee: because he trusteth in thee.",
        "The peace in this verse doesn't come from a calm life. It comes from a mind stayed on God. The roads to Bethlehem were busy and loud, and peace was still possible on them.",
        "Lord, keep my mind on You today, and keep me in Your peace. Amen.",
        "Each time your mind wanders on today's walk, gently bring it back to God."),
    SeasonDay("Not as the World Gives", "John 14:27",
        "Peace I leave with you, my peace I give unto you: not as the world giveth, give I unto you. Let not your heart be troubled, neither let it be afraid.",
        "The world's peace depends on everything going right. Jesus offers a peace that holds when things go wrong. December can be crowded and stressful, and His peace is still on offer in the middle of it.",
        "Jesus, I receive Your peace for the busy days ahead. Let my heart not be troubled. Amen.",
        "Leave your phone in your pocket for part of today's walk, and rest in His peace."),
    SeasonDay("My Soul Magnifies", "Luke 1:46-47",
        "And Mary said, My soul doth magnify the Lord, And my spirit hath rejoiced in God my Saviour.",
        "Mary's song comes before the birth, before anything is easy. Her joy wasn't in her circumstances but in God her Saviour. Joy can start before the answer arrives.",
        "My soul magnifies You, Lord, and my spirit rejoices in You, my Saviour. Amen.",
        "Sing or hum a song of praise as you walk today, even quietly."),
    SeasonDay("Leaping for Joy", "Luke 1:41",
        "And it came to pass, that, when Elisabeth heard the salutation of Mary, the babe leaped in her womb; and Elisabeth was filled with the Holy Ghost.",
        "When Mary walked into Elisabeth's house, the baby in Elisabeth's womb leaped for joy. Two women, both carrying promises, encouraged each other. Faith grows when we share it.",
        "Lord, lead me to someone I can encourage today, and someone who can encourage me. Amen.",
        "Invite someone to walk with you this week, in person or by sharing this Advent walk."),
    SeasonDay("He Rejoices over You", "Zephaniah 3:17",
        "The LORD thy God in the midst of thee is mighty; he will save, he will rejoice over thee with joy; he will rest in his love, he will joy over thee with singing.",
        "We talk a lot about our joy in God. This verse turns it around: God rejoices over you, with singing. You are not a burden to Him. You are a delight.",
        "Father, help me believe that You delight in me. Amen.",
        "As you walk today, picture God singing over you, and let that set your pace."),
    SeasonDay("Rejoice Always", "Philippians 4:4",
        "Rejoice in the Lord alway: and again I say, Rejoice.",
        "Paul wrote this from prison. Rejoicing in the Lord isn't pretending everything is fine; it's remembering who is with you when it isn't. That kind of joy can walk through anything.",
        "Lord, give me joy that doesn't depend on my circumstances. Amen.",
        "Name something you're thankful for every few minutes of today's walk."),
    SeasonDay("The Path of Life", "Psalm 16:11",
        "Thou wilt shew me the path of life: in thy presence is fulness of joy; at thy right hand there are pleasures for evermore.",
        "God doesn't only give a destination; He shows us the path. Fulness of joy is found in His presence, which means it can be found on the way, not only at the end.",
        "Show me the path of life, Lord, and let me enjoy Your presence on it. Amen.",
        "Take a route today you don't usually take, and pay attention to God along it."),
    SeasonDay("Joseph, Fear Not", "Matthew 1:20",
        "But while he thought on these things, behold, the angel of the Lord appeared unto him in a dream, saying, Joseph, thou son of David, fear not to take unto thee Mary thy wife: for that which is conceived in her is of the Holy Ghost.",
        "Joseph had a quiet plan to step away. God interrupted it with a dream and two words: fear not. Joseph's obedience was quiet too; he simply got up and did what God said.",
        "Lord, when I'm afraid of where You're leading, give me Joseph's quiet courage. Amen.",
        "Pray for the fathers and father figures in your life as you walk today."),
    SeasonDay("His Name Is Jesus", "Matthew 1:21",
        "And she shall bring forth a son, and thou shalt call his name JESUS: for he shall save his people from their sins.",
        "Jesus means the Lord saves. Before He was born, His name told everyone why He came. He didn't come to make good people a little better; He came to save.",
        "Jesus, thank You for saving me. Let Your name be on my lips today. Amen.",
        "Pray the name of Jesus slowly as you walk, for yourself and for someone who needs Him."),
    SeasonDay("So Loved", "John 3:16",
        "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
        "Christmas is how much God loves the world, in the shape of a baby. He didn't send only a message or a messenger. He gave His Son.",
        "Father, thank You for loving me enough to give Your Son. Help me love like that. Amen.",
        "Pray for your neighbours, house by house or street by street, as you walk today."),
    SeasonDay("A Decree Went Out", "Luke 2:1",
        "And it came to pass in those days, that there went out a decree from Caesar Augustus, that all the world should be taxed.",
        "An emperor ordered a census and thought he was in charge. God used it to bring Mary and Joseph to Bethlehem, right where the prophet said He would be born. God works through events that seem out of anyone's control.",
        "Lord, You rule over the things I can't control. I rest in that. Amen.",
        "As you walk, hand God one thing that feels out of your control."),
    SeasonDay("Great with Child", "Luke 2:5",
        "To be taxed with Mary his espoused wife, being great with child.",
        "Picture the road: days of walking, with Mary close to giving birth. It was hard, slow and uncomfortable. Many of God's best gifts arrive at the end of a hard road.",
        "Lord, strengthen everyone walking a hard road this Christmas, and make me kind to them. Amen.",
        "Pray for expectant mothers, and for everyone traveling to be home for Christmas."),
    SeasonDay("Your Going Out and Coming In", "Psalm 121:8",
        "The LORD shall preserve thy going out and thy coming in from this time forth, and even for evermore.",
        "The last miles of a journey are often the hardest. God kept Mary and Joseph on every one of them, and He keeps your going out and your coming in too, this Christmas and always.",
        "Lord, keep me and those I love on every road this season. Amen.",
        "Pray for everyone traveling this week as you walk your last miles to Bethlehem."),
    SeasonDay("Born This Day", "Luke 2:11",
        "For unto you is born this day in the city of David a Saviour, which is Christ the Lord.",
        "You made it to Bethlehem. After every mile, the news is simple: unto you is born a Saviour. There was no room at the inn, but there is room for Him in you.",
        "Jesus, welcome. Be born in me this Christmas. Amen.",
        "Take a slow walk tonight and look up. Thank God for the gift of His Son.")
]
