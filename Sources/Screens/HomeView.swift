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
                                T("VERSE OF THE DAY").font(.hs(11, .semibold)).tracking(1.4).foregroundStyle(HS.peach)
                                D(verse.shown)
                                    .font(.accent(20))
                                    .foregroundStyle(HS.peach)
                                T(verse.ref).font(.hs(14)).foregroundStyle(HS.textMuted)
                                ShareLink(item: "\"\(verse.shown)\" — \(tr(verse.ref))") {
                                    Label(tr("Share"), systemImage: "square.and.arrow.up").font(.hs(14))
                                }
                                .tint(HS.goldButton)
                            }
                        }
                        GlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    T("Reading streak").font(.hs(14)).foregroundStyle(HS.textMuted)
                                    T(store.readStreak == 1 ? "1 day" : "\(store.readStreak) days")
                                        .font(.hs(26, .semibold)).foregroundStyle(HS.text)
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
                                T("Today's prayer prompt").font(.hs(14)).foregroundStyle(HS.textMuted)
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
