import SwiftUI

/// The Faith tab: the Bible, this week's sermon, and the prayer list and journal.
struct FaithView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ScreenTitle(text: "Faith")
                        BibleHomeCard()
                        DevotionalCard()
                        SermonCard()
                        MusicCard()
                        QuizCard()
                        NavigationLink { PrayerJournalView(section: 0) } label: {
                            GlassCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        T("PRAYER LIST AND JOURNAL").font(.caption.weight(.semibold)).foregroundStyle(HS.gold)
                                        T(store.prayers.isEmpty ? "Write down what you're praying for" : "\(store.prayers.filter { !$0.answered }.count) open · \(store.prayers.filter { $0.answered }.count) answered")
                                            .foregroundStyle(HS.text)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(HS.gold)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// The prayer list and the journal.
struct PrayerJournalView: View {
    @EnvironmentObject var store: AppStore
    @State var section = 0
    @State private var draft = ""

    var body: some View {
            ZStack {
                HSBackground()
                VStack(alignment: .leading, spacing: 14) {
                    Picker("", selection: $section) {
                        T("Prayer list").tag(0)
                        T("Journal").tag(1)
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        TextField(tr(section == 0 ? "Add a prayer request" : "Write a reflection"), text: $draft, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                        Button(tr("Add")) { add() }
                            .buttonStyle(.borderedProminent).tint(HS.goldButton).foregroundStyle(HS.onGold)
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    List {
                        if section == 0 {
                            ForEach($store.prayers) { $p in
                                HStack {
                                    Button { p.answered.toggle() } label: {
                                        Image(systemName: p.answered ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(p.answered ? HS.body : HS.textMuted)
                                    }
                                    .buttonStyle(.plain)
                                    Text(p.text).foregroundStyle(HS.text).strikethrough(p.answered)
                                }
                                .listRowBackground(HS.card.opacity(0.65))
                            }
                            .onDelete { store.prayers.remove(atOffsets: $0) }
                        } else {
                            ForEach(store.journal) { e in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(e.created, style: .date).font(.caption).foregroundStyle(HS.gold)
                                    Text(e.text).foregroundStyle(HS.text)
                                }
                                .listRowBackground(HS.card.opacity(0.65))
                            }
                            .onDelete { store.journal.remove(atOffsets: $0) }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
                .padding(20)
            }
            .navigationTitle(tr("Prayer list and journal"))
            .navigationBarTitleDisplayMode(.inline)
    }

    private func add() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if section == 0 { store.prayers.insert(PrayerItem(text: t), at: 0) }
        else { store.journal.insert(JournalEntry(text: t), at: 0) }
        draft = ""
    }
}
