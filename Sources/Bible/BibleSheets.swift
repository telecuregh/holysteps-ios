import SwiftUI
import MapKit

/// A sheet with the app's look: dark background, a title and a Close/Done button.
struct HSSheet<Content: View>: View {
    let title: String
    var doneLabel = "Close"
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                HS.solidSurface.ignoresSafeArea()
                content()
            }
            .navigationTitle(D(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HS.solidSurface, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(tr(doneLabel)) { dismiss() }.tint(HS.goldButton) } }
        }
        .presentationBackground(HS.solidSurface)
    }
}

// MARK: - Book and chapter

struct BookPicker: View {
    let t: Bible.Text
    let current: String
    let onPick: (String, Int) -> Void
    @State private var book: String?

    var body: some View {
        HSSheet(title: book.map { t.display($0, single: false) } ?? tr("Choose a book")) {
            if let b = book {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(1...max(1, t.chapters(b)), id: \.self) { c in
                            Button { onPick(b, c) } label: {
                                D("\(c)").font(.hs(16)).foregroundStyle(HS.text)
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(HS.overlay(0.06)))
                            }
                            .accessibilityLabel(tr("Chapter \(c)"))
                        }
                    }
                    .padding(16)
                    Button(tr("Books")) { book = nil }.tint(HS.goldButton).padding(.bottom, 20)
                }
            } else {
                ScrollViewReader { proxy in
                    List(t.books.map { $0.name }, id: \.self) { name in
                        Button {
                            if t.chapters(name) == 1 { onPick(name, 1) } else { book = name }
                        } label: {
                            D(t.display(name, single: false))
                                .foregroundStyle(name == current ? HS.faith : HS.text)
                                .fontWeight(name == current ? .bold : .regular)
                        }
                        .listRowBackground(HS.card.opacity(0.6))
                        .id(name)
                    }
                    .scrollContentBackground(.hidden)
                    .onAppear { proxy.scrollTo(current, anchor: .center) }
                }
            }
        }
    }
}

// MARK: - Bible language

struct LanguagePicker: View {
    let translations: [Bible.Translation]
    let current: String
    let onPick: (String) -> Void

    var body: some View {
        HSSheet(title: tr("Bible language")) {
            List {
                ForEach(Bible.languages(translations)) { l in
                    let n = translations.filter { $0.lang == l.code }.count
                    Button { onPick(l.code) } label: {
                        HStack {
                            D(l.name).foregroundStyle(l.code == current ? HS.faith : HS.text)
                                .fontWeight(l.code == current ? .bold : .regular)
                            Spacer()
                            T(n == 1 ? "1 Bible" : "\(n) Bibles").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    }
                    .listRowBackground(HS.card.opacity(0.6))
                }
                T("Each Bible downloads once (about 1–2 MB) and then works offline.").font(.hs(12)).foregroundStyle(HS.textMuted)
                    .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Text settings

struct ReaderSettingsView: View {
    @ObservedObject private var bible = BibleState.shared

    var body: some View {
        let p = bible.prefs
        HSSheet(title: tr("Text"), doneLabel: "Done") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    T("In the beginning was the Word, and the Word was with God, and the Word was God.")
                        .font(.system(size: CGFloat(p.textSize), design: p.font == .serif ? .serif : .default))
                        .lineSpacing(p.lineGap)
                        .foregroundStyle(p.highContrast ? .white : HS.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(p.highContrast ? Color(hex: 0x050507) : HS.overlay(0.05)))
                    T("Size  \(p.textSize)").font(.hs(14)).foregroundStyle(HS.textSecondary)
                    Slider(value: Binding(get: { Double(bible.prefs.textSize) }, set: { bible.prefs.textSize = Int($0.rounded()) }),
                           in: Double(ReaderPrefs.sizes.lowerBound)...Double(ReaderPrefs.sizes.upperBound), step: 1)
                        .tint(HS.goldButton)
                    T("Line spacing").font(.hs(14)).foregroundStyle(HS.textSecondary)
                    HStack(spacing: 6) {
                        ForEach(ReaderPrefs.lines, id: \.self) { l in
                            choice(String(format: "%g", l), on: l == p.lineSpacing) { bible.prefs.lineSpacing = l }
                        }
                    }
                    T("Typeface").font(.hs(14)).foregroundStyle(HS.textSecondary)
                    HStack(spacing: 6) {
                        ForEach(ReaderFont.allCases) { f in choice(tr(f.label), on: f == p.font) { bible.prefs.font = f } }
                    }
                    Toggle(isOn: $bible.prefs.highContrast) {
                        VStack(alignment: .leading) {
                            T("High contrast").foregroundStyle(HS.text)
                            T("White text on a black page").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    }
                    .tint(HS.goldButton)
                    Toggle(isOn: $bible.prefs.verseNumbers) {
                        VStack(alignment: .leading) {
                            T("Verse numbers").foregroundStyle(HS.text)
                            T("Show the small number before each verse").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    }
                    .tint(HS.goldButton)
                    Button(tr("Reset to default")) { bible.prefs = ReaderPrefs() }.foregroundStyle(HS.textMuted)
                }
                .padding(20)
            }
        }
    }

    private func choice(_ label: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            D(label).font(.hs(13)).foregroundStyle(on ? HS.onGold : HS.text)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10).fill(on ? HS.goldButton : HS.overlay(0.06)))
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Search

struct BibleSearchView: View {
    let t: Bible.Text
    let onGo: (String, Int, Int?) -> Void
    @State private var query = ""
    @State private var hits: [Bible.Hit]?
    @FocusState private var focused: Bool

    var body: some View {
        let ref = Bible.parseRef(query, in: t)
        let q = query.trimmingCharacters(in: .whitespaces)
        HSSheet(title: tr("Search the Bible")) {
            VStack(alignment: .leading, spacing: 10) {
                TextField(tr("John 3:16, Psalm 23, or words like \"peace\""), text: $query)
                    .textFieldStyle(.roundedBorder).focused($focused).submitLabel(.search)
                    .autocorrectionDisabled()
                    .onChange(of: query) { _, v in if v.count > 80 { query = String(v.prefix(80)) } }
                if let ref {
                    Button { onGo(ref.book, ref.ch, ref.v) } label: {
                        D(tr("Go to") + " \(t.display(ref.book)) \(ref.ch)" + (ref.v.map { ":\($0)" } ?? "") + " →")
                            .font(.hs(16, .semibold)).foregroundStyle(HS.faith).padding(.vertical, 10)
                    }
                } else if q.count < 2 {
                    T("Type a reference to jump there, or words to find every verse that has them.").font(.hs(12)).foregroundStyle(HS.textMuted)
                } else if let list = hits {
                    if list.isEmpty {
                        T("No verses found. Try fewer or different words.").font(.hs(12)).foregroundStyle(HS.textMuted)
                    } else {
                        T(list.count >= 200 ? "First 200 verses" : "\(list.count) verses").font(.hs(11)).foregroundStyle(HS.textMuted)
                        List(list) { h in
                            Button { onGo(h.book, h.ch, h.v) } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    D("\(t.display(h.book)) \(h.ch):\(h.v)").font(.hs(13, .bold)).foregroundStyle(HS.faith)
                                    D(h.text).font(.hs(13)).foregroundStyle(HS.text).lineLimit(3)
                                }
                            }
                            .listRowBackground(HS.card.opacity(0.6))
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                } else {
                    HStack(spacing: 8) { ProgressView(); T("Searching…").font(.hs(12)).foregroundStyle(HS.textMuted) }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .onAppear { focused = true }
        .task(id: query) {
            hits = nil
            let q = query
            guard q.trimmingCharacters(in: .whitespaces).count >= 2, Bible.parseRef(q, in: t) == nil else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)   // wait for typing to pause
            if Task.isCancelled { return }
            let text = t
            let found = await Task.detached(priority: .userInitiated) { Bible.search(text, q) }.value
            if !Task.isCancelled { hits = found }
        }
    }
}

// MARK: - Note

struct NoteEditor: View {
    let ref: String
    let verse: String
    let initial: String
    let onSave: (String) -> Void
    @State private var note = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                D(verse).font(.hs(13)).foregroundStyle(HS.textSecondary).lineLimit(4)
                TextField(tr("What is God saying to you in this verse?"), text: $note, axis: .vertical)
                    .lineLimit(6...14).textFieldStyle(.roundedBorder)
                    .onChange(of: note) { _, v in if v.count > Highlights.maxNote { note = String(v.prefix(Highlights.maxNote)) } }
                T("Kept on this phone. \(note.count)/\(Highlights.maxNote)").font(.hs(11)).foregroundStyle(HS.textMuted)
                Spacer()
            }
            .padding(16)
            .background(HS.solidSurface.ignoresSafeArea())
            .navigationTitle(D(ref)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !initial.isEmpty ? "Delete note" : "Save")) { onSave(note) }
                }
            }
            .tint(HS.goldButton)
        }
        .presentationBackground(HS.solidSurface)
        .onAppear { note = initial }
    }
}

// MARK: - Cross-references

struct CrossRefsView: View {
    let t: Bible.Text
    let book: String
    let ch: Int
    let v: Int
    let onOpen: (CrossRefs.Ref) -> Void
    @State private var refs: [CrossRefs.Ref]?

    var body: some View {
        HSSheet(title: tr("References for") + " \(t.display(book)) \(ch):\(v)") {
            Group {
                if let r = refs {
                    if r.isEmpty {
                        T("No cross-references for this verse.").foregroundStyle(HS.textSecondary).padding()
                    } else {
                        List {
                            ForEach(r) { ref in
                                Button { onOpen(ref) } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        D(ref.label { t.display($0) }).font(.hs(13, .bold)).foregroundStyle(HS.faith)
                                        if let first = t.chapter(ref.book, ref.ch)[safe: ref.v - 1] {
                                            D(first + (ref.isRange ? " …" : "")).font(.hs(14)).foregroundStyle(HS.text).lineLimit(4)
                                        } else {
                                            T("Not in this translation").font(.hs(12)).foregroundStyle(HS.textMuted)
                                        }
                                    }
                                }
                                .listRowBackground(HS.card.opacity(0.6))
                            }
                            T(CrossRefs.attribution).font(.hs(11)).foregroundStyle(HS.textMuted).listRowBackground(Color.clear)
                        }
                        .scrollContentBackground(.hidden)
                    }
                } else {
                    ProgressView()
                }
            }
        }
        .task { refs = await Task.detached { CrossRefs.forVerse(book: book, ch: ch, v: v) }.value }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { i >= 0 && i < count ? self[i] : nil }
}

// MARK: - Commentary

struct CommentaryView: View {
    let book: String
    let bookTitle: String
    let ch: Int
    let v: Int
    @State private var chapter: Commentary.Chapter?
    @State private var error: String?
    @State private var loading = true
    @State private var downloadedAlready = true
    @State private var retry = 0
    @State private var showAll = false

    var body: some View {
        HSSheet(title: "\(bookTitle) \(ch) · \(tr(Commentary.name))") {
            Group {
                if loading {
                    VStack(spacing: 8) {
                        ProgressView()
                        if !downloadedAlready {
                            T("Downloading the commentary on \(bookTitle) (one time)…").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    }
                } else if let error {
                    VStack(spacing: 10) {
                        D(error).foregroundStyle(HS.textSecondary)
                        Button(tr("Try again")) { retry += 1 }.tint(HS.goldButton)
                    }
                    .padding()
                } else if let c = chapter {
                    let forVerse = c.forVerse(v)
                    let shown = (showAll || forVerse.isEmpty) ? c.sections : forVerse
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if (showAll || forVerse.isEmpty) && !c.intro.isEmpty {
                                D(c.intro).font(.hs(14)).foregroundStyle(HS.textSecondary)
                            }
                            ForEach(shown) { s in
                                T(s.fromVerse == s.toVerse ? "Verse \(s.fromVerse)" : "Verses \(s.fromVerse)–\(s.toVerse)")
                                    .font(.hs(12, .bold)).foregroundStyle(HS.faith)
                                D(s.text).font(.hs(14)).foregroundStyle(HS.text)
                            }
                            if !showAll && !forVerse.isEmpty && c.sections.count > forVerse.count {
                                Button(tr("Read the whole chapter's commentary")) { showAll = true }.tint(HS.goldButton)
                            }
                            T(Commentary.attribution).font(.hs(11)).foregroundStyle(HS.textMuted)
                        }
                        .padding(16)
                    }
                }
            }
        }
        .task(id: retry) {
            loading = true; error = nil
            downloadedAlready = await BibleRepository.shared.isCommentaryDownloaded(book)
            do {
                chapter = try await BibleRepository.shared.commentary(book: book, ch: ch)
                if chapter == nil { error = tr("There's no commentary on this chapter.") }
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}

// MARK: - Compare translations

struct CompareView: View {
    let book: String
    let ch: Int
    let v: Int
    let translations: [Bible.Translation]
    @State private var rows: [Row]?
    struct Row: Identifiable { let id: String; let text: String }

    var body: some View {
        HSSheet(title: "\(Bible.englishDisplay(book)) \(ch):\(v)") {
            if let r = rows {
                List {
                    ForEach(r) { row in
                        VStack(alignment: .leading, spacing: 3) {
                            D(row.id).font(.hs(12, .bold)).foregroundStyle(HS.faith)
                            D(row.text).foregroundStyle(HS.text)
                        }
                        .listRowBackground(HS.card.opacity(0.6))
                    }
                    T("Choose another translation above to download it and see it here too.").font(.hs(11)).foregroundStyle(HS.textMuted)
                        .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
            } else {
                ProgressView()
            }
        }
        .task {
            var out: [Row] = []
            let repo = BibleRepository.shared
            for t in translations {
                guard await repo.isDownloaded(t) else { continue }
                if let text = try? await repo.load(t.id), let verse = text.chapter(book, ch)[safe: v - 1] { out.append(Row(id: t.id, text: verse)) }
            }
            rows = out
        }
    }
}

// MARK: - Places map

struct BibleMapView: View {
    let book: String
    let title: String
    let ch: Int

    var body: some View {
        let places = BiblePlaces.forChapter(book: book, ch: ch)
        HSSheet(title: title) {
            if places.isEmpty {
                T("No places are mapped for this chapter.").foregroundStyle(HS.textSecondary).padding()
            } else {
                VStack(spacing: 0) {
                    Map(initialPosition: .automatic) {
                        ForEach(places) { p in
                            Marker(p.name, coordinate: CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon)).tint(HS.goldButton)
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(places) { p in
                                D(p.name).font(.hs(12)).foregroundStyle(HS.text)
                                    .padding(.horizontal, 10).padding(.vertical, 6).background(Capsule().fill(HS.overlay(0.08)))
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                    T(BiblePlaces.attribution).font(.hs(11)).foregroundStyle(HS.textMuted).padding(.bottom, 8)
                }
            }
        }
    }
}

// MARK: - Verse image

struct VerseCard {
    let text: String
    let ref: String
    let translation: String
    let attribution: String
}

struct VerseImageView: View {
    let card: VerseCard
    @State private var image: Image?

    private var art: some View {
        VStack(spacing: 18) {
            D("“\(card.text)”")
                .font(.accent(30))
                .foregroundStyle(HS.peach).multilineTextAlignment(.center)
            D("\(card.ref) · \(card.translation)").font(.hs(18, .semibold)).foregroundStyle(HS.gold)
            if !card.attribution.isEmpty {
                D(card.attribution).font(.hs(11)).foregroundStyle(HS.textMuted)
            }
            D("HolySteps").font(.hs(14, .medium)).foregroundStyle(HS.textMuted)
        }
        .padding(48)
        .frame(width: 1080 / 2, height: 1350 / 2)
        .background(LinearGradient(colors: [HS.bgTop, HS.solidSurface, HS.bgBottom], startPoint: .top, endPoint: .bottom))
    }

    var body: some View {
        HSSheet(title: tr("Verse image")) {
            ScrollView {
                VStack(spacing: 16) {
                    art.scaleEffect(0.62).frame(width: 1080 / 2 * 0.62, height: 1350 / 2 * 0.62)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    if let image {
                        ShareLink(item: image, preview: SharePreview(card.ref, image: image)) {
                            T("Share image").font(.hs(16, .semibold)).foregroundStyle(HS.onGold)
                                .frame(maxWidth: .infinity).padding(.vertical, 14).background(Capsule().fill(HS.goldButton))
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .task {
            let r = ImageRenderer(content: art)
            r.scale = 2
            if let ui = r.uiImage { image = Image(uiImage: ui) }
        }
    }
}
