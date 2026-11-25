import SwiftUI

/// Android's prayer garden (data/PrayerGarden.kt, ui/screens/PrayerGardenScreen.kt): every prayer on the list is a
/// plant. It grows with the days it is prayed for and blooms only when the prayer is marked answered. Nothing wilts.
enum PrayerGarden {
    static let bedSize = 20, fullBed = 6, stemDays = 3, budDays = 7

    enum Stage: Int { case sprout, stem, bud, bloom
        var label: String { ["Sprout", "Growing", "Bud", "In bloom"][rawValue] }
    }
    static func stage(_ r: PrayerItem) -> Stage {
        if r.answered { return .bloom }
        if r.daysPrayed >= budDays { return .bud }
        if r.daysPrayed >= stemDays { return .stem }
        return .sprout
    }
    static func daysToNext(_ r: PrayerItem) -> Int? {
        switch stage(r) {
        case .sprout: max(1, stemDays - r.daysPrayed)
        case .stem: max(1, budDays - r.daysPrayed)
        default: nil
        }
    }
    static func forOthers(_ r: PrayerItem) -> Bool {
        let w = r.forWhom.trimmingCharacters(in: .whitespaces).lowercased()
        return !w.isEmpty && !["me", "myself", "self", "i", "yo", "mí", "mi"].contains(w)
    }
    static func plants(_ all: [PrayerItem], bed: Int) -> [PrayerItem] { all.filter { $0.bed == bed }.sorted { $0.created < $1.created } }
    static func pastBeds(_ all: [PrayerItem], current: Int) -> [(Int, [PrayerItem])] {
        Dictionary(grouping: all.filter { $0.bed < current }, by: \.bed).sorted { $0.key > $1.key }.map { ($0.key, $0.value.sorted { $0.created < $1.created }) }
    }

    /// The picture of the one garden that fits these plants (the bed's average growth).
    static func scene(_ plants: [PrayerItem]) -> String {
        if plants.isEmpty { return "garden_empty" }
        if plants.allSatisfy({ !$0.answered && $0.daysPrayed <= 1 }) { return "garden_seeds" }
        let avg = Double(plants.map { stage($0).rawValue }.reduce(0, +)) / Double(max(plants.count, fullBed))
        switch avg {
        case ..<0.5: return "garden_sprouts"
        case ..<1.0: return "garden_seedlings"
        case ..<1.75: return "garden_stems"
        case ..<2.5: return "garden_buds"
        default: return "garden_bloom"
        }
    }

    /// Where plant `index` sits on the picture: x and y as fractions, and a size scale (rows further back are smaller).
    static func spot(_ index: Int) -> (CGFloat, CGFloat, CGFloat) {
        let i = index % bedSize, row = i / 5, col = i % 5
        let depth = CGFloat(row) / 3
        let y = 0.92 - depth * 0.26
        let left = 0.07 + depth * 0.07, right = 0.93 - depth * 0.07
        let stagger: CGFloat = row % 2 == 1 ? 0.1 : 0
        let jitter = CGFloat(((i * 37) % 11) - 5) / 400
        let x = left + (right - left) * min(0.95, max(0.05, (CGFloat(col) + 0.5) / 5 + stagger - 0.05)) + jitter
        return (x, y, 1 - depth * 0.35)
    }

    struct Tally { let plants, answered, praying, daysOfPrayer: Int }
    static func tally(_ p: [PrayerItem]) -> Tally {
        Tally(plants: p.count, answered: p.filter(\.answered).count, praying: p.filter { !$0.answered }.count, daysOfPrayer: p.map(\.daysPrayed).reduce(0, +))
    }

    static func color(_ r: PrayerItem) -> Color {
        stage(r) == .bloom ? Color(hex: 0xF4C46A) : forOthers(r) ? Color(hex: 0xED93B1) : Color(hex: 0xAFA9EC)
    }
}

struct PrayerGardenView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("gardenBed") private var bed = 0
    @State private var selectedId: UUID?
    @State private var showAdd = false
    @State private var answering: PrayerItem?
    @State private var confirmNewBed = false
    @State private var note: String?
    @State private var pulse = false

    var body: some View {
        let plants = PrayerGarden.plants(store.prayers, bed: bed)
        let t = PrayerGarden.tally(plants)
        let scene = PrayerGarden.scene(plants)
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        T("Your prayer garden").font(.hs(26, .semibold)).foregroundStyle(HS.text)
                        T("Every prayer is planted here. It grows as you keep praying and blooms when God answers.").font(.accent(14)).foregroundStyle(HS.italic)
                        D(tr("Bed \(bed + 1)") + " · " + tr(t.plants == 1 ? "1 prayer" : "\(t.plants) prayers") + " · " + tr("\(t.answered) answered"))
                            .font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    .padding(.horizontal, 20)

                    garden(plants, scene)

                    if let note { D(tr(note)).font(.hs(13, .semibold)).foregroundStyle(HS.gold).padding(.horizontal, 20) }
                    if let p = plants.first(where: { $0.id == selectedId }) { detail(p) }

                    HStack(spacing: 8) {
                        gardenButton("Plant a prayer", primary: !plants.isEmpty) { showAdd = true }
                        if !plants.isEmpty, let img = shareImage(scene, t) {
                            ShareLink(item: img, preview: SharePreview(tr("My prayer garden"), image: img)) {
                                T("Share my garden").font(.hs(13, .semibold)).foregroundStyle(HS.text).frame(maxWidth: .infinity).padding(.vertical, 11)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
                                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.gold.opacity(0.35), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    if !plants.isEmpty {
                        SectionHeader(title: "In this bed")
                        GlassCard {
                            VStack(spacing: 10) {
                                ForEach(plants) { p in
                                    Button { selectedId = p.id } label: {
                                        HStack(spacing: 10) {
                                            Circle().fill(PrayerGarden.color(p)).frame(width: 10, height: 10)
                                            D(p.text).font(.hs(14)).foregroundStyle(HS.text).lineLimit(1)
                                            Spacer()
                                            T(PrayerGarden.stage(p).label).font(.hs(12)).foregroundStyle(HS.textMuted)
                                        }
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        if t.answered > 0 || t.plants >= PrayerGarden.bedSize {
                            Button { confirmNewBed = true } label: {
                                T(t.plants >= PrayerGarden.bedSize ? "This bed is full. Start a new bed →" : "Start a new bed →")
                                    .font(.hs(13, .semibold)).foregroundStyle(HS.italic)
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    let past = PrayerGarden.pastBeds(store.prayers, current: bed)
                    if !past.isEmpty {
                        SectionHeader(title: "Keepsake beds")
                        ForEach(past, id: \.0) { b, list in
                            let pt = PrayerGarden.tally(list)
                            GlassCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    D(tr("Bed \(b + 1)") + " · " + tr("\(pt.plants) prayers") + " · " + tr("\(pt.answered) answered")).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                    ForEach(list.filter(\.answered).prefix(5)) { p in
                                        D("🌸 " + p.text + (p.testimony.isEmpty ? "" : ": " + p.testimony)).font(.hs(12)).foregroundStyle(HS.textMuted).lineLimit(2)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    Spacer().frame(height: 100)
                }
                .padding(.top, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            AddPrayerSheet { text, who in
                store.prayers.insert(PrayerItem(text: text, forWhom: who, bed: bed), at: 0)
                note = "A new sprout is in your garden."
            }
        }
        .sheet(item: $answering) { p in
            AnsweredSheet(prayer: p.text) { testimony in
                if let i = store.prayers.firstIndex(where: { $0.id == p.id }) {
                    store.prayers[i].answered = true
                    store.prayers[i].testimony = testimony
                }
                selectedId = p.id
                note = "It bloomed. Praise God!"
            }
        }
        .alert(tr("Start a new bed?"), isPresented: $confirmNewBed) {
            Button(tr("Start new bed")) { newBed() }
            Button(tr("Not yet"), role: .cancel) {}
        } message: {
            T("This bed is kept as a keepsake with every answered prayer in it. Prayers you're still praying for move to the new bed and keep their growth.")
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true } }
    }

    private func garden(_ plants: [PrayerItem], _ scene: String) -> some View {
        Color.clear
            .aspectRatio(720.0 / 894.0, contentMode: .fit)
            .overlay(Image(scene).resizable().scaledToFill().accessibilityLabel(tr("Your prayer garden")))
            .overlay(GeometryReader { g in
                ForEach(Array(plants.prefix(PrayerGarden.bedSize).enumerated()), id: \.element.id) { i, p in
                    let (fx, fy, sc) = PrayerGarden.spot(i)
                    marker(p, size: 30 * sc)
                        .position(x: g.size.width * fx, y: g.size.height * fy)
                }
            })
            .overlay(alignment: .bottom) {
                if plants.isEmpty {
                    VStack(spacing: 6) {
                        T("Fresh soil, ready for your first prayer").font(.hs(15, .semibold)).foregroundStyle(.white).multilineTextAlignment(.center)
                        T("Pray for someone or something on your heart and a sprout will appear.").font(.hs(12)).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                        gardenButton("Plant a prayer", primary: true) { showAdd = true }.padding(.top, 4)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x140C18).opacity(0.7)))
                    .padding(18)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 16)
    }

    private func marker(_ p: PrayerItem, size: CGFloat) -> some View {
        let st = PrayerGarden.stage(p), c = PrayerGarden.color(p), sel = p.id == selectedId
        return Button { selectedId = sel ? nil : p.id } label: {
            ZStack {
                Circle().fill(RadialGradient(colors: [c.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: size / 2))
                Circle().fill(st == .sprout ? Color(hex: 0x97C459) : c).frame(width: size / 2, height: size / 2)
                    .overlay(Circle().strokeBorder(.white.opacity(sel ? 1 : 0.7), lineWidth: sel ? 2 : 1))
            }
            .frame(width: size, height: size)
            .scaleEffect(sel ? 1.25 : (st == .bloom ? (pulse ? 1.1 : 0.9) : 1))
            .frame(width: max(44, size), height: max(44, size))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(p.text + ", " + tr(st.label))
    }

    private func detail(_ p: PrayerItem) -> some View {
        let st = PrayerGarden.stage(p)
        let today = AppStore.dayKey()
        let days = p.daysPrayed == 1 ? tr("1 day") : tr("\(p.daysPrayed) days")
        let growth: String = {
            if p.answered && !p.testimony.isEmpty { return tr("What God did:") + " " + p.testimony }
            if p.answered { return tr("Answered. You prayed for this on \(days).") }
            if let n = PrayerGarden.daysToNext(p) {
                return tr("Prayed on \(days).") + " " + tr(n == 1 ? "1 more day of prayer and it grows." : "\(n) more days of prayer and it grows.")
            }
            return tr("Prayed on \(days).") + " " + tr("Only God's answer makes it bloom. \"Be not weary in well doing.\" Galatians 6:9")
        }()
        return GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle().fill(PrayerGarden.color(p)).frame(width: 12, height: 12)
                    D(tr(st.label) + (p.forWhom.isEmpty ? "" : " · " + tr("for") + " " + p.forWhom)).font(.hs(12)).foregroundStyle(HS.textMuted)
                }
                D(p.text).font(.hs(17, .semibold)).foregroundStyle(HS.text)
                D(growth).font(.hs(13)).foregroundStyle(HS.textMuted)
                HStack(spacing: 8) {
                    if !p.answered {
                        if p.lastPrayedDay != today {
                            gardenButton("I prayed today", primary: true) { pray(p) }
                        } else {
                            gardenButton("Prayed today ✓", primary: false) { note = "You've already prayed for this today. Come back tomorrow." }
                        }
                        gardenButton("Prayer answered", primary: false) { answering = p }
                    } else {
                        ShareLink(item: testimonyText(p)) {
                            T("Share testimony").font(.hs(13, .semibold)).foregroundStyle(HS.onGold).frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(RoundedRectangle(cornerRadius: 14).fill(HS.goldButton))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
    }

    private func pray(_ p: PrayerItem) {
        guard let i = store.prayers.firstIndex(where: { $0.id == p.id }) else { return }
        let before = PrayerGarden.stage(store.prayers[i])
        store.prayers[i].daysPrayed += 1
        store.prayers[i].lastPrayedDay = AppStore.dayKey()
        let after = PrayerGarden.stage(store.prayers[i])
        note = after != before ? "It grew into a \(after.label.lowercased())!" : "Watered with prayer today."
    }

    private func newBed() {
        let next = bed + 1
        for i in store.prayers.indices where store.prayers[i].bed == bed && !store.prayers[i].answered { store.prayers[i].bed = next }
        bed = next
        selectedId = nil
        note = "Fresh soil. Your keepsake bed is saved below."
    }

    private func testimonyText(_ p: PrayerItem) -> String {
        var s = tr("God answered my prayer:") + " " + p.text
        if !p.testimony.isEmpty { s += "\n\n" + p.testimony }
        s += "\n\n" + tr(p.daysPrayed == 1 ? "Prayed for on 1 day. — from my prayer garden on HolySteps" : "Prayed for on \(p.daysPrayed) days. — from my prayer garden on HolySteps")
        return s
    }

    /// The garden picture with a caption band, for the share sheet.
    @MainActor private func shareImage(_ scene: String, _ t: PrayerGarden.Tally) -> Image? {
        let card = VStack(alignment: .leading, spacing: 0) {
            Image(scene).resizable().scaledToFill().frame(width: 720, height: 894).clipped()
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("My prayer garden")).font(.system(size: 40, weight: .bold, design: .serif)).foregroundStyle(.white)
                Text(tr("Bed \(bed + 1)") + " · " + tr("\(t.plants) prayers") + " · " + tr("\(t.answered) answered") + " · HolySteps")
                    .font(.system(size: 26)).foregroundStyle(Color(hex: 0xF4C46A))
            }
            .padding(.horizontal, 43).frame(width: 720, height: 143, alignment: .leading)
        }
        .background(Color(hex: 0x140C18))
        guard let ui = ImageRenderer(content: card).uiImage else { return nil }
        return Image(uiImage: ui)
    }

    private func gardenButton(_ label: String, primary: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            T(label).font(.hs(13, .semibold)).foregroundStyle(primary ? HS.onGold : HS.text).frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 14).fill(primary ? HS.goldButton : HS.cardFill))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(primary ? .clear : HS.gold.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct AddPrayerSheet: View {
    let onAdd: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var who = ""
    var body: some View {
        NavigationStack {
            Form {
                Section { TextField(tr("What are you praying for?"), text: $text, axis: .vertical).lineLimit(2...5) }
                Section { TextField(tr("For whom? (optional)"), text: $who) } footer: { T("Leave it empty or write \"me\" for your own prayer.") }
            }
            .navigationTitle(tr("Plant a prayer")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Plant")) { onAdd(text.trimmingCharacters(in: .whitespacesAndNewlines), who.trimmingCharacters(in: .whitespaces)); dismiss() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct AnsweredSheet: View {
    let prayer: String
    let onConfirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var testimony = ""
    var body: some View {
        NavigationStack {
            Form {
                Section { D(prayer).font(.hs(15, .semibold)) }
                Section { TextField(tr("What did God do? (optional)"), text: $testimony, axis: .vertical).lineLimit(2...6) }
                    footer: { T("Your testimony stays on this phone unless you share it.") }
            }
            .navigationTitle(tr("Prayer answered")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(tr("It bloomed")) { onConfirm(testimony.trimmingCharacters(in: .whitespacesAndNewlines)); dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}

/// The garden's picture in small, at the top of Faith → Pray.
struct PrayerGardenCard: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("gardenBed") private var bed = 0
    var body: some View {
        let plants = PrayerGarden.plants(store.prayers, bed: bed)
        let t = PrayerGarden.tally(plants)
        NavigationLink { PrayerGardenView() } label: {
            Color.clear.frame(height: 150)
                .overlay(Image(PrayerGarden.scene(plants)).resizable().scaledToFill(), alignment: .bottom)
                .overlay(LinearGradient(colors: [.clear, Color(hex: 0x140C18).opacity(0.8)], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        T("Your prayer garden").font(.hs(17, .semibold)).foregroundStyle(.white)
                        D(t.plants == 0 ? tr("Plant your first prayer and watch it grow") : tr("\(t.praying) growing · \(t.answered) in bloom"))
                            .font(.hs(12)).foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(14)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20).padding(.bottom, 12)
    }
}
