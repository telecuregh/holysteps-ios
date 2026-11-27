import SwiftUI
import CryptoKit

/// Android's kids profiles (Kids.kt, KidsScreens.kt): a child's own space with only age-appropriate content (bedtime
/// stories read aloud, short prayers, a verse for the week, gentle Bible-story summaries). No social features, chat or
/// AI. Leaving kids mode needs the parent's 4-digit PIN, kept as a salted hash. Everything stays on this phone.
enum Kids {
    struct Profile: Codable, Identifiable, Equatable { let id: String; var name: String; var age: Int; var emoji: String }
    struct Prayer { let title, text: String; let young: Bool }
    struct Verse { let ref, text: String }
    struct Story: Identifiable { let title, emoji, ref, summary: String; var id: String { title } }
    static let emojis = ["🦁", "🐑", "🕊️", "🐻", "🦊", "🐢", "🦉", "🐳", "🌟", "🌈"]
    static let prayers: [Prayer] = [
        .init(title: "Good morning", text: "Thank you, God, for this new day. Help me be kind and brave. Amen.", young: true),
        .init(title: "Before we eat", text: "Thank you, God, for this food and for the hands that made it. Amen.", young: true),
        .init(title: "Bedtime", text: "Now I lay me down to sleep. Thank you, God, for loving me. Keep my family safe tonight. Amen.", young: true),
        .init(title: "When I'm scared", text: "God, you are with me. You are bigger than anything I'm scared of. Help me feel safe. Amen.", young: true),
        .init(title: "Thank you", text: "Thank you, God, for my family, my friends, and the world you made. Amen.", young: true),
        .init(title: "For a friend", text: "Dear God, please help my friend today. Show them how much you love them. Amen.", young: false),
        .init(title: "When I made a mistake", text: "God, I'm sorry for what I did. Help me make it right, and help me do better. Thank you for forgiving me. Amen.", young: false),
        .init(title: "Before school", text: "Jesus, be with me at school today. Help me learn, listen, and be a good friend to someone who needs one. Amen.", young: false),
        .init(title: "The Lord's Prayer", text: "Our Father in heaven, holy is your name. Your kingdom come, your will be done, on earth as in heaven. Give us today our daily bread. Forgive us our sins as we forgive those who sin against us. Lead us not into temptation, but deliver us from evil. Amen.", young: false)
    ]
    static let verses: [Verse] = [
        .init(ref: "1 John 4:8", text: "God is love."),
        .init(ref: "Psalm 56:3", text: "When I am afraid, I will trust in you."),
        .init(ref: "Ephesians 4:32", text: "Be kind to one another."),
        .init(ref: "Psalm 118:24", text: "This is the day which the Lord has made; we will be glad and have joy in it."),
        .init(ref: "Philippians 4:13", text: "I am able to do all things through him who gives me strength."),
        .init(ref: "Psalm 23:1", text: "The Lord takes care of me as his sheep; I will not be without any good thing."),
        .init(ref: "Joshua 1:9", text: "Be strong and of a good heart; have no fear, for the Lord your God is with you."),
        .init(ref: "John 3:16", text: "For God so loved the world that he gave his only Son."),
        .init(ref: "Matthew 19:14", text: "Let the little children come to me."),
        .init(ref: "Psalm 136:1", text: "Give thanks to the Lord, for he is good."),
        .init(ref: "1 Peter 5:7", text: "Put all your cares on him, for he takes care of you."),
        .init(ref: "Proverbs 3:5", text: "Trust in the Lord with all your heart."),
        .init(ref: "Luke 6:31", text: "Do to others as you would have them do to you."),
        .init(ref: "Psalm 4:8", text: "I will lie down in peace and sleep, for you, Lord, keep me safe.")
    ]
    static let stories: [Story] = [
        .init(title: "God makes the world", emoji: "🌍", ref: "Genesis 1", summary: "God made the light, the sky, the seas, the plants, the animals, and people too. He looked at everything and said it was very good."),
        .init(title: "Noah's big boat", emoji: "🚢", ref: "Genesis 6–9", summary: "God asked Noah to build a giant boat. Noah, his family and the animals stayed safe inside, and God put a rainbow in the sky as a promise."),
        .init(title: "Baby Moses in a basket", emoji: "🧺", ref: "Exodus 2", summary: "Moses' mother hid him in a little basket by the river. A princess found him and loved him, and God kept him safe."),
        .init(title: "David and the giant", emoji: "🪨", ref: "1 Samuel 17", summary: "David was just a boy, but he trusted God. With one small stone he beat the giant Goliath, because God was with him."),
        .init(title: "Daniel and the lions", emoji: "🦁", ref: "Daniel 6", summary: "Daniel kept praying to God even when it was against the rules. God shut the lions' mouths and kept Daniel safe all night."),
        .init(title: "Jonah and the big fish", emoji: "🐋", ref: "Jonah 1–3", summary: "Jonah ran away from what God asked. A big fish swallowed him, and after three days Jonah said sorry and did what God wanted."),
        .init(title: "Jesus is born", emoji: "⭐", ref: "Luke 2", summary: "Jesus was born in a stable in Bethlehem. Angels sang, shepherds came to visit, and a bright star shone in the sky."),
        .init(title: "Jesus calms the storm", emoji: "🌊", ref: "Mark 4", summary: "A big storm rocked the boat. Jesus stood up and said, \\\"Peace, be still,\\\" and the wind and waves became calm."),
        .init(title: "Five loaves and two fish", emoji: "🐟", ref: "John 6", summary: "A boy shared his small lunch. Jesus blessed it and fed more than five thousand people, with food left over."),
        .init(title: "The lost sheep", emoji: "🐑", ref: "Luke 15", summary: "A shepherd had one hundred sheep and one got lost. He looked everywhere until he found it, because every one matters to him, just like you matter to God."),
        .init(title: "Jesus loves the children", emoji: "🧒", ref: "Mark 10", summary: "The disciples tried to send the children away, but Jesus said, \\\"Let them come to me,\\\" and he hugged and blessed them."),
        .init(title: "The good Samaritan", emoji: "🤝", ref: "Luke 10", summary: "A man was hurt by the road. Others walked past, but a stranger stopped, helped him, and took care of him. Jesus said, be like him."),
        .init(title: "Zacchaeus in the tree", emoji: "🌳", ref: "Luke 19", summary: "Zacchaeus was too short to see Jesus, so he climbed a tree. Jesus called him by name and went to his house, and Zacchaeus changed his heart."),
        .init(title: "Jesus is alive!", emoji: "🌅", ref: "Matthew 28", summary: "Jesus died on the cross, but on the third day the tomb was empty. Jesus is alive, and he is with us always.")
    ]
    static func verseOfWeek(_ epochDay: Int = PhasePlan.epochDay) -> Verse { verses[((epochDay / 7) % verses.count + verses.count) % verses.count] }
    /// Ages 2–5 get the short prayers only.
    static func prayersFor(_ age: Int) -> [Prayer] { prayers.filter { age >= 6 || $0.young } }
    static func hashPin(_ pin: String, salt: String) -> String { SHA256.hash(data: Data("\(salt):\(pin)".utf8)).map { String(format: "%02x", $0) }.joined() }
    static func validPin(_ pin: String) -> Bool { pin.count == 4 && pin.allSatisfy(\.isASCII) && pin.allSatisfy(\.isNumber) }
}

@MainActor
final class KidsStore: ObservableObject {
    static let shared = KidsStore()
    @Published private(set) var kids: [Kids.Profile] = []
    @Published var active: Kids.Profile?
    private init() {
        kids = (UserDefaults.standard.data(forKey: "kidsProfiles").flatMap { try? JSONDecoder().decode([Kids.Profile].self, from: $0) }) ?? []
    }
    private func save() { UserDefaults.standard.set(try? JSONEncoder().encode(Array(kids.prefix(8))), forKey: "kidsProfiles") }
    var hasPin: Bool { UserDefaults.standard.string(forKey: "kidsPinHash") != nil }
    func setPin(_ pin: String) {
        let salt = UUID().uuidString
        UserDefaults.standard.set(salt, forKey: "kidsPinSalt"); UserDefaults.standard.set(Kids.hashPin(pin, salt: salt), forKey: "kidsPinHash")
    }
    func check(_ pin: String) -> Bool {
        guard let h = UserDefaults.standard.string(forKey: "kidsPinHash"), let s = UserDefaults.standard.string(forKey: "kidsPinSalt") else { return true }
        return Kids.hashPin(pin, salt: s) == h
    }
    func add(name: String, age: Int) {
        let n = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        guard !n.isEmpty, kids.count < 8 else { return }
        kids.append(.init(id: UUID().uuidString, name: n, age: min(12, max(2, age)), emoji: Kids.emojis[kids.count % Kids.emojis.count])); save()
    }
    func remove(_ k: Kids.Profile) { kids.removeAll { $0.id == k.id }; save() }
}

struct KidsProfilesView: View {
    @ObservedObject private var s = KidsStore.shared
    @State private var adding = false
    @State private var name = ""
    @State private var age = 6
    @State private var pinFor: Kids.Profile?
    @State private var pin = ""
    @State private var removing: Kids.Profile?

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    T("🧸 Kids profiles").font(.hs(24)).foregroundStyle(HS.text)
                    T("A child's own space with bedtime stories, short prayers, a verse for the week and Bible stories. No chat, no social features, no AI. Leaving it needs your 4-digit PIN.")
                        .font(.hs(13)).foregroundStyle(HS.textSecondary)
                    ForEach(s.kids) { k in
                        GlassCard {
                            HStack {
                                D(k.emoji).font(.system(size: 30))
                                VStack(alignment: .leading) {
                                    D(k.name).font(.hs(16, .bold)).foregroundStyle(HS.text)
                                    D(tr("Age \(k.age) · tap to open their space")).font(.hs(12)).foregroundStyle(HS.textMuted)
                                }
                                Spacer()
                                Button { removing = k } label: { Image(systemName: "xmark").foregroundStyle(HS.textMuted) }.buttonStyle(.plain)
                            }.contentShape(Rectangle())
                            .onTapGesture { if s.hasPin { s.active = k } else { pinFor = k } }
                        }
                    }
                    if s.kids.count < 8 { GoldButton(title: "+ Add a child") { adding = true } }
                }.padding(20)
            }
        }
        .sheet(isPresented: $adding) {
            NavigationStack {
                Form {
                    TextField(tr("First name or nickname"), text: $name)
                    Stepper(tr("Age: \(age)"), value: $age, in: 2...12)
                }
                .navigationTitle(tr("Add a child"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button(tr("Add")) { s.add(name: name, age: age); name = ""; adding = false }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
                    ToolbarItem(placement: .cancellationAction) { Button(tr("Cancel")) { adding = false } }
                }
            }.presentationDetents([.medium])
        }
        .alert(tr("Set a parent PIN"), isPresented: Binding(get: { pinFor != nil }, set: { if !$0 { pinFor = nil } })) {
            SecureField(tr("4 digits"), text: $pin).keyboardType(.numberPad)
            Button(tr("OK")) { if Kids.validPin(pin) { s.setPin(pin); s.active = pinFor }; pin = ""; pinFor = nil }
            Button(tr("Cancel"), role: .cancel) { pin = ""; pinFor = nil }
        } message: { T("You'll need it to leave kids mode.") }
        .alert(Text(tr("Remove \(removing?.name ?? "")'s profile?")), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button(tr("Remove"), role: .destructive) { if let k = removing { s.remove(k) }; removing = nil }
            Button(tr("Cancel"), role: .cancel) { removing = nil }
        }
        .fullScreenCover(item: $s.active) { k in KidsModeView(kid: k) }
    }
}

struct KidsModeView: View {
    let kid: Kids.Profile
    @ObservedObject private var s = KidsStore.shared
    @State private var askPin = false
    @State private var pin = ""
    @State private var wrong = false
    @State private var story: Kids.Story?
    @State private var play: Sermon?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1E3A8A), Color(hex: 0x312E81)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        D(kid.emoji).font(.system(size: 40))
                        D(tr("Hi, \(kid.name)!")).font(.hs(26, .bold)).foregroundStyle(.white)
                        Spacer()
                        Button(tr("Grown-ups 🔒")) { askPin = true }.font(.hs(12)).foregroundStyle(.white.opacity(0.7))
                    }
                    let v = Kids.verseOfWeek()
                    tile {
                        T("⭐ VERSE OF THE WEEK").font(.hs(11, .bold)).foregroundStyle(Color(hex: 0xFDE68A))
                        T(v.text).font(.hs(18, .semibold)).foregroundStyle(.white)
                        D(v.ref).font(.hs(12)).foregroundStyle(.white.opacity(0.7))
                    }
                    header("🌙 Bedtime stories")
                    ForEach(SleepLibrary.list("kids").filter { !SleepLibrary.locked($0) }) { j in
                        Button { play = j } label: { row(j.title, j.minutesLabel, "🧸") }.buttonStyle(.plain)
                    }
                    header("📖 Bible stories")
                    ForEach(Kids.stories) { st in Button { story = st } label: { row(st.title, st.ref, st.emoji) }.buttonStyle(.plain) }
                    header("🙏 Prayers")
                    ForEach(Kids.prayersFor(kid.age), id: \.title) { p in
                        tile { T(p.title).font(.hs(15, .bold)).foregroundStyle(.white); T(p.text).font(.hs(14)).foregroundStyle(.white.opacity(0.9)) }
                    }
                }.padding(20)
            }
        }
        .interactiveDismissDisabled()
        .fullScreenCover(item: $play) { j in SermonPlayerView(sermon: j) }
        .alert(Text(story.map { "\($0.emoji) \(tr($0.title))" } ?? ""), isPresented: Binding(get: { story != nil }, set: { if !$0 { story = nil } })) {
            Button(tr("The end! 🌟")) { story = nil }
        } message: { Text(tr(story?.summary ?? "")) }
        .alert(tr(wrong ? "That PIN isn't right." : "Parent PIN"), isPresented: $askPin) {
            SecureField(tr("4 digits"), text: $pin).keyboardType(.numberPad)
            Button(tr("OK")) { let ok = s.check(pin); pin = ""; if ok { wrong = false; s.active = nil } else { wrong = true; DispatchQueue.main.async { askPin = true } } }
            Button(tr("Cancel"), role: .cancel) { pin = ""; wrong = false }
        }
    }

    private func header(_ t: String) -> some View { T(t).font(.hs(17, .bold)).foregroundStyle(.white).padding(.top, 6) }
    private func tile<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6, content: c).padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
    }
    private func row(_ title: String, _ sub: String, _ emoji: String) -> some View {
        HStack { D(emoji).font(.system(size: 24)); VStack(alignment: .leading) { T(title).font(.hs(15, .semibold)).foregroundStyle(.white); D(sub).font(.hs(12)).foregroundStyle(.white.opacity(0.7)) }; Spacer() }
            .padding(12).background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
    }
}
