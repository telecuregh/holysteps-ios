import SwiftUI
import UniformTypeIdentifiers

// MARK: - The person's own music

/// One of the person's own audio files: only where it lives (a bookmark) and a name, kept on this phone.
struct MyTrack: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let bookmark: Data
    var item: MusicItem { MusicItem(id: "own:\(id.uuidString)", title: title, subtitle: tr("My music"), source: .own(bookmark)) }
}

@MainActor
final class MyMusicStore: ObservableObject {
    static let shared = MyMusicStore()
    static let max = 300
    @Published private(set) var tracks: [MyTrack] = []

    private init() {
        if let d = UserDefaults.standard.data(forKey: "myMusic"), let list = try? JSONDecoder().decode([MyTrack].self, from: d) { tracks = list }
    }

    private func save() { if let d = try? JSONEncoder().encode(tracks) { UserDefaults.standard.set(d, forKey: "myMusic") } }

    /// "01_Great_Is_Thy_Faithfulness.mp3" → "01 Great Is Thy Faithfulness".
    nonisolated static func title(fromFileName name: String) -> String {
        let base = (name as NSString).deletingPathExtension.replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String((base.isEmpty ? "Untitled track" : base).prefix(120))
    }

    func add(_ urls: [URL]) -> Int {
        var added = 0
        for u in urls where tracks.count < MyMusicStore.max {
            let ok = u.startAccessingSecurityScopedResource()
            defer { if ok { u.stopAccessingSecurityScopedResource() } }
            guard let b = try? u.bookmarkData(), !tracks.contains(where: { $0.bookmark == b }) else { continue }
            tracks.append(MyTrack(id: UUID(), title: MyMusicStore.title(fromFileName: u.lastPathComponent), bookmark: b))
            added += 1
        }
        save()
        return added
    }

    func remove(_ t: MyTrack) { tracks.removeAll { $0.id == t.id }; save() }
}

// MARK: - The HolySteps content library (music and hymns added from the console)

struct LibraryItem: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let premium: Bool
    let url: URL?
    var item: MusicItem? { url.map { MusicItem(id: "lib:\(id)", title: title, subtitle: author, source: .remote($0)) } }
}

enum ContentLibrary {
    static let base = "https://holysteps.org/holysteps/library/index.json?type="

    /// The catalog for "music" or "hymn": only items recorded in the app's language. Premium items come without a link
    /// for accounts without a plan and stay listed (locked) until sign-in arrives in phase 2.
    static func catalog(_ type: String) async -> [LibraryItem] {
        guard let u = URL(string: base + type),
              let r = try? await URLSession.shared.data(from: u), (r.1 as? HTTPURLResponse)?.statusCode == 200,
              let o = try? JSONSerialization.jsonObject(with: r.0) as? [String: Any], let items = o["items"] as? [[String: Any]] else { return [] }
        let lang = I18n.shared.spanish ? "es" : "en"
        return items.compactMap { i in
            guard let id = i["id"] as? String, !id.isEmpty else { return nil }
            let audio = (i["audio"] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
            let premium = i["premium"] as? Bool ?? false
            if audio == nil && !premium { return nil }
            if ((i["lang"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "en") != lang { return nil }
            return LibraryItem(id: id, title: i["title"] as? String ?? "", author: i["author"] as? String ?? "", premium: premium, url: audio)
        }
    }
}

// MARK: - Screen

struct MusicView: View {
    @ObservedObject private var player = MusicPlayer.shared
    @ObservedObject private var mine = MyMusicStore.shared
    @State var tab = 0
    @State private var need: MusicNeed?
    @State private var importing = false
    @State private var note = ""
    @State private var libMusic: [LibraryItem] = []
    @State private var libHymns: [LibraryItem] = []
    @State private var libLoading = true

    var body: some View {
        ZStack {
            HSBackground()
            VStack(spacing: 0) {
                if player.active { PlayerCard().padding(.horizontal, 16).padding(.bottom, 8) }
                Picker("", selection: $tab) {
                    T("Gospel").tag(0)
                    T("Hymns").tag(1)
                    D(tr("Mine") + " (\(mine.tracks.count))").tag(2)
                    T("Library").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.bottom, 8)
                List {
                    switch tab {
                    case 0: gospel
                    case 1: hymns
                    case 2: own
                    default: library
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
        }
        .navigationTitle(tr("🎶 Christian music"))
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                let n = mine.add(urls)
                note = n == 0 ? tr("Those files are already in your list.") : tr(n == 1 ? "Added 1 song" : "Added \(n) songs")
            }
        }
        .task {
            async let m = ContentLibrary.catalog("music")
            async let h = ContentLibrary.catalog("hymn")
            libMusic = await m
            libHymns = await h
            libLoading = false
        }
    }

    // MARK: Tabs

    @ViewBuilder private var gospel: some View {
        Section {
            T("What are you carrying today?").font(.hs(13)).foregroundStyle(HS.textSecondary).listRowBackground(Color.clear)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip(tr("All"), on: need == nil) { need = nil }
                    ForEach(MusicNeed.allCases) { n in chip(n.emoji + " " + tr(n.label), on: need == n) { need = n } }
                }
            }
            .listRowBackground(Color.clear)
        }
        let list = need.map { WorshipMusic.forNeed($0) } ?? WorshipMusic.worship
        Section {
            ForEach(Array(list.enumerated()), id: \.element.id) { i, t in
                trackRow(t.item, scripture: t.scripture) { player.play(list.map(\.item), start: i) }
            }
        }
    }

    @ViewBuilder private var hymns: some View {
        Section(header: header("Sung hymns")) {
            ForEach(Array(WorshipMusic.sungHymns.enumerated()), id: \.element.id) { i, t in
                trackRow(t.item, scripture: t.scripture) { player.play(WorshipMusic.sungHymns.map(\.item), start: i) }
            }
        }
        Section(header: header("Country gospel")) {
            ForEach(Array(WorshipMusic.countryGospel.enumerated()), id: \.element.id) { i, t in
                trackRow(t.item, scripture: t.scripture) { player.play(WorshipMusic.countryGospel.map(\.item), start: i) }
            }
        }
        if !libHymns.isEmpty {
            Section(header: header("Recorded hymns")) { libraryRows(libHymns) }
        }
    }

    @ViewBuilder private var own: some View {
        Section {
            Button { importing = true } label: {
                Label(tr("Add songs from Files"), systemImage: "plus.circle.fill").foregroundStyle(HS.goldButton)
            }
            .listRowBackground(Color.clear)
            if !note.isEmpty { D(note).font(.hs(12)).foregroundStyle(HS.textMuted).listRowBackground(Color.clear) }
            T("Your songs play from where they are. HolySteps keeps only their names on this phone and never copies or uploads them.")
                .font(.hs(12)).foregroundStyle(HS.textMuted).listRowBackground(Color.clear)
        }
        Section {
            ForEach(Array(mine.tracks.enumerated()), id: \.element.id) { i, t in
                trackRow(t.item, scripture: nil) { player.play(mine.tracks.map(\.item), start: i) }
                    .swipeActions { Button(role: .destructive) { mine.remove(t) } label: { Label(tr("Remove"), systemImage: "trash") } }
            }
        }
    }

    @ViewBuilder private var library: some View {
        if libLoading {
            T("Loading…").foregroundStyle(HS.textMuted).listRowBackground(Color.clear)
        } else if libMusic.isEmpty {
            T("No library music yet. Worship music added in the HolySteps console shows up here.")
                .foregroundStyle(HS.textMuted).listRowBackground(Color.clear)
        } else {
            libraryRows(libMusic)
            T("This music is added by HolySteps and streamed, so the first play of a song needs a connection.")
                .font(.hs(12)).foregroundStyle(HS.textMuted).listRowBackground(Color.clear)
        }
    }

    @ViewBuilder private func libraryRows(_ items: [LibraryItem]) -> some View {
        let playable = items.compactMap(\.item)
        ForEach(items) { li in
            if let item = li.item {
                trackRow(item, scripture: nil) { player.play(playable, start: playable.firstIndex(of: item) ?? 0) }
            } else {
                HStack {
                    VStack(alignment: .leading) { D(li.title).foregroundStyle(HS.textMuted); D(li.author).font(.hs(12)).foregroundStyle(HS.textMuted) }
                    Spacer()
                    T("Premium").font(.hs(11)).foregroundStyle(HS.textMuted)
                }
                .listRowBackground(HS.card.opacity(0.4))
            }
        }
    }

    // MARK: Pieces

    private func header(_ s: String) -> some View {
        T(s).font(.hs(13, .semibold)).foregroundStyle(HS.textSecondary)
    }

    private func chip(_ s: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            D(s).font(.hs(12, .semibold)).foregroundStyle(on ? HS.onGold : HS.text)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(on ? HS.goldButton : Color.white.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func trackRow(_ item: MusicItem, scripture: String?, play: @escaping () -> Void) -> some View {
        let now = player.isCurrent(item)
        return Button(action: { now ? player.toggle() : play() }) {
            HStack(spacing: 12) {
                Image(systemName: now && player.playing ? "speaker.wave.2.fill" : "play.circle.fill")
                    .font(.hs(22)).foregroundStyle(HS.goldButton).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    T(item.title).font(.hs(14, .semibold)).foregroundStyle(now ? HS.gold : HS.text)
                    T(item.subtitle).font(.hs(12)).foregroundStyle(HS.textMuted).lineLimit(2)
                    if let scripture { T(scripture).font(.hs(11)).foregroundStyle(HS.faith) }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(HS.card.opacity(0.65))
    }
}

/// What's playing, with the controls.
struct PlayerCard: View {
    @ObservedObject private var p = MusicPlayer.shared

    private func mmss(_ s: Double) -> String {
        guard s.isFinite else { return "0:00" }
        let n = Int(max(0, s)); return String(format: "%d:%02d", n / 60, n % 60)
    }

    var body: some View {
        if let item = p.current {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        T(item.title).font(.hs(14, .semibold)).foregroundStyle(HS.text).lineLimit(1)
                        T(item.subtitle).font(.hs(12)).foregroundStyle(HS.textMuted).lineLimit(1)
                    }
                    Spacer()
                    Button { p.stop() } label: { Image(systemName: "xmark.circle").font(.hs(20)).foregroundStyle(HS.textMuted) }
                        .accessibilityLabel(tr("Stop"))
                }
                Slider(value: Binding(get: { min(p.elapsed, max(p.duration, 0.1)) }, set: { p.seek($0) }), in: 0...max(p.duration, 0.1))
                    .tint(HS.goldButton)
                HStack {
                    D(mmss(p.elapsed)).font(.hs(11).monospacedDigit())
                    Spacer()
                    D(mmss(p.duration)).font(.hs(11).monospacedDigit())
                }
                .foregroundStyle(HS.textMuted)
                HStack(spacing: 26) {
                    Button { p.setShuffle(!p.shuffle) } label: { Image(systemName: "shuffle").foregroundStyle(p.shuffle ? HS.goldButton : HS.textMuted) }
                        .accessibilityLabel(tr("Shuffle"))
                    Button { p.previous() } label: { Image(systemName: "backward.fill") }.accessibilityLabel(tr("Previous"))
                    Button { p.toggle() } label: { Image(systemName: p.playing ? "pause.circle.fill" : "play.circle.fill").font(.hs(44)) }
                        .foregroundStyle(HS.goldButton)
                        .accessibilityLabel(tr(p.playing ? "Pause" : "Play"))
                    Button { p.next() } label: { Image(systemName: "forward.fill") }.accessibilityLabel(tr("Next"))
                    Button { p.repeatOne.toggle() } label: { Image(systemName: "repeat.1").foregroundStyle(p.repeatOne ? HS.goldButton : HS.textMuted) }
                        .accessibilityLabel(tr("Repeat"))
                    Menu {
                        ForEach([0, 15, 30, 45, 60], id: \.self) { m in
                            Button(m == 0 ? tr("Off") : "\(m) min") { p.setSleepTimer(m) }
                        }
                    } label: { Image(systemName: p.sleepEndsAt == nil ? "moon" : "moon.fill").foregroundStyle(p.sleepEndsAt == nil ? HS.textMuted : HS.goldButton) }
                        .accessibilityLabel(tr("Sleep timer"))
                }
                .font(.hs(20))
                .foregroundStyle(HS.text)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(HS.card))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(HS.gold.opacity(0.24), lineWidth: 1))
        }
    }
}

/// The music entry on the Faith tab, with what's playing.
struct MusicCard: View {
    @ObservedObject private var p = MusicPlayer.shared

    var body: some View {
        NavigationLink { MusicView() } label: {
            GlassCard {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        T("🎶 CHRISTIAN MUSIC").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                        if let item = p.current {
                            T("Now playing: \(tr(item.title))").foregroundStyle(HS.text).lineLimit(1)
                        } else {
                            T("Worship songs, sung hymns and your own music").foregroundStyle(HS.text).multilineTextAlignment(.leading)
                        }
                    }
                    Spacer()
                    if p.active {
                        Button { p.toggle() } label: {
                            Image(systemName: p.playing ? "pause.circle.fill" : "play.circle.fill").font(.hs(34)).foregroundStyle(HS.goldButton)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "chevron.right").foregroundStyle(HS.gold)
                    }
                }
            }
        }
    }
}
