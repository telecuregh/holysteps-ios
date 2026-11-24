import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @State private var markedRead = false

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening")
        return store.name.isEmpty ? part : "\(part), \(store.name)"
    }

    var body: some View {
        let verse = AppContent.verseOfTheDay()
        NavigationStack {
            ZStack {
                HSBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ScreenTitle(text: greeting)
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                T("VERSE OF THE DAY").font(.caption.weight(.semibold)).foregroundStyle(HS.gold)
                                Text(verbatim: verse.shown)
                                    .font(.system(size: 20, design: .serif).italic())
                                    .foregroundStyle(HS.peach)
                                T(verse.ref).font(.subheadline).foregroundStyle(HS.textMuted)
                                ShareLink(item: "\"\(verse.shown)\" — \(tr(verse.ref))") {
                                    Label(tr("Share"), systemImage: "square.and.arrow.up").font(.subheadline)
                                }
                                .tint(HS.goldButton)
                            }
                        }
                        GlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    T("Reading streak").font(.subheadline).foregroundStyle(HS.textMuted)
                                    T(store.readStreak == 1 ? "1 day" : "\(store.readStreak) days")
                                        .font(.system(size: 26, weight: .semibold)).foregroundStyle(HS.text)
                                }
                                Spacer()
                                let done = store.readDays.contains(AppStore.dayKey())
                                Button(tr(done ? "Read today ✓" : "I read today")) {
                                    store.readDays.insert(AppStore.dayKey())
                                }
                                .disabled(done)
                                .buttonStyle(.borderedProminent)
                                .tint(HS.goldButton)
                                .foregroundStyle(HS.onGold)
                            }
                        }
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                T("Today's prayer prompt").font(.subheadline).foregroundStyle(HS.textMuted)
                                T(AppContent.prayerPrompts[(Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0) % AppContent.prayerPrompts.count])
                                    .foregroundStyle(HS.text)
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
