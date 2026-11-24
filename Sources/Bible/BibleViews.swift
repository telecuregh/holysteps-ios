import SwiftUI

/// The bar at the bottom of the reader while a chapter is being read aloud.
struct ListeningBar: View {
    @ObservedObject private var l = BibleListening.shared
    var onGoTo: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button(action: onGoTo) {
                    VStack(alignment: .leading, spacing: 2) {
                        D("🎧 \(l.title)").font(.hs(14, .semibold)).foregroundStyle(HS.text).lineLimit(1)
                        if l.loading {
                            T("Opening…").font(.hs(12)).foregroundStyle(HS.textMuted)
                        } else if let e = l.error {
                            D(e).font(.hs(12)).foregroundStyle(HS.cycle).lineLimit(2)
                        } else {
                            T("Verse \(l.verse) of \(l.verseCount)").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    }
                }
                .accessibilityHint(tr("Go to the chapter being read"))
                Spacer()
                Button { l.toggle() } label: {
                    Image(systemName: l.playing ? "pause.circle.fill" : "play.circle.fill").font(.hs(34)).foregroundStyle(HS.goldButton)
                }
                .accessibilityLabel(tr(l.playing ? "Pause" : "Play"))
                Button { l.nextVerse() } label: {
                    Image(systemName: "forward.end.fill").font(.hs(18)).foregroundStyle(HS.text)
                }
                .accessibilityLabel(tr("Next verse"))
                Button { l.stop() } label: {
                    Image(systemName: "xmark.circle").font(.hs(22)).foregroundStyle(HS.textMuted)
                }
                .accessibilityLabel(tr("Stop listening"))
            }
            HStack(spacing: 8) {
                Menu {
                    ForEach(BibleListening.speeds, id: \.self) { s in
                        Button(BibleListening.speedLabel(s)) { l.setSpeed(s) }
                    }
                } label: { pill("⏩ " + BibleListening.speedLabel(l.speed)) }
                Menu {
                    ForEach(BibleListening.sleepChoices, id: \.self) { m in
                        Button(BibleListening.sleepLabel(m)) { l.setSleep(m) }
                    }
                } label: {
                    if let end = l.sleepEndsAt {
                        pill("🌙 " + tr("Until") + " " + end.formatted(date: .omitted, time: .shortened))
                    } else {
                        pill("🌙 " + (l.sleepMinutes == -1 ? BibleListening.sleepLabel(-1) : tr("Sleep timer")))
                    }
                }
                Spacer()
                Menu {
                    ForEach(VoicePacks.narrators) { v in
                        Button { l.narrator = v.id } label: { D((l.narrator == v.id ? "✓ " : "") + v.name + " · " + tr(v.description)) }
                    }
                    Button { l.narrator = VoicePacks.deviceVoice } label: {
                        D((l.narrator == VoicePacks.deviceVoice ? "✓ " : "") + tr("Your phone's voice"))
                    }
                } label: {
                    D("🎙 " + (l.reader.isEmpty ? tr("Your phone's voice") : l.reader)).font(.hs(11)).foregroundStyle(HS.textMuted)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(HS.card.overlay(Rectangle().fill(HS.gold.opacity(0.06))))
    }

    private func pill(_ s: String) -> some View {
        D(s).font(.hs(12, .semibold)).foregroundStyle(HS.text)
            .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(HS.overlay(0.08)))
    }
}

/// Every highlighted verse and every note, newest first, with color and notes-only filters.
struct HighlightsView: View {
    @ObservedObject private var bible = BibleState.shared
    /// Set when opened from the reader: tapping a verse goes back there. Otherwise each verse opens a reader.
    var onOpen: ((String, Int, Int) -> Void)? = nil
    @State private var filter: HighlightColor?
    @State private var notesOnly = false
    @State private var editing: Highlight?
    @State private var image: VerseCard?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let all = bible.highlights
        let list = all.filter { notesOnly ? !$0.note.isEmpty : (filter == nil || ($0.isHighlighted && $0.color == filter)) }
            .sorted { $0.atMs > $1.atMs }
        ZStack {
            HSBackground()
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        T("\(all.filter { $0.isHighlighted }.count) highlighted · \(all.filter { !$0.note.isEmpty }.count) with notes")
                            .font(.hs(13)).foregroundStyle(HS.textMuted)
                        HStack(spacing: 8) {
                            filterChip("All", on: filter == nil && !notesOnly) { filter = nil; notesOnly = false }
                            filterChip("📝 Notes", on: notesOnly) { notesOnly = true; filter = nil }
                            ForEach(HighlightColor.allCases) { c in
                                let on = filter == c && !notesOnly
                                Button { filter = c; notesOnly = false } label: {
                                    Circle().fill(Color(hex: c.hex)).frame(width: 28, height: 28).overlay(Circle().stroke(.white, lineWidth: on ? 3 : 0))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(tr(c.label))
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                if list.isEmpty {
                    T(notesOnly ? "Tap any verse in the Bible reader and choose Note to write one."
                      : "Tap any verse in the Bible reader and choose a color to save it here.")
                        .foregroundStyle(HS.textSecondary).listRowBackground(Color.clear)
                }
                ForEach(list) { h in row(h).listRowBackground(HS.card.opacity(0.65)) }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(tr("Highlights and notes"))
        .toolbar {
            if onOpen != nil {
                ToolbarItem(placement: .confirmationAction) { Button(tr("Close")) { dismiss() }.tint(HS.goldButton) }
            }
        }
        .sheet(item: $editing) { h in
            NoteEditor(ref: h.ref, verse: h.text, initial: h.note) { note in bible.setNote(key: h.key, note: note); editing = nil }
        }
        .sheet(isPresented: Binding(get: { image != nil }, set: { if !$0 { image = nil } })) {
            if let c = image { VerseImageView(card: c) }
        }
    }

    @ViewBuilder
    private func row(_ h: Highlight) -> some View {
        let content = VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                if h.isHighlighted { Circle().fill(Color(hex: h.color.hex)).frame(width: 10, height: 10) } else { D("📝").font(.hs(11)) }
                D("\(tr(h.ref)) · \(h.translation)").font(.hs(13, .bold)).foregroundStyle(HS.faith)
                Spacer()
                Text(Date(timeIntervalSince1970: TimeInterval(h.atMs) / 1000), format: .dateTime.month(.abbreviated).day().year())
                    .font(.hs(11)).foregroundStyle(HS.textMuted)
            }
            D(h.text).foregroundStyle(HS.text)
            if !h.note.isEmpty { D("📝 \(h.note)").font(.hs(13)).foregroundStyle(HS.textSecondary) }
            HStack(spacing: 16) {
                Button(tr(h.note.isEmpty ? "Add a note" : "Edit note")) { editing = h }.buttonStyle(.borderless)
                Button(tr("Make an image")) {
                    image = VerseCard(text: h.text, ref: h.ref, translation: h.translation,
                                      attribution: Bible.known.first { $0.id == h.translation }?.attribution ?? "")
                }
                .buttonStyle(.borderless)
            }
            .font(.hs(12)).tint(HS.textMuted)
        }
        .padding(.vertical, 4)
        if let onOpen {
            content.contentShape(Rectangle()).onTapGesture { onOpen(h.book, h.ch, h.v) }
        } else {
            NavigationLink { BibleReaderView(startBook: h.book, startCh: h.ch, startVerse: h.v) } label: { content }
        }
    }

    private func filterChip(_ label: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            T(label).font(.hs(12)).foregroundStyle(on ? HS.onGold : HS.text)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(on ? HS.goldButton : HS.overlay(0.06)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The one-year plan: today's chapters, checked off as they're read, and the days around it.
struct BiblePlanView: View {
    @ObservedObject private var bible = BibleState.shared
    @State private var confirmStop = false

    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    T("Read the whole Bible in a year: 3 or 4 chapters a day, from Genesis to Revelation.")
                        .foregroundStyle(HS.textSecondary)
                    if let day = bible.planDay {
                        let doneCount = BiblePlan.chapters.filter { bible.isRead($0.book, $0.ch) }.count
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                T("Day \(day) of \(BiblePlan.days)").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                                ProgressView(value: Double(doneCount), total: Double(BiblePlan.totalChapters)).tint(HS.body)
                                T("\(doneCount) of \(BiblePlan.totalChapters) chapters read").font(.hs(12)).foregroundStyle(HS.textMuted)
                            }
                        }
                        ForEach(max(1, day - 1)...(day + 2), id: \.self) { d in dayCard(d, today: d == day) }
                        Button(tr("Stop the plan")) { confirmStop = true }.foregroundStyle(HS.textMuted)
                    } else {
                        GoldButton(title: tr("Start the one-year plan today")) { bible.startPlan() }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(tr("Bible in a year"))
        .alert(tr("Stop the plan?"), isPresented: $confirmStop) {
            Button(tr("Stop"), role: .destructive) { bible.stopPlan() }
            Button(tr("Cancel"), role: .cancel) {}
        } message: { T("The chapters you've read stay checked.") }
    }

    private func dayCard(_ d: Int, today: Bool) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    T(today ? "Today · Day \(d)" : "Day \(d)").font(.hs(14, .semibold)).foregroundStyle(today ? HS.gold : HS.textMuted)
                    Spacer()
                    if bible.planDone(day: d) { Image(systemName: "checkmark.seal.fill").foregroundStyle(HS.body) }
                }
                ForEach(Array(BiblePlan.chapters(day: d).enumerated()), id: \.offset) { _, c in
                    NavigationLink { BibleReaderView(startBook: c.book, startCh: c.ch) } label: {
                        HStack {
                            Image(systemName: bible.isRead(c.book, c.ch) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(bible.isRead(c.book, c.ch) ? HS.body : HS.textMuted)
                            T("\(c.book) \(c.ch)").foregroundStyle(HS.text)
                            Spacer()
                            Image(systemName: "chevron.right").font(.hs(12)).foregroundStyle(HS.textMuted)
                        }
                    }
                }
            }
        }
    }
}

/// The Bible's place on the Faith tab: continue reading, search, highlights and the one-year plan.
struct BibleHomeCard: View {
    @ObservedObject private var bible = BibleState.shared

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    T("BIBLE").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                    Spacer()
                    D(bible.translationId).font(.hs(11, .semibold)).foregroundStyle(HS.textMuted)
                }
                NavigationLink { BibleReaderView() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            T("Continue reading").font(.hs(12)).foregroundStyle(HS.textMuted)
                            T("\(bible.lastBook) \(bible.lastCh)").font(.hs(20, .semibold)).foregroundStyle(HS.text)
                        }
                        Spacer()
                        Image(systemName: "book.fill").font(.hs(22)).foregroundStyle(HS.faith)
                    }
                }
                HStack(spacing: 8) {
                    NavigationLink { HighlightsView() } label: { smallLink("🖍 Highlights") }
                    NavigationLink { BiblePlanView() } label: {
                        smallLink(bible.planDay.map { "📅 " + tr("Today") + ": " + tr(BiblePlan.reading(day: $0)) } ?? "📅 " + tr("Bible in a year"))
                    }
                }
            }
        }
    }

    private func smallLink(_ s: String) -> some View {
        D(s.hasPrefix("🖍") ? "🖍 " + tr("Highlights") : s).font(.hs(12, .semibold)).foregroundStyle(HS.text).lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 7).background(Capsule().fill(HS.overlay(0.08)))
    }
}
