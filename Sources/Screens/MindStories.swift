import SwiftUI

/// Mental health stories for the Men's and Women's hubs (Resources/mind_stories.json, written by
/// tools/mind_stories.py), read by Grace through the sermon player. Her recordings are the voice packs
/// "j_<id>" on holysteps.org/voice (tools/gen_story_packs.py). Daytime listening, not sleep.
enum MindStories {
    private struct Item: Decodable { let id, hub, category, title, subtitle, script: String; let free: Bool }

    private static let items: [Item] = {
        guard let data = Bundle.main.resourceData("mind_stories.json") else { return [] }
        return (try? JSONDecoder().decode([Item].self, from: data)) ?? []
    }()
    private static let freeIds: Set<String> = Set(items.filter(\.free).map(\.id))
    private static let categories: [String: String] = Dictionary(items.map { ($0.id, $0.category) }, uniquingKeysWith: { a, _ in a })

    static let all: [Sermon] = items.map {
        Sermon(id: $0.id, group: .mind, title: $0.title, subtitle: $0.subtitle, scene: "DAWN", recorded: [], script: $0.script,
               voice: "af_heart", kind: $0.hub)
    }

    /// An everyday audio session (MensMindSession / WomenMindSession) read by Grace through the same player.
    static func session(id: String, title: String, subtitle: String, script: String, hub: String) -> Sermon {
        Sermon(id: id, group: .mind, title: title, subtitle: subtitle, scene: "DAY", recorded: [], script: script,
               voice: "af_heart", kind: hub)
    }

    /// Grace's real pace on these recordings is about 200 words a minute, plus the written pauses.
    static func minutesLabel(_ script: String) -> String {
        let secs = Sermon.parse(script).reduce(0.0) { sum, seg in
            switch seg {
            case .speech(let t): return sum + Double(t.split(whereSeparator: \.isWhitespace).count) * 60 / 200
            case .pause(let n): return sum + Double(n)
            }
        }
        return "\(max(1, Int((secs + 30) / 60))) min"
    }

    /// "men" or "women".
    static func list(_ hub: String) -> [Sermon] { all.filter { $0.kind == hub } }
    static func category(_ s: Sermon) -> String { categories[s.id] ?? "" }

    /// One story per hub is free; the rest come with that hub's plan, like the audio sessions.
    @MainActor static func locked(_ s: Sermon) -> Bool {
        guard !freeIds.contains(s.id) else { return false }
        return !AccountStore.shared.canUse(s.kind == "men" ? .mensMindAudio : .womenMindAudio)
    }
    static func isFree(_ s: Sermon) -> Bool { freeIds.contains(s.id) }
}

/// "Stories, read by Grace": one row per story, filtered by the hub's selected category.
struct MindStoriesSection: View {
    let hub: String
    let selectedCat: String
    let tint: Color
    let catEmoji: [String: String]
    @ObservedObject private var account = AccountStore.shared
    @State private var open: Sermon?
    @State private var paywall = false

    var body: some View {
        let stories = MindStories.list(hub).filter { selectedCat == "All" || MindStories.category($0) == selectedCat }
        if !stories.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    T("Bible stories, read by Grace").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    T("Stories from Scripture about what you might be going through.")
                        .font(.hs(12)).foregroundStyle(HS.textMuted)
                }
                .padding(.horizontal, 20)

                VStack(spacing: 10) {
                    ForEach(stories) { s in
                        let locked = MindStories.locked(s)
                        Button { if locked { paywall = true } else { open = s } } label: {
                            HStack(spacing: 14) {
                                T(catEmoji[MindStories.category(s)] ?? "📖").font(.system(size: 24))
                                    .frame(width: 46, height: 46)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.14)))
                                VStack(alignment: .leading, spacing: 3) {
                                    T(s.title).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                                    T(s.subtitle).font(.hs(12)).foregroundStyle(HS.textMuted).lineLimit(2)
                                    HStack(spacing: 8) {
                                        D(tr(MindStories.minutesLabel(s.script))).font(.hs(11)).foregroundStyle(HS.textSubtle)
                                        T(MindStories.category(s)).font(.hs(11, .medium)).foregroundStyle(tint)
                                        if locked {
                                            T(hub == "men" ? "Wellness plan" : "Cycle plan").font(.hs(11, .medium)).foregroundStyle(HS.textMuted)
                                        } else if MindStories.isFree(s) {
                                            T("Free").font(.hs(11, .semibold)).foregroundStyle(Color(hex: 0x10B981))
                                        }
                                    }
                                }
                                Spacer(minLength: 6)
                                Image(systemName: locked ? "lock.fill" : "play.circle")
                                    .font(.system(size: locked ? 18 : 24)).foregroundStyle(locked ? HS.textMuted : tint)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
            .fullScreenCover(item: $open) { s in SermonPlayerView(sermon: s) }
            .sheet(isPresented: $paywall) { PlansView(feature: hub == "men" ? .mensMindAudio : .womenMindAudio) }
        }
    }
}

// MARK: - Everyday mental health talks (no faith content)

/// Talks for the Men's and Women's hubs (Resources/mind_talks.json, written by tools/mind_talks.py): everyday,
/// non-faith guidance on each topic, read by Grace (voice packs "j_<id>"), each with the sources it cites.
enum MindTalks {
    struct Source: Decodable, Hashable { let title, url: String }
    private struct Item: Decodable { let id, hub, category, title, subtitle, script: String; let free: Bool; let sources: [Source] }

    private static let items: [Item] = {
        guard let data = Bundle.main.resourceData("mind_talks.json") else { return [] }
        return (try? JSONDecoder().decode([Item].self, from: data)) ?? []
    }()
    private static let byId: [String: Item] = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    static let all: [Sermon] = items.map {
        Sermon(id: $0.id, group: .mind, title: $0.title, subtitle: $0.subtitle, scene: "DAY", recorded: [], script: $0.script,
               voice: "af_heart", kind: $0.hub)
    }
    static func list(_ hub: String) -> [Sermon] { all.filter { $0.kind == hub } }
    static func category(_ s: Sermon) -> String { byId[s.id]?.category ?? "" }
    static func sources(_ s: Sermon) -> [Source] { byId[s.id]?.sources ?? [] }
    static func isFree(_ s: Sermon) -> Bool { byId[s.id]?.free ?? false }
    /// Categories in the order they first appear for this hub.
    static func categories(_ hub: String) -> [String] {
        var seen: [String] = []
        for s in list(hub) where !seen.contains(category(s)) { seen.append(category(s)) }
        return seen
    }
    /// Two talks per hub are free; the rest come with that hub's plan, like the audio sessions.
    @MainActor static func locked(_ s: Sermon) -> Bool {
        !isFree(s) && !AccountStore.shared.canUse(s.kind == "men" ? .mensMindAudio : .womenMindAudio)
    }
}

/// The hub's entry card: one tap to the full talks library, so the hub page stays short.
struct MindTalksEntryCard: View {
    let hub: String
    let tint: Color
    var body: some View {
        let count = MindTalks.list(hub).count
        if count > 0 {
            NavigationLink(destination: MindTalksView(hub: hub, tint: tint)) {
                HStack(spacing: 14) {
                    T("🎙️").font(.system(size: 26))
                        .frame(width: 50, height: 50)
                        .background(RoundedRectangle(cornerRadius: 14).fill(tint.opacity(0.16)))
                    VStack(alignment: .leading, spacing: 3) {
                        T("Mental health talks").font(.hs(16, .semibold)).foregroundStyle(HS.text)
                        D(tr("\(count) talks, read by Grace. Real research, no faith content.")).font(.hs(12)).foregroundStyle(HS.textMuted)
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right").foregroundStyle(HS.textMuted)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(HS.cardFill))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
    }
}

struct MindTalksView: View {
    let hub: String
    let tint: Color
    @ObservedObject private var account = AccountStore.shared
    @State private var selected = "All"
    @State private var open: Sermon?
    @State private var paywall = false
    @State private var showSources: Sermon?

    var body: some View {
        let cats = ["All"] + MindTalks.categories(hub)
        let talks = MindTalks.list(hub).filter { selected == "All" || MindTalks.category($0) == selected }
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        T("Mental health talks").font(.hs(26, .bold)).foregroundStyle(HS.text)
                        T(hub == "men"
                          ? "Straight talk on what men go through, read by Grace. Every fact comes from a named source."
                          : "Honest talk on what women go through, read by Grace. Every fact comes from a named source.")
                            .font(.hs(13)).foregroundStyle(HS.textMuted).fixedSize(horizontal: false, vertical: true)
                        T("Not medical advice. In a crisis, call or text 988.").font(.hs(11)).foregroundStyle(HS.textSubtle)
                    }
                    .padding(.horizontal, 20).padding(.top, 58).padding(.bottom, 12)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(cats, id: \.self) { c in
                                Button(c) { selected = c }
                                    .font(.hs(13, .medium))
                                    .foregroundStyle(selected == c ? .white : HS.textMuted)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(Capsule().fill(selected == c ? tint : HS.cardFill))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 14)

                    VStack(spacing: 10) {
                        ForEach(talks) { s in talkRow(s) }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 100)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
        .fullScreenCover(item: $open) { s in SermonPlayerView(sermon: s) }
        .sheet(isPresented: $paywall) { PlansView(feature: hub == "men" ? .mensMindAudio : .womenMindAudio) }
        .sheet(item: $showSources) { s in MindTalkSourcesSheet(talk: s) }
    }

    private func talkRow(_ s: Sermon) -> some View {
        let locked = MindTalks.locked(s)
        return VStack(alignment: .leading, spacing: 8) {
            Button { if locked { paywall = true } else { open = s } } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        T(s.title).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                        T(s.subtitle).font(.hs(12)).foregroundStyle(HS.textMuted).lineLimit(2)
                        HStack(spacing: 8) {
                            D(tr(MindStories.minutesLabel(s.script))).font(.hs(11)).foregroundStyle(HS.textSubtle)
                            T(MindTalks.category(s)).font(.hs(11, .medium)).foregroundStyle(tint)
                            if locked {
                                T(hub == "men" ? "Wellness plan" : "Cycle plan").font(.hs(11, .medium)).foregroundStyle(HS.textMuted)
                            } else if MindTalks.isFree(s) {
                                T("Free").font(.hs(11, .semibold)).foregroundStyle(Color(hex: 0x10B981))
                            }
                        }
                    }
                    Spacer(minLength: 6)
                    Image(systemName: locked ? "lock.fill" : "play.circle")
                        .font(.system(size: locked ? 18 : 26)).foregroundStyle(locked ? HS.textMuted : tint)
                }
            }
            .buttonStyle(.plain)
            Button { showSources = s } label: {
                Label(tr("Sources"), systemImage: "doc.text.magnifyingglass").font(.hs(11, .medium)).foregroundStyle(HS.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
    }
}

/// The studies and agencies a talk cites, each opening in the browser.
private struct MindTalkSourcesSheet: View {
    let talk: Sermon
    var body: some View {
        HSSheet(title: "Sources") {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    T(talk.title).font(.hs(16, .semibold)).foregroundStyle(HS.text)
                    ForEach(MindTalks.sources(talk), id: \.self) { src in
                        if let u = URL(string: src.url) {
                            Link(destination: u) {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "arrow.up.right.square").foregroundStyle(HS.peach)
                                    D(src.title).font(.hs(13)).foregroundStyle(HS.text).multilineTextAlignment(.leading)
                                }
                            }
                        }
                    }
                    T("These talks share general information, not medical advice. Talk to your doctor about your own care.")
                        .font(.hs(11)).foregroundStyle(HS.textSubtle).padding(.top, 8)
                }
                .padding(20)
            }
        }
    }
}
