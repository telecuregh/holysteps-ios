import SwiftUI

/// The Bible reader, ported from Android's BibleReaderScreen: pick a translation, book and chapter; set the text the
/// way you like it; tap a verse to highlight it, write a note, see its cross-references and Matthew Henry's
/// commentary, make an image of it, compare or share it; or listen from any verse.
struct BibleReaderView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var bible = BibleState.shared
    @ObservedObject private var listening = BibleListening.shared
    @Environment(\.dismiss) private var dismiss

    var startBook: String? = nil
    var startCh: Int? = nil
    var startVerse: Int? = nil

    enum Sheet: Identifiable {
        case picker, language, settings, search, highlights, map
        case note(Int), refs(Int), commentary(Int), compare(Int), image(Int)
        var id: String {
            switch self {
            case .picker: return "picker"; case .language: return "language"; case .settings: return "settings"
            case .search: return "search"; case .highlights: return "highlights"; case .map: return "map"
            case .note(let v): return "note\(v)"; case .refs(let v): return "refs\(v)"; case .commentary(let v): return "comm\(v)"
            case .compare(let v): return "cmp\(v)"; case .image(let v): return "img\(v)"
            }
        }
    }

    @State private var book = ""
    @State private var ch = 1
    @State private var text: Bible.Text?
    @State private var error: String?
    @State private var retry = 0
    @State private var translations: [Bible.Translation] = Bible.known
    @State private var downloaded: Set<String> = []
    @State private var selected: Int?
    @State private var sheet: Sheet?
    @State private var scrollTo: Int?
    @State private var openedAt = Date()
    @State private var started = false

    private var tid: String { bible.translationId }
    private var current: Bible.Translation? { translations.first { $0.id == tid } ?? Bible.known.first { $0.id == tid } }
    private var lang: String { current?.lang ?? "en" }
    private var verses: [String] { text?.chapter(book, ch) ?? [] }
    private var prefs: ReaderPrefs { bible.prefs }
    private var readingHere: Bool { listening.active && listening.translation == tid && listening.book == book && listening.ch == ch }

    var body: some View {
        let marks = bible.marks(book: book, ch: ch)
        VStack(spacing: 0) {
            header
            translationRow
            content(marks: marks)
            if let sel = selected, let t = text, sel <= verses.count {
                verseActions(sel: sel, t: t, marks: marks)
            }
            if listening.active { ListeningBar(onGoTo: { book = listening.book; ch = listening.ch }) }
        }
        .background((prefs.highContrast ? Color(hex: 0x050507) : HS.bgMid).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $sheet) { s in sheetView(s) }
        .task(id: "\(tid)#\(retry)") {
            if !started {
                started = true
                book = startBook ?? bible.lastBook
                ch = startCh ?? bible.lastCh
                scrollTo = startVerse
            }
            await load()
            translations = await BibleRepository.shared.translations()
            downloaded = await BibleRepository.shared.downloadedIds()
        }
        .onChange(of: book) { _, _ in chapterChanged() }
        .onChange(of: ch) { _, _ in chapterChanged() }
        .onChange(of: listening.ch) { _, _ in followPlayer() }
        .onReceive(NotificationCenter.default.publisher(for: ChapterHeard.name)) { n in
            if let b = n.userInfo?["book"] as? String, let c = n.userInfo?["ch"] as? Int { bible.chapterRead(b, c, store: store) }
        }
    }

    private func load() async {
        error = nil; text = nil
        do {
            let t = try await BibleRepository.shared.load(tid)
            text = t
            downloaded.insert(tid)
            // Douay-Rheims has extra books and some different names; fall back to John 1.
            if !t.has(book) { book = "John"; ch = 1 }
            if ch > t.chapters(book) { ch = 1 }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func chapterChanged() {
        bible.setLast(book, ch)
        selected = nil
        openedAt = Date()
    }

    /// Follow the player when it moves on to the next chapter.
    private func followPlayer() {
        if listening.active && listening.playing && listening.translation == tid && !listening.book.isEmpty
            && (listening.book != book || listening.ch != ch) {
            book = listening.book; ch = listening.ch
        }
    }

    /// Reading a chapter to its end (and staying on it a little while) counts by itself.
    private func reachedEnd() {
        let b = book, c = ch, count = verses.count
        let need = min(60, max(15, Double(count) * 2))
        let left = need - Date().timeIntervalSince(openedAt)
        Task {
            if left > 0 { try? await Task.sleep(nanoseconds: UInt64(left * 1_000_000_000)) }
            if book == b && ch == c { bible.chapterRead(b, c, store: store) }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 2) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.title3).foregroundStyle(HS.textMuted).padding(10)
            }
            .accessibilityLabel(tr("Back"))
            Button { sheet = .picker } label: {
                Text(verbatim: "\(text?.display(book) ?? tr(Bible.englishDisplay(book))) \(ch) ▾")
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(HS.text).lineLimit(1).minimumScaleFactor(0.7)
            }
            .accessibilityLabel(tr("Choose a book and chapter"))
            Spacer(minLength: 4)
            headerIcon("magnifyingglass", "Search the Bible") { sheet = .search }
            headerIcon("headphones", "Listen to this chapter") { listen(from: 1) }
            headerIcon("textformat.size", "Text size and style") { sheet = .settings }
            headerIcon("highlighter", "Highlights and notes") { sheet = .highlights }
            headerIcon("map", "Places on this chapter's map") { sheet = .map }
        }
        .padding(.horizontal, 6).padding(.top, 4)
    }

    private func headerIcon(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(HS.faith).frame(width: 34, height: 36)
        }
        .accessibilityLabel(tr(label))
    }

    private var translationRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button { sheet = .language } label: {
                        Text(verbatim: "🌐 \(current?.language ?? "English") ▾").font(.caption.weight(.semibold)).foregroundStyle(HS.text)
                            .padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    .accessibilityLabel(tr("Change Bible language"))
                    ForEach(translations.filter { $0.lang == lang }) { t in
                        let on = t.id == tid
                        Button { bible.translationId = t.id } label: {
                            Text(verbatim: t.id + (downloaded.contains(t.id) || on ? "" : " ↓")).font(.caption.weight(.semibold))
                                .foregroundStyle(on ? HS.onGold : HS.text)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(on ? HS.goldButton : Color.white.opacity(0.06)))
                                .overlay(Capsule().stroke(HS.gold.opacity(on ? 0.8 : 0.2), lineWidth: 1))
                        }
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
            }
            if let c = current {
                Text(verbatim: c.name + (c.attribution.isEmpty ? "" : " · \(c.attribution)"))
                    .font(.system(size: 10)).foregroundStyle(HS.textMuted).lineLimit(1).padding(.horizontal, 20)
            }
            if let note = Bible.psalmNote(tid, book: book) {
                T(note).font(.system(size: 11)).foregroundStyle(HS.textMuted).padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: Text

    @ViewBuilder
    private func content(marks: [Int: Highlight]) -> some View {
        if let error {
            VStack(spacing: 12) {
                Spacer()
                Text(verbatim: error).foregroundStyle(HS.textSecondary).multilineTextAlignment(.center)
                Button(tr("Try again")) { retry += 1 }.buttonStyle(.borderedProminent).tint(HS.goldButton).foregroundStyle(HS.onGold)
                Spacer()
            }
            .padding(24).frame(maxWidth: .infinity)
        } else if let t = text {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(verses.enumerated()), id: \.offset) { i, v in
                            verseRow(n: i + 1, v: v, mark: marks[i + 1])
                                .id(i + 1)
                                .onAppear { if i + 1 == verses.count { reachedEnd() } }
                        }
                        chapterNav(t)
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 40)
                }
                .onChange(of: "\(book)|\(ch)") { _, _ in
                    if scrollTo == nil { proxy.scrollTo(1, anchor: .top) }
                }
                .onChange(of: verses.count) { _, _ in jump(proxy) }
                .onChange(of: scrollTo) { _, _ in jump(proxy) }
                .onChange(of: listening.verse) { _, v in
                    if readingHere && v > 0 { withAnimation { proxy.scrollTo(v, anchor: .center) } }
                }
                .onAppear { jump(proxy) }
            }
        } else {
            VStack(spacing: 10) {
                Spacer()
                ProgressView().tint(HS.faith)
                T("Opening the \(current?.name ?? "Bible")… (one-time download)").font(.footnote).foregroundStyle(HS.textMuted)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24).frame(maxWidth: .infinity)
        }
    }

    private func jump(_ proxy: ScrollViewProxy) {
        guard let v = scrollTo, !verses.isEmpty else { return }
        let target = max(1, min(v, verses.count))
        DispatchQueue.main.async {
            proxy.scrollTo(target, anchor: .top)
            selected = target
            scrollTo = nil
        }
    }

    private func verseRow(n: Int, v: String, mark: Highlight?) -> some View {
        let reading = readingHere && listening.verse == n
        let size = CGFloat(prefs.textSize)
        let design: Font.Design = prefs.font == .serif ? .serif : .default
        var line = Text(verbatim: "")
        if prefs.verseNumbers {
            line = Text(verbatim: "\(n) ").font(.system(size: size * 0.65, weight: .bold, design: design)).foregroundColor(HS.faith)
        }
        line = line + Text(verbatim: v).font(.system(size: size, design: design)).foregroundColor(prefs.highContrast ? .white : HS.text)
        let bg: Color = mark?.isHighlighted == true ? Color(hex: mark!.color.hex).opacity(0.22)
            : (selected == n ? Color.white.opacity(0.08) : .clear)
        return VStack(alignment: .leading, spacing: 2) {
            line
                .lineSpacing(prefs.lineGap)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(bg))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(reading ? Color(hex: 0xFCD34D) : .clear, lineWidth: 1.5))
                .contentShape(Rectangle())
                .onTapGesture { selected = selected == n ? nil : n }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(tr("Verse options"))
            if let note = mark?.note, !note.isEmpty {
                Text(verbatim: "📝 \(note)").font(.system(size: size * 0.75)).foregroundStyle(HS.textMuted).lineLimit(3)
                    .padding(.leading, 12).padding(.bottom, 4)
                    .onTapGesture { sheet = .note(n) }
            }
        }
        .padding(.vertical, 1)
    }

    private func chapterNav(_ t: Bible.Text) -> some View {
        let idx = t.bookIndex(book) ?? 0
        let canPrev = ch > 1 || idx > 0
        let canNext = ch < t.chapters(book) || idx < t.books.count - 1
        return HStack {
            Button(tr("‹ Previous")) {
                if ch > 1 { ch -= 1 } else if idx > 0 { book = t.books[idx - 1].name; ch = t.books[idx - 1].chapters.count }
            }.disabled(!canPrev)
            Spacer()
            Button(tr("Next ›")) {
                if ch < t.chapters(book) { ch += 1 } else if idx < t.books.count - 1 { book = t.books[idx + 1].name; ch = 1 }
            }.disabled(!canNext)
        }
        .tint(HS.goldButton)
        .padding(.top, 16)
    }

    // MARK: Verse actions

    private func verseActions(sel: Int, t: Bible.Text, marks: [Int: Highlight]) -> some View {
        let ref = "\(t.display(book)) \(ch):\(sel)"
        let verse = verses[sel - 1]
        let shareText = tr("\"\(verse)\" — \(ref) (\(tid))") + "\n\n" + tr("Shared from HolySteps. Get the app:") + " " + AppLinks.site
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: "\(ref) · \(tid)").font(.subheadline.weight(.semibold)).foregroundStyle(HS.text)
                Spacer()
                Button { selected = nil } label: { Image(systemName: "xmark").foregroundStyle(HS.textMuted).padding(6) }
                    .accessibilityLabel(tr("Close verse options"))
            }
            HStack(spacing: 12) {
                ForEach(HighlightColor.allCases) { c in
                    let on = marks[sel]?.isHighlighted == true && marks[sel]?.color == c
                    Button {
                        bible.toggleHighlight(Highlight(book: book, ch: ch, v: sel, color: c, text: verse, translation: tid, atMs: BibleState.nowMs))
                    } label: {
                        Circle().fill(Color(hex: c.hex)).frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Color.white, lineWidth: on ? 3 : 0))
                    }
                    .accessibilityLabel(tr("\(c.label) highlight"))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    actionChip("📝 Note") { sheet = .note(sel) }
                    actionChip("🖼 Image") { sheet = .image(sel) }
                    actionChip("🎧 Listen from here") { listen(from: sel) }
                    actionChip("🔗 References") { sheet = .refs(sel) }
                    actionChip("📚 Commentary") { sheet = .commentary(sel) }
                    actionChip("⇄ Compare") { sheet = .compare(sel) }
                    ShareLink(item: shareText) { chipLabel("↗ Share text") }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(HS.card)
    }

    private func chipLabel(_ s: String) -> some View {
        T(s).font(.caption.weight(.semibold)).foregroundStyle(HS.text)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    private func actionChip(_ s: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { chipLabel(s) }
    }

    private func listen(from v: Int) {
        BibleListening.shared.play(translation: tid, lang: lang, book: book, ch: ch, fromVerse: v)
    }

    // MARK: Sheets

    @ViewBuilder
    private func sheetView(_ s: Sheet) -> some View {
        switch s {
        case .picker:
            if let t = text { BookPicker(t: t, current: book) { b, c in book = b; ch = c; sheet = nil } }
        case .language:
            LanguagePicker(translations: translations, current: lang) { l in
                sheet = nil
                if l != lang { bible.translationId = Bible.defaultId(phoneLang: l, list: translations) }
            }
        case .settings:
            ReaderSettingsView()
        case .search:
            if let t = text { BibleSearchView(t: t) { b, c, v in sheet = nil; book = b; ch = c; scrollTo = v } }
        case .highlights:
            NavigationStack { HighlightsView(onOpen: { b, c, v in sheet = nil; book = b; ch = c; scrollTo = v }) }
        case .map:
            BibleMapView(book: book, title: "\(text?.display(book) ?? book) \(ch)", ch: ch)
        case .note(let v):
            if v <= verses.count {
                NoteEditor(ref: "\(text?.display(book) ?? book) \(ch):\(v)", verse: verses[v - 1], initial: bible.marks(book: book, ch: ch)[v]?.note ?? "") { note in
                    bible.saveNote(book: book, ch: ch, v: v, verseText: verses[v - 1], translation: tid, note: note)
                    sheet = nil
                }
            }
        case .refs(let v):
            if let t = text { CrossRefsView(t: t, book: book, ch: ch, v: v) { r in sheet = nil; book = r.book; ch = r.ch; scrollTo = r.v } }
        case .commentary(let v):
            CommentaryView(book: book, bookTitle: text?.display(book) ?? book, ch: ch, v: v)
        case .compare(let v):
            CompareView(book: book, ch: ch, v: v, translations: translations)
        case .image(let v):
            if v <= verses.count {
                VerseImageView(card: VerseCard(text: verses[v - 1], ref: "\(text?.display(book) ?? book) \(ch):\(v)", translation: tid, attribution: current?.attribution ?? ""))
            }
        }
    }
}

enum AppLinks {
    static let site = "https://holysteps.org"
}
