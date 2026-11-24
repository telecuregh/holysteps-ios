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
                                Text("VERSE OF THE DAY").font(.caption.weight(.semibold)).foregroundStyle(HS.gold)
                                Text(verse.text)
                                    .font(.system(size: 20, design: .serif).italic())
                                    .foregroundStyle(HS.peach)
                                Text(verse.ref).font(.subheadline).foregroundStyle(HS.textMuted)
                                ShareLink(item: "\"\(verse.text)\" — \(verse.ref)") {
                                    Label("Share", systemImage: "square.and.arrow.up").font(.subheadline)
                                }
                                .tint(HS.goldButton)
                            }
                        }
                        GlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Reading streak").font(.subheadline).foregroundStyle(HS.textMuted)
                                    Text("\(store.readStreak) day\(store.readStreak == 1 ? "" : "s")")
                                        .font(.system(size: 26, weight: .semibold)).foregroundStyle(HS.text)
                                }
                                Spacer()
                                let done = store.readDays.contains(AppStore.dayKey())
                                Button(done ? "Read today ✓" : "I read today") {
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
                                Text("Today's prayer prompt").font(.subheadline).foregroundStyle(HS.textMuted)
                                Text(AppContent.prayerPrompts[(Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0) % AppContent.prayerPrompts.count])
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
