import SwiftUI

/// Android's Mind tracks (BodyBasics.kt MindTracks, MindTracksScreen): seven short days each, with a thought, one
/// thing to do and a question to write about. Men's and women's tracks as on Android; the data is Android's own,
/// converted to Resources/mind_tracks.json.
struct MindTrack: Decodable, Identifiable {
    struct Day: Decodable { let title, read, doThis, write, ref: String }
    let id: String, title: String, blurb: String, forWomen: Bool
    let days: [Day]

    static let all: [MindTrack] = {
        guard let u = Bundle.main.url(forResource: "mind_tracks", withExtension: "json"),
              let d = try? Data(contentsOf: u), let t = try? JSONDecoder().decode([MindTrack].self, from: d) else { return [] }
        return t
    }()

    static func forGender(_ g: String) -> [MindTrack] {
        switch g { case "male": all.filter { !$0.forWomen }; case "female": all.filter(\.forWomen); default: all }
    }
}

final class MindTrackProgress: ObservableObject {
    static let shared = MindTrackProgress()
    @Published private(set) var done: [String: Set<Int>] = [:]
    private init() {
        if let d = UserDefaults.standard.dictionary(forKey: "mindTrackDays") as? [String: [Int]] { done = d.mapValues(Set.init) }
    }
    func mark(_ id: String, _ day: Int) {
        done[id, default: []].insert(day)
        UserDefaults.standard.set(done.mapValues { Array($0).sorted() }, forKey: "mindTrackDays")
    }
}

struct MindTracksView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var progress = MindTrackProgress.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header("🧠 MIND", "Mind tracks", "Seven short days each: a thought, one thing to do, and a question to write about.")
                ForEach(MindTrack.forGender(store.gender)) { t in
                    let n = progress.done[t.id]?.count ?? 0
                    NavigationLink { MindTrackView(track: t) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            T(t.title).font(.hs(17, .semibold)).foregroundStyle(HS.text)
                            T(t.blurb).font(.hs(13)).foregroundStyle(HS.textSecondary)
                            D(n == 0 ? tr("7 days · start") : n >= 7 ? tr("Finished ✓") : tr("Day {0} of 7").replacingOccurrences(of: "{0}", with: "\(n + 1)"))
                                .font(.hs(13, .semibold)).foregroundStyle(HS.faith).padding(.top, 2)
                        }
                        .multilineTextAlignment(.leading).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr("Mind tracks"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func header(_ label: String, _ title: String, _ sub: String) -> some View {
    GlassCard(warm: true) {
        VStack(alignment: .leading, spacing: 4) {
            D(label).font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
            D(tr(title)).font(.hs(24, .light)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
            D(tr(sub)).font(.hs(13)).foregroundStyle(HS.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MindTrackView: View {
    let track: MindTrack
    @ObservedObject private var progress = MindTrackProgress.shared
    @State private var open: Int

    init(track: MindTrack) {
        self.track = track
        let mine = MindTrackProgress.shared.done[track.id] ?? []
        _open = State(initialValue: (1...7).first { !mine.contains($0) } ?? 7)
    }

    var body: some View {
        let mine = progress.done[track.id] ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header("🧠 MIND TRACK", track.title, track.blurb)
                ForEach(Array(track.days.enumerated()), id: \.offset) { i, d in
                    let day = i + 1, isDone = mine.contains(day)
                    VStack(alignment: .leading, spacing: 6) {
                        Button { open = day } label: {
                            D((isDone ? "✓ " : "") + tr("Day") + " \(day) · " + tr(d.title)).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        if open == day {
                            T(d.read).font(.hs(15)).foregroundStyle(HS.text)
                            D(tr("Read:") + " " + d.ref).font(.hs(13, .semibold)).foregroundStyle(HS.faith)
                            T("Do this").font(.hs(12, .bold)).foregroundStyle(HS.faith).padding(.top, 4)
                            T(d.doThis).font(.hs(14)).foregroundStyle(HS.text)
                            T("Write about it").font(.hs(12, .bold)).foregroundStyle(HS.faith).padding(.top, 4)
                            T(d.write).font(.hs(14)).foregroundStyle(HS.text)
                            HStack(spacing: 8) {
                                NavigationLink { PrayerJournalView(section: 1) } label: {
                                    T("Open journal").font(.hs(13)).foregroundStyle(HS.text).frame(maxWidth: .infinity, minHeight: 40)
                                        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(HS.gold.opacity(0.35)))
                                }
                                Button { if !isDone { progress.mark(track.id, day); if day < 7 { open = day + 1 } } } label: {
                                    T(isDone ? "Done ✓" : "Mark done").font(.hs(13, .semibold)).foregroundStyle(isDone ? HS.onGold : HS.text)
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(isDone ? AnyShapeStyle(HS.goldButton) : AnyShapeStyle(HS.cardFill)))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 6)
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(open == day ? HS.faith.opacity(0.4) : .clear))
                }
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr(track.title))
        .navigationBarTitleDisplayMode(.inline)
    }
}
