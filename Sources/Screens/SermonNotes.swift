import SwiftUI

/// Android's Sermon notes (Together.kt SermonNote, SermonNotesScreen): private notes on a sermon, kept on this
/// iPhone only (a protected file, unreadable while the phone is locked), with search, share and export.
struct SermonNote: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var date = AppStore.dayKey()
    var title = "", speaker = "", church = "", passages = "", notes = "", takeaway = "", prayer = ""
    var createdAt = Date(), updatedAt = Date()

    var isBlank: Bool { [title, speaker, church, passages, notes, takeaway, prayer].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }

    /// The note as plain text, for sharing or exporting.
    var asText: String {
        var out = [title.isEmpty ? tr("Sermon notes") : title]
        let who = [speaker, church].filter { !$0.isEmpty }.joined(separator: " · ")
        if !who.isEmpty { out.append(who) }
        out.append(SermonNotesStore.dayLabel(date))
        for (label, v) in [("Passages", passages), ("Notes", notes), ("What I'm taking with me", takeaway), ("To pray about", prayer)] where !v.isEmpty {
            out.append("\n\(tr(label)):\n\(v)")
        }
        return out.joined(separator: "\n")
    }
}

final class SermonNotesStore: ObservableObject {
    static let shared = SermonNotesStore()
    static let maxShort = 120, maxField = 8000
    @Published private(set) var notes: [SermonNote] = []

    private var file: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d.appendingPathComponent("sermon-notes.json")
    }

    private init() {
        if let d = try? Data(contentsOf: file), let n = try? JSONDecoder().decode([SermonNote].self, from: d) { notes = n }
    }

    /// Saves (or, if it's empty, drops) a note. Newest first.
    func save(_ n: SermonNote) {
        var n = n; n.updatedAt = Date()
        notes.removeAll { $0.id == n.id }
        if !n.isBlank { notes.insert(n, at: 0) }
        notes.sort { $0.date == $1.date ? $0.updatedAt > $1.updatedAt : $0.date > $1.date }
        write()
    }

    func delete(_ id: String) { notes.removeAll { $0.id == id }; write() }

    private func write() {
        guard let d = try? JSONEncoder().encode(notes) else { return }
        try? d.write(to: file, options: [.atomic, .completeFileProtection])
        var u = file; var v = URLResourceValues(); v.isExcludedFromBackup = true; try? u.setResourceValues(v)
    }

    static func search(_ all: [SermonNote], _ q: String) -> [SermonNote] {
        let words = q.lowercased().split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return all }
        return all.filter { n in
            let hay = [n.title, n.speaker, n.church, n.passages, n.notes, n.takeaway, n.prayer].joined(separator: " ").lowercased()
            return words.allSatisfy { hay.contains($0) }
        }
    }

    static func dayLabel(_ key: String) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: key) else { return key }
        return d.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())
    }
}

struct SermonNotesView: View {
    @ObservedObject private var store = SermonNotesStore.shared
    @State private var query = ""
    @State private var editing: SermonNote?

    var body: some View {
        let shown = SermonNotesStore.search(store.notes, query)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GlassCard(warm: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        T("📝 SERMON NOTES").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                        T("Your sermon notes").font(.hs(24, .light)).foregroundStyle(HS.text).accessibilityAddTraits(.isHeader)
                        T("Private to you and kept on this phone only. Share one whenever you like.").font(.hs(13)).foregroundStyle(HS.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Button { editing = SermonNote() } label: {
                        T("New note").font(.hs(15, .semibold)).foregroundStyle(HS.onGold).frame(maxWidth: .infinity, minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: 14).fill(HS.goldButton))
                    }
                    .buttonStyle(.plain)
                    if !store.notes.isEmpty {
                        ShareLink(item: store.notes.map(\.asText).joined(separator: "\n\n────────\n\n")) {
                            T("Export all").font(.hs(14, .semibold)).foregroundStyle(HS.faith).padding(.horizontal, 12)
                        }
                    }
                }
                if store.notes.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            T("No notes yet").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            T("Write down the passages, what stood out and what you'll carry into your week. If your church posts its sermons in My church, you can follow along there.")
                                .font(.hs(13)).foregroundStyle(HS.textMuted)
                            NavigationLink { ChurchTab() } label: { T("Open My church →").font(.hs(13)).foregroundStyle(HS.faith) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    TextField(tr("Search your notes"), text: $query).font(.hs(15)).padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
                    if shown.isEmpty { D(tr("Nothing matches") + " \u{201C}\(query)\u{201D}.").font(.hs(13)).foregroundStyle(HS.textMuted) }
                    ForEach(shown) { n in
                        Button { editing = n } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                D(SermonNotesStore.dayLabel(n.date)).font(.hs(12, .bold)).foregroundStyle(HS.peach)
                                D(n.title.isEmpty ? tr("Untitled sermon") : n.title).font(.hs(15, .bold)).foregroundStyle(HS.text).lineLimit(2)
                                let who = [n.speaker, n.church].filter { !$0.isEmpty }.joined(separator: " · ")
                                if !who.isEmpty { D(who).font(.hs(12)).foregroundStyle(HS.textMuted) }
                                if let p = [n.takeaway, n.notes, n.passages].first(where: { !$0.isEmpty }) {
                                    D(p).font(.hs(13)).foregroundStyle(HS.textMuted).lineLimit(2)
                                }
                            }
                            .multilineTextAlignment(.leading).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(HSBackground())
        .navigationTitle(tr("Sermon notes"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { n in NavigationStack { SermonNoteEditor(start: n) } }
    }
}

private struct SermonNoteEditor: View {
    let start: SermonNote
    @Environment(\.dismiss) private var dismiss
    @State private var n: SermonNote
    @State private var confirmDelete = false

    init(start: SermonNote) { self.start = start; _n = State(initialValue: start) }

    var body: some View {
        Form {
            Section {
                TextField(tr("Sermon title"), text: limited(\.title, SermonNotesStore.maxShort))
                TextField(tr("Preacher"), text: limited(\.speaker, SermonNotesStore.maxShort)).textInputAutocapitalization(.words)
                TextField(tr("Church"), text: limited(\.church, SermonNotesStore.maxShort)).textInputAutocapitalization(.words)
                DatePicker(tr("Date"), selection: Binding(get: { day(n.date) }, set: { n.date = AppStore.dayKey($0) }), displayedComponents: .date)
            }
            Section(tr("Passages, like Romans 8:28-39")) { TextField("", text: limited(\.passages, 600), axis: .vertical) }
            Section(tr("Notes")) { TextField("", text: limited(\.notes, SermonNotesStore.maxField), axis: .vertical).lineLimit(6...) }
            Section(tr("What I'm taking with me")) { TextField("", text: limited(\.takeaway, SermonNotesStore.maxField), axis: .vertical).lineLimit(2...) }
            Section(tr("To pray about")) { TextField("", text: limited(\.prayer, SermonNotesStore.maxField), axis: .vertical).lineLimit(2...) }
            Section {
                if !n.isBlank { ShareLink(item: n.asText) { T("Share") } }
                Button(tr("Delete"), role: .destructive) { confirmDelete = true }
            } footer: {
                T("Saved on this phone when you leave. Notes stay on this phone only, so deleting HolySteps removes them: share or export them to keep a copy.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(HSBackground())
        .navigationTitle(n.title.isEmpty ? tr("New note") : n.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(tr("Done")) { SermonNotesStore.shared.save(n); dismiss() } } }
        // Nothing is lost: closing the sheet any way saves it (a note left empty isn't kept).
        .onDisappear { if n != start { SermonNotesStore.shared.save(n) } }
        .confirmationDialog(tr("Delete this note?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(tr("Delete"), role: .destructive) { SermonNotesStore.shared.delete(n.id); n = start; dismiss() }
        } message: { T("It can't be brought back.") }
    }

    private func limited(_ kp: WritableKeyPath<SermonNote, String>, _ max: Int) -> Binding<String> {
        Binding(get: { n[keyPath: kp] }, set: { n[keyPath: kp] = String($0.prefix(max)) })
    }
    private func day(_ key: String) -> Date {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key) ?? Date()
    }
}
