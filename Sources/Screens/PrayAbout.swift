import SwiftUI

/// Android's "Pray about…" (PrayerGuide.kt, PrayerGuideScreen.kt): a guide for praying about a specific need, for
/// yourself or for someone by name. Each topic has KJV verses to pray, short prompts, and a written prayer in two
/// forms. The data is Android's own, converted to Resources/prayer_guide.json so every verse matches exactly.
struct PrayerTopic: Decodable, Identifiable {
    struct Verse: Decodable {
        let book: String, ch: Int, from: Int, to: Int, text: String
        var ref: String { "\(book == "Psalms" ? "Psalm" : book) \(ch):\(from)\(to > from ? "–\(to)" : "")" }
    }
    let id: String, emoji: String, title: String, keywords: String
    let verses: [Verse], prompts: [String]
    let forMe: String, forOther: String

    /// The prayer, worded for `name` when one is given, otherwise for the person praying.
    func prayer(_ name: String?) -> String {
        if let n = name?.trimmingCharacters(in: .whitespaces), !n.isEmpty { return tr(forOther).replacingOccurrences(of: "{name}", with: n) }
        return tr(forMe)
    }
}

enum PrayerGuide {
    static let maxName = 40
    /// What Grace says in place of a typed name: names can't be recorded in advance.
    static let standIn = "the one I'm praying for"

    static let topics: [PrayerTopic] = {
        guard let u = Bundle.main.url(forResource: "prayer_guide", withExtension: "json"),
              let d = try? Data(contentsOf: u), let t = try? JSONDecoder().decode([PrayerTopic].self, from: d) else { return [] }
        return t
    }()

    /// Topics whose title, the words people use for it, or verses match `query`; all of them for a blank query.
    static func search(_ query: String) -> [PrayerTopic] {
        let words = query.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 2 }
        guard !words.isEmpty else { return topics }
        return topics.map { t -> (PrayerTopic, Int) in
            let hay = (t.title + " " + t.keywords + " " + t.verses.map(\.ref).joined(separator: " ")).lowercased()
            return (t, words.filter { hay.contains($0) }.count)
        }
        .filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.map(\.0)
    }

    static func cleanName(_ raw: String) -> String {
        String(raw.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(maxName))
    }

    /// A short message to send someone you prayed for: their name, that you prayed, and one verse.
    static func message(_ t: PrayerTopic, _ name: String) -> String {
        let v = t.verses[0]
        return "\(name.isEmpty ? "Hi" : name), \(tr("I prayed for you today.")) \u{201C}\(v.text)\u{201D} (\(v.ref), KJV)"
    }

    /// The lines Grace reads, in order: each verse with its reference, then the prayer (Android's spokenLines).
    static func spokenLines(_ t: PrayerTopic, forSomeone: Bool) -> [String] {
        t.verses.map { "\($0.text) \($0.ref.replacingOccurrences(of: "–", with: " to "))." } +
            [(forSomeone ? t.forOther : t.forMe).replacingOccurrences(of: "{name}", with: standIn)]
    }
}

struct PrayAboutView: View {
    @State private var query = ""

    var body: some View {
        let topics = PrayerGuide.search(query)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PrayHeader(label: "🙏 PRAY ABOUT…", title: "What would you like to pray about?",
                           sub: "Pick a need, for yourself or for someone you love. Each one has verses to pray and words to begin with.")
                TextField(tr("Search: sick, job, grief, exams…"), text: $query)
                    .font(.hs(15)).padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
                    .onChange(of: query) { if query.count > 60 { query = String(query.prefix(60)) } }
                if topics.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            D(tr("No topic matches") + " \u{201C}\(query)\u{201D}.").font(.hs(14)).foregroundStyle(HS.text)
                            T("You can always pray in your own words, or add it to your Prayer List.").font(.hs(13)).foregroundStyle(HS.textMuted)
                            NavigationLink { PrayerJournalView(section: 0) } label: { T("Open my Prayer List →").font(.hs(13)).foregroundStyle(HS.faith) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(topics) { t in
                        NavigationLink { PrayAboutTopicView(topic: t) } label: {
                            HStack(spacing: 10) {
                                D(t.emoji).font(.system(size: 22))
                                T(t.title).font(.hs(14, .semibold)).foregroundStyle(HS.text).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(12).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(HS.gold.opacity(0.22)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr("Pray about…"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrayHeader: View {
    let label: String, title: String, sub: String
    var body: some View {
        GlassCard(warm: true) {
            VStack(alignment: .leading, spacing: 4) {
                D(label).font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                D(tr(title)).font(.hs(24, .light)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                ItalicAccent(text: "bring every burden to God", size: 18)
                if !sub.isEmpty { D(tr(sub)).font(.hs(13)).foregroundStyle(HS.textSecondary).padding(.top, 2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct PrayAboutTopicView: View {
    let topic: PrayerTopic
    @EnvironmentObject var store: AppStore
    @State private var forSomeone = false
    @State private var name = ""
    @State private var prayed = false
    @State private var added = false
    @State private var reading = false
    @State private var noVoice = false
    @State private var readTask: Task<Void, Never>?

    private var who: String? { let n = PrayerGuide.cleanName(name); return forSomeone && !n.isEmpty ? n : nil }

    var body: some View {
        let prayer = topic.prayer(who)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PrayHeader(label: "\(topic.emoji) PRAY ABOUT…", title: topic.title, sub: who.map { tr("Praying for") + " \($0)" } ?? "")

                HStack(spacing: 4) {
                    ForEach([false, true], id: \.self) { v in
                        Button { forSomeone = v; prayed = false; added = false } label: {
                            T(v ? "For someone" : "For me").font(.hs(14, forSomeone == v ? .bold : .regular))
                                .foregroundStyle(forSomeone == v ? HS.onGold : HS.textMuted)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(forSomeone == v ? AnyShapeStyle(HS.goldButton) : AnyShapeStyle(Color.clear)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(forSomeone == v ? .isSelected : [])
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))

                if forSomeone {
                    TextField(tr("Their name"), text: $name)
                        .textInputAutocapitalization(.words).font(.hs(15)).padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
                        .onChange(of: name) { if name.count > PrayerGuide.maxName { name = String(name.prefix(PrayerGuide.maxName)) }; prayed = false; added = false }
                    let known = Array(Set(store.prayers.filter { !$0.answered }.map { $0.forWhom.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty && $0.count <= PrayerGuide.maxName })).sorted().prefix(8)
                    if !known.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(known), id: \.self) { k in
                                    Button { name = k } label: {
                                        D(k).font(.hs(13)).foregroundStyle(HS.text).padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(Capsule().strokeBorder(HS.gold.opacity(0.35)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if topic.id == "depression" { CrisisCard() }
                if topic.id == "addiction" {
                    NavigationLink { FreedomView() } label: {
                        HStack(spacing: 10) {
                            D("🕊️").font(.system(size: 20))
                            T("Freedom walks with you day by day, free. Open Freedom →").font(.hs(13)).foregroundStyle(HS.text).multilineTextAlignment(.leading)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
                    }
                    .buttonStyle(.plain)
                }

                T("Pray these verses").font(.hs(15, .bold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader).padding(.top, 4)
                ForEach(topic.verses, id: \.ref) { v in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 4) {
                            D("\u{201C}\(v.text)\u{201D}").font(.hs(15)).foregroundStyle(HS.text)
                            D("\(v.ref) · KJV").font(.hs(12, .semibold)).foregroundStyle(HS.peach)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                T("As you pray").font(.hs(15, .bold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader).padding(.top, 4)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(topic.prompts, id: \.self) { p in
                        HStack(alignment: .top, spacing: 6) {
                            D("•").foregroundStyle(HS.peach)
                            T(p).font(.hs(14)).foregroundStyle(HS.textSecondary)
                        }
                    }
                }

                T("A prayer to begin with").font(.hs(15, .bold)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader).padding(.top, 4)
                GlassCard(warm: true) {
                    VStack(alignment: .leading, spacing: 6) {
                        D(prayer).font(.hs(15)).foregroundStyle(HS.text).textSelection(.enabled)
                        if forSomeone && who == nil {
                            T("Type their name above and the prayer is worded for them.").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button { reading ? stopReading() : readAloud() } label: {
                    T(reading ? "⏹ Stop reading" : "🔊 Read it to me").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.gold.opacity(0.35)))
                }
                .buttonStyle(.plain)
                if noVoice {
                    T("Grace's reading of this prayer isn't on this phone yet. Connect to the internet and try again.").font(.hs(12)).foregroundStyle(HS.textMuted)
                }
                HStack(spacing: 8) {
                    Button { UIPasteboard.general.string = prayer } label: {
                        T("📋 Copy prayer").font(.hs(14)).foregroundStyle(HS.text).frame(maxWidth: .infinity, minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.gold.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    ShareLink(item: prayer) {
                        T("↗ Share prayer").font(.hs(14)).foregroundStyle(HS.text).frame(maxWidth: .infinity, minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.gold.opacity(0.35)))
                    }
                }

                if !prayed {
                    Button { stopReading(); prayed = true; prayedFromGuide() } label: {
                        T("🙏 Amen, I prayed").font(.hs(15, .bold)).foregroundStyle(HS.onGold).frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 16).fill(HS.goldButton))
                    }
                    .buttonStyle(.plain).padding(.top, 6)
                } else {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            T("Amen.").font(.hs(16, .bold)).foregroundStyle(HS.text)
                            D(who.map { tr("Keep praying for") + " \($0). " + tr("You can come back to this anytime.") } ?? tr("You can come back to this anytime."))
                                .font(.hs(13)).foregroundStyle(HS.textMuted)
                            if !added {
                                Button {
                                    store.prayers.insert(PrayerItem(text: topic.title, forWhom: who ?? ""), at: 0); added = true
                                } label: {
                                    T("📝 Add to my Prayer List").font(.hs(14)).foregroundStyle(HS.text).frame(maxWidth: .infinity, minHeight: 44)
                                        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(HS.gold.opacity(0.35)))
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink { PrayerJournalView(section: 0) } label: { T("✓ On your Prayer List").font(.hs(13, .semibold)).foregroundStyle(HS.body) }
                            }
                            if let w = who {
                                ShareLink(item: PrayerGuide.message(topic, w)) {
                                    D("💬 " + tr("Tell") + " \(w) " + tr("you prayed")).font(.hs(14)).foregroundStyle(HS.text).frame(maxWidth: .infinity, minHeight: 44)
                                        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(HS.gold.opacity(0.35)))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr(topic.title))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear(perform: stopReading)
        .onChange(of: forSomeone) { stopReading() }
    }

    /// Grace reads the verses and the prayer from her "prayer_guide" pack; a line she hasn't recorded stays silent.
    private func readAloud() {
        let lines = PrayerGuide.spokenLines(topic, forSomeone: forSomeone)
        reading = true; noVoice = false
        readTask = Task { @MainActor in
            var any = false
            for l in lines {
                if Task.isCancelled { break }
                if await GraceVoice.say(l, pack: "prayer_guide") { any = true }
            }
            if !Task.isCancelled && !any { noVoice = true }
            reading = false
        }
    }

    private func stopReading() { readTask?.cancel(); readTask = nil; GraceVoice.stop(); reading = false }

    /// Android's prayedFromGuide: counts as the next prayer of the day.
    private func prayedFromGuide() {
        if let next = store.prayerDoneToday.firstIndex(of: false) { store.togglePrayer(next) }
        Learning.shared.recordOpen("Pray about…")
    }
}
