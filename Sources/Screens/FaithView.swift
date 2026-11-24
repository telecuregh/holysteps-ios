import SwiftUI

struct FaithView: View {
    @EnvironmentObject var store: AppStore
    @State private var section = 0
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            ZStack {
                HSBackground()
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle(text: "Faith")
                    BibleHomeCard()
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
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func add() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if section == 0 { store.prayers.insert(PrayerItem(text: t), at: 0) }
        else { store.journal.insert(JournalEntry(text: t), at: 0) }
        draft = ""
    }
}
