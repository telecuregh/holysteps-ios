import SwiftUI

/// Program progress on the phone ("id:day" keys, Android's programDone) and the program last opened.
@MainActor
final class ProgramStore: ObservableObject {
    static let shared = ProgramStore()
    @Published private(set) var done: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "programDone") ?? [])
    @Published var active: String? = UserDefaults.standard.string(forKey: "programActive") {
        didSet { UserDefaults.standard.set(active, forKey: "programActive") }
    }
    func complete(_ p: Program, day: Int) {
        done.insert("\(p.id):\(day)"); save()
        ActivityLog.shared.add(.walk)
    }
    func restart(_ p: Program) { done = done.filter { !$0.hasPrefix(p.id + ":") }; save() }
    private func save() { UserDefaults.standard.set(Array(done), forKey: "programDone") }
}

/// Fitness › Train: the program in progress, or a way into the programs (Android ProgramsEntryCard).
struct ProgramsEntryCard: View {
    @ObservedObject private var store = ProgramStore.shared
    var body: some View {
        let active = store.active.flatMap(Programs.byId)
        NavigationLink { if let active { ProgramDetailView(program: active) } else { ProgramsView() } } label: {
            GlassCard(padding: 14) {
                HStack(spacing: 12) {
                    T(active?.emoji ?? "🗓️").font(.system(size: 22)).frame(width: 40, height: 40).background(Circle().fill(HS.overlay(0.07)))
                    VStack(alignment: .leading, spacing: 2) {
                        T(active?.title ?? "Programs").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                        if let p = active {
                            let next = Programs.nextDay(p, store.done)
                            D(next > p.dayCount ? tr("Finished. Well done!") : tr("Day \(next) of \(p.dayCount) is ready")).font(.hs(12)).foregroundStyle(HS.textMuted)
                        } else {
                            T("A few weeks of short workouts with Scripture for each day").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    }
                    Spacer()
                    D("›").font(.hs(22)).foregroundStyle(HS.gold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ProgramsView: View {
    @EnvironmentObject var appStore: AppStore
    @ObservedObject private var store = ProgramStore.shared
    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    T("Programs").font(.hs(26)).foregroundStyle(HS.text)
                    ItalicAccent(text: "Train your body, feed your soul", size: 16)
                    ForEach(Programs.forGender(appStore.gender)) { p in
                        NavigationLink { ProgramDetailView(program: p) } label: {
                            GlassCard(padding: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    D(p.emoji + " " + tr(p.title)).font(.hs(16, .semibold)).foregroundStyle(HS.text)
                                    D(tr("\(p.dayCount) days") + " · " + p.minutes).font(.hs(12, .semibold)).foregroundStyle(HS.gold)
                                    T(p.blurb).font(.hs(13)).foregroundStyle(HS.textSecondary).fixedSize(horizontal: false, vertical: true)
                                    let n = Programs.doneDays(p, store.done)
                                    if n > 0 {
                                        ProgressView(value: Double(n), total: Double(p.dayCount)).tint(HS.goldButton)
                                        D(tr("\(n) of \(p.dayCount) days done")).font(.hs(11)).foregroundStyle(HS.textMuted)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProgramDetailView: View {
    let program: Program
    @EnvironmentObject var appStore: AppStore
    @ObservedObject private var store = ProgramStore.shared
    @ObservedObject private var account = AccountStore.shared
    @State private var open = 1
    @State private var playing: Int?
    @State private var confirmRestart = false
    @State private var paywall = false
    @State private var bible: (String, Int)?
    @State private var showBible = false

    private var unlocked: Bool { account.canUse(.devotionalPlans) || account.canUse(.walkPlus) }

    var body: some View {
        let p = program
        let next = Programs.nextDay(p, store.done)
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    D(p.emoji + " " + tr(p.title)).font(.hs(24)).foregroundStyle(HS.text)
                    D(tr("\(p.dayCount) days") + " · " + p.minutes + " · " + tr("\(Programs.doneDays(p, store.done)) done")).font(.hs(12, .semibold)).foregroundStyle(HS.gold)
                    if let note = p.note {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 4) {
                                T("Before you start").font(.hs(14, .semibold)).foregroundStyle(HS.text)
                                T(note).font(.hs(13)).foregroundStyle(HS.textSecondary)
                            }
                        }
                    }
                    dayCard(open, next: next)
                    ForEach(Array(p.weeks.enumerated()), id: \.offset) { wi, week in
                        VStack(alignment: .leading, spacing: 8) {
                            D(tr("Week \(wi + 1)") + " · " + tr(week.theme)).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                                ForEach(1...week.days.count, id: \.self) { i in
                                    let day = wi * 7 + i
                                    let isDone = store.done.contains("\(p.id):\(day)")
                                    Button { withAnimation { open = day } } label: {
                                        D(isDone ? "✓" : "\(day)").font(.hs(13, .semibold))
                                            .foregroundStyle(isDone ? HS.onGold : (day == open ? HS.text : HS.textMuted))
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(isDone ? AnyShapeStyle(HS.goldButton) : AnyShapeStyle(HS.overlay(day == open ? 0.14 : 0.06))))
                                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(day == open ? HS.gold : .clear, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(tr("Day \(day)") + (isDone ? ", " + tr("done") : ""))
                                }
                            }
                        }
                    }
                    if Programs.doneDays(p, store.done) > 0 {
                        Button(tr("Start this program over")) { confirmRestart = true }.font(.hs(13)).foregroundStyle(HS.textMuted)
                    }
                    Spacer().frame(height: 80)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { open = min(next, p.dayCount); store.active = p.id }
        .fullScreenCover(item: Binding(get: { playing.map { PlayingDay(day: $0) } }, set: { playing = $0?.day })) { d in
            RoutinePlayerView(routine: routine(d.day)) {
                store.complete(p, day: d.day)
                open = min(d.day + 1, p.dayCount)
            }
        }
        .sheet(isPresented: $paywall) { PlansView(feature: .walkPlus) }
        .fullScreenCover(isPresented: $showBible) {
            NavigationStack {
                BibleReaderView(startBook: bible?.0, startCh: bible?.1, startVerse: nil)
            }
            .environmentObject(appStore)
        }
        .alert(tr("Start over?"), isPresented: $confirmRestart) {
            Button(tr("Start over"), role: .destructive) { store.restart(p); open = 1 }
            Button(tr("Cancel"), role: .cancel) {}
        } message: { T("Your days in this program will be cleared and you'll start again from day 1.") }
    }

    private struct PlayingDay: Identifiable { let day: Int; var id: Int { day } }

    @ViewBuilder private func dayCard(_ day: Int, next: Int) -> some View {
        let p = program
        let info = p.dayInfo(day), week = p.week(day)
        let steps = Programs.workout(p, day: day)
        let isDone = store.done.contains("\(p.id):\(day)")
        let locked = day > next
        let needsPlan = day > Programs.freeDays && !unlocked
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                D(tr("Week \((day - 1) / 7 + 1)") + " · " + tr(week.theme)).font(.hs(12, .semibold)).foregroundStyle(HS.gold)
                D(tr("Day \(day)") + " · " + (p.isRest(day) ? tr("Rest walk") : tr("\(Programs.minutes(steps)) min"))).font(.hs(18, .semibold)).foregroundStyle(HS.text)
                HStack(spacing: 8) {
                    D("📖 " + info.ref).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    Spacer()
                    if let r = Self.bibleRef(info.ref) {
                        Button { bible = r; showBible = true } label: {
                            T("Read").font(.hs(12, .semibold)).foregroundStyle(HS.text).padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(HS.overlay(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                T(info.line).font(.accent(16)).foregroundStyle(HS.italic)
                VStack(alignment: .leading, spacing: 3) {
                    T("🙏 Prayer for this week").font(.hs(13, .semibold)).foregroundStyle(HS.text)
                    T(week.prayer).font(.hs(13)).foregroundStyle(HS.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                let moves = steps.filter { !$0.rest }.map(\.move).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                HStack(spacing: 6) {
                    ForEach(moves.prefix(5), id: \.self) { m in
                        VStack(spacing: 3) {
                            TrainerThumb(key: m).aspectRatio(0.8, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 10))
                            D(tr(Programs.moveName(m))).font(.hs(10)).foregroundStyle(HS.textMuted).lineLimit(2).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                if isDone {
                    Button { playing = day } label: {
                        T("✓ Done · Do it again").font(.hs(15, .semibold)).foregroundStyle(HS.text).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(HS.gold.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                } else if locked {
                    D(tr("Finish day \(next) first.")).font(.hs(13)).foregroundStyle(HS.textMuted)
                } else {
                    GoldButton(title: needsPlan ? "🔒 Start day \(day)" : "Start day \(day)") {
                        if needsPlan { paywall = true } else { playing = day }
                    }
                }
            }
        }
        .task(id: day) { await TrainerLoops.shared.prefetch(routine(day).steps) }
    }

    /// Today's workout as a guided routine for the shared player (trainer clip on every move, rests between).
    private func routine(_ day: Int) -> GuidedRoutine {
        let p = program
        let steps = Programs.workout(p, day: day).map { s -> RoutineStep in
            if s.rest {
                return RoutineStep(name: "Rest", seconds: s.seconds, cue: tr("Next up: \(Programs.moveName(s.move))"), rest: true, move: s.move)
            }
            let name = Programs.moveName(s.move) + (s.rounds > 1 ? " · " + tr("round \(s.round)/\(s.rounds)") : "")
            return RoutineStep(name: name, seconds: s.seconds, cue: "", rest: false, move: s.move)
        }
        return GuidedRoutine(id: "prog_\(p.id)_\(day)", title: tr("Day \(day)") + " · " + tr(p.title), kind: "STRENGTH", summary: "",
                             equipment: "None", caution: p.note ?? "", venue: "INDOOR", zones: [], externalRoute: nil,
                             nominalMinutes: 0, steps: steps)
    }

    /// "Psalm 139:13-14" → ("Psalms", 139); "3 John 1:2" → ("3 John", 1); "Psalm 121" → ("Psalms", 121).
    static func bibleRef(_ ref: String) -> (String, Int)? {
        let parts = ref.split(separator: " ")
        guard let last = parts.last, let ch = Int(last.split(separator: ":").first ?? "") else { return nil }
        var book = parts.dropLast().joined(separator: " ")
        if book == "Psalm" { book = "Psalms" }
        return Bible.canonNames.contains(book) ? (book, ch) : nil
    }
}

/// A trainer's photo for a move (Kojo for men, Amara for everyone else), with a plain surface while it loads.
struct TrainerThumb: View {
    let key: String
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            HS.overlay(0.06)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
        }
        .accessibilityLabel(tr("Trainer") + " " + TrainerClips.trainerName)
        .task(id: key) { if let u = TrainerClips.photo(key) { image = await TrainerPhotos.shared.image(u) } }
    }
}
