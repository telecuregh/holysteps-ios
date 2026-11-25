import SwiftUI

/// Android's Verse Memory (SignatureScreens.kt VerseMemoryScreen, AppState MEMORY_VERSES): four rounds that hide
/// more words each time; the premium verses come with the Faith plan.
struct MemoryVerse: Decodable, Identifiable { let id, ref, text: String; let premium: Bool }

enum VerseMemory {
    static let all: [MemoryVerse] = {
        guard let u = Bundle.main.url(forResource: "memory_verses", withExtension: "json"), let d = try? Data(contentsOf: u) else { return [] }
        return (try? JSONDecoder().decode([MemoryVerse].self, from: d)) ?? []
    }()
    static var mastered: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "memorizedVerses") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "memorizedVerses") }
    }
}

struct VerseMemoryView: View {
    @ObservedObject private var account = AccountStore.shared
    @State private var practicing: MemoryVerse?
    @State private var mastered = VerseMemory.mastered
    @State private var paywall = false

    var body: some View {
        let total = max(1, VerseMemory.all.count)
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    T("🧠 Verse Memory").font(.hs(13, .bold)).foregroundStyle(HS.gold)
                    T("Hide His Word in your heart").font(.hs(22, .bold)).foregroundStyle(HS.text)
                    T("Psalm 119:11").font(.hs(12)).foregroundStyle(HS.textMuted)
                    D(tr("\(mastered.count) of \(VerseMemory.all.count) mastered")).font(.hs(13, .semibold)).foregroundStyle(HS.gold).padding(.top, 8)
                    ProgressView(value: Double(mastered.count), total: Double(total)).tint(HS.goldButton)
                    ForEach(VerseMemory.all) { v in
                        let done = mastered.contains(v.id)
                        let locked = v.premium && !account.canUse(.versesPremium)
                        Button { if locked { paywall = true } else { practicing = v } } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    D(v.ref).font(.hs(14, .bold)).foregroundStyle(HS.text)
                                    D(locked ? tr("Premium verse") : v.text).font(.hs(12)).foregroundStyle(HS.textMuted).lineLimit(2)
                                }
                                Spacer(minLength: 6)
                                D(done ? "✓" : locked ? "👑" : tr("Practice")).font(.hs(13, .bold)).foregroundStyle(done || locked ? HS.gold : HS.faith)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(done ? HS.gold.opacity(0.1) : HS.cardFill))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(done ? HS.gold.opacity(0.5) : HS.overlay(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20).padding(.bottom, 60)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $practicing) { v in
            PracticeSheet(verse: v) {
                if !mastered.contains(v.id) { Points.award(30) }
                mastered.insert(v.id); VerseMemory.mastered = mastered
            }
        }
        .sheet(isPresented: $paywall) { PlansView(feature: .versesPremium) }
    }
}

private struct PracticeSheet: View {
    let verse: MemoryVerse
    let onMastered: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var round = 0
    @State private var revealed = false

    var body: some View {
        let words = verse.text.split(separator: " ").map(String.init)
        let every = [0, 3, 2, 1][round]
        let shown = words.enumerated().map { i, w in revealed || every == 0 || i % every != 0 ? w : String(repeating: "_", count: min(8, max(2, w.count))) }.joined(separator: " ")
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                T(["Read it slowly, out loud.", "Fill in the missing words.", "Half the words are gone.", "Say the whole verse from memory."][round]).font(.hs(12)).foregroundStyle(HS.textMuted)
                D(shown).font(.hs(19)).foregroundStyle(HS.text)
                if round > 0 && !revealed { Button { revealed = true } label: { T("Reveal answer").font(.hs(14, .semibold)).foregroundStyle(HS.faith) } }
                HStack(spacing: 6) { ForEach(0..<4, id: \.self) { i in Capsule().fill(i <= round ? HS.goldButton : HS.overlay(0.1)).frame(height: 5) } }
                Spacer()
                if round < 3 { GoldButton(title: "Next round →") { round += 1; revealed = false } }
                else { GoldButton(title: "I know it! · +30") { onMastered(); dismiss() } }
            }
            .padding(20)
            .background(HSBackground())
            .navigationTitle(verse.ref).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Close")) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
