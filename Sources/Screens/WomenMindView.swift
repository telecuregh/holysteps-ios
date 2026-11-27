import SwiftUI

// MARK: - Women's Mental Health data

struct WomenMindSession: Identifiable {
    let id: String
    let title: String
    let category: String   // Anxiety | PMS/PMDD | Postpartum | Grief | Self-Worth | Burnout
    let durationSeconds: Int
    let blurb: String
    let script: String

    /// How long Grace's reading actually runs.
    var durationLabel: String { MindStories.minutesLabel(script) }
}

let womenMindSessions: [WomenMindSession] = [
    WomenMindSession(
        id: "women_emotions_valid",
        title: "Your Emotions Are Valid",
        category: "Anxiety",
        durationSeconds: 420,
        blurb: "You were not built to feel less. Here's permission to feel it all.",
        script: """
If anyone has told you that you're too emotional — too sensitive, too much, too intense — this is for you.

Your emotional depth is not a flaw. It is how you were wired. The ability to feel deeply, to pick up on what others miss, to care with your whole self — that is not weakness. That is design.

Take a slow breath.

The world will sometimes ask you to manage yourself down. To be more professional, more composed, more measured. And there is wisdom in knowing when and how to express what you feel. But there is a difference between wisdom and suppression — and so many women have been taught to suppress without anyone calling it what it is.

What are you feeling right now? Not what you should feel, not what would look acceptable — what are you actually feeling?

Name it. Even to yourself.

Whatever it is — frustration, grief, loneliness, overwhelm, joy, longing — it is valid. It does not need to be explained or apologized for. It needs to be acknowledged.

Your inner life is real, and it makes sense. You are not too much. You do not need to simplify yourself to be acceptable. The whole of you is welcome here.

Where you are in your feelings right now is okay. Your feelings are information, not a problem to hide.

Breathe. You are allowed to feel.
"""
    ),
    WomenMindSession(
        id: "women_pms_wave",
        title: "Before Your Period",
        category: "PMS/PMDD",
        durationSeconds: 460,
        blurb: "The luteal phase is real. What to do when the wave hits.",
        script: """
If you're in the week before your period — the days when everything feels heavier, sharper, harder — this session was made for this exact moment.

What you're experiencing is real. The drop in estrogen and progesterone in the late luteal phase changes brain chemistry. The irritability, the sadness, the feeling that everything is wrong and you can't quite name why — that is not in your head. It is in your biology.

Take a slow breath.

This wave has a name. It has a timeline. It has an end.

You have survived every hard week before this one. You will survive this one too.

Right now, what does your body need most? Rest? To move? Warmth? Quiet? One honest conversation? Permission to feel what you feel without explaining it?

Give yourself that — not as a luxury, but as medicine.

If the pain of this week is severe — if it derails your life month after month — that is not something to manage in silence. PMDD is real. Treatment exists. You deserve support beyond just pushing through.

For today: be gentle. Reduce what you can reduce. Say no to what you can say no to. And if someone in your life does not understand what this week is like for you — that is a conversation worth having in a better week, so they can support you in this one.

You are not broken. You are cyclical. And cycles move.

Breathe. This will pass.
"""
    ),
    WomenMindSession(
        id: "women_postpartum_truth",
        title: "After the Baby",
        category: "Postpartum",
        durationSeconds: 540,
        blurb: "Postpartum anxiety and depression are common. You are not a bad mother.",
        script: """
If you have recently had a baby, or if you're in the postpartum season — whether that was months ago or years ago — and something has felt off in a way you haven't been able to name, this is for you.

Postpartum depression and anxiety are not rare. They are not signs of bad motherhood. They are not what you signed up for and also they are real and common and treatable, and nobody talks about them enough.

Breathe slowly.

If you've felt disconnected from your baby — or from yourself. If you've had intrusive thoughts that terrify you. If the joy everyone told you you'd feel hasn't come in the way you expected. If you feel exhausted in a way that sleep doesn't fix. If you've wondered if everyone would be better off without you — please hear me: you are not alone, and what you're experiencing has a name and help available.

You are not a bad mother for struggling. The fact that you care about struggling already tells you who you are.

Postpartum can look like sadness. It can also look like rage, numbness, constant anxiety, fear, or a detachment you can't explain. Any of these things, persisting for more than two weeks, is worth bringing to a doctor.

You are worth getting help for. Not just for your baby. For you.

If you have a partner, a family member, a midwife, an OB — tell them one true thing today. Even just: "I haven't been okay."

That one sentence opens the door.

Breathe. You are doing something hard and important. And you deserve support through it.
"""
    ),
    WomenMindSession(
        id: "women_carrying_everyone",
        title: "Carrying Everyone",
        category: "Burnout",
        durationSeconds: 500,
        blurb: "The invisible labor of holding a family together — and what it costs.",
        script: """
You make sure everyone has what they need. You remember the appointments, the allergies, the forms, the feelings. You carry the emotional weather of the whole household. You are the one who notices when something is wrong before anyone else does.

And nobody sees it. Because it's invisible. Because it's expected.

Take a breath.

The mental and emotional load that falls disproportionately on women in families and relationships is real. It is documented, named, and deeply exhausting in a way that is hard to explain to someone who doesn't carry it.

You are not complaining if you say it's too much. You are telling the truth.

What would it mean to put something down? Not forever. Just today. One thing that someone else could carry, even imperfectly. What if imperfect was enough for today?

You cannot pour from empty. And you have been pouring. When did someone last ask how you were and actually wait for the answer?

You need care too. Not as a reward for doing enough. As a human being who has needs, feelings, and limits — just like everyone you take care of.

What is one thing you can receive today? Not do — receive. Help, rest, a meal, a conversation, an hour to yourself.

Ask for it. Not later. This week.

You have permission to need things.

Breathe.
"""
    ),
    WomenMindSession(
        id: "women_grief_quiet",
        title: "The Quiet Grief",
        category: "Grief",
        durationSeconds: 480,
        blurb: "Pregnancy loss, infertility, the grief that often goes unwitnessed.",
        script: """
If you have lost a pregnancy — an early loss, a later one, a baby who didn't come home — this session is a space to hold what may not have been held enough.

If you have been trying to conceive and the months have turned into years, and hope has started to feel complicated — this is for you.

If there is a loss in your life that others moved past before you were ready, that didn't get the ceremony it deserved, that you still carry in a quiet place — this is for you.

Take a breath.

Grief that is not witnessed does not stop being grief. It just becomes a private weight. And some women carry this for years — across pregnancies, across holidays, across the babies of friends and family — and smile through it because there is no other option available.

You are allowed to mourn what you lost. You are allowed to name the child, the dream, the version of your life that did not come. You are allowed to be sad still, even if no one else remembers.

Grief does not come with a time limit. It does not expire when others think you should be over it.

Is there something — or someone — that you haven't allowed yourself to fully grieve? Something that needed more space than it got?

You can give it space now. You don't need a reason. You don't need an anniversary. You just need to say: this mattered. I miss this. I am still sad.

Say it. Even quietly.

You are not alone in this room.

Breathe.
"""
    ),
    WomenMindSession(
        id: "women_hormonal_anxiety",
        title: "Hormonal Anxiety Is Real",
        category: "Anxiety",
        durationSeconds: 440,
        blurb: "Estrogen, progesterone, cortisol — anxiety has a biology. Here's what to do.",
        script: """
If your anxiety spikes at specific times — before your period, around ovulation, postpartum, or during perimenopause — you are not imagining it.

Hormones directly affect the brain's anxiety and stress response systems. Estrogen modulates serotonin. Progesterone affects GABA — the calming neurotransmitter. Cortisol rises when hormones shift. The anxiety that arrives like a wave at predictable times in your cycle is not emotional instability. It is biology.

Take a slow breath.

Understanding this matters because when you know the pattern, you can prepare. You can track it. You can adjust what you do in that window — reduce caffeine, increase sleep, move your body differently, ask for more support, cancel what you can cancel.

You are not fragile. You are variable — which is completely different. All humans are variable. Women's variability has been pathologized for centuries. That does not make it a flaw.

Right now, in this moment: your nervous system is activated. That is what anxiety is. Your body thinks there is a threat.

There is no threat right now. You are safe.

Five slow breaths, counting each one. In through the nose. Out through the mouth.

One. You are safe.
Two. This is temporary.
Three. Your body is trying to protect you.
Four. You can help it settle.
Five. You are okay.

If this pattern is severe and recurring, a doctor who understands hormonal health can help. This is a physical thing — not a character thing.

Breathe. You are okay.
"""
    ),
    WomenMindSession(
        id: "women_body_peace",
        title: "The Body You Live In",
        category: "Self-Worth",
        durationSeconds: 460,
        blurb: "Your body has carried you through everything. What if you let it be enough?",
        script: """
If you have ever looked in the mirror and catalogued what was wrong — if the relationship between you and your body has been characterized more by criticism than by gratitude — this is for you.

Take a breath.

Your body has carried you here. Through every hard year. Through every loss and every joy. Through illness and recovery. Through growing up, through change, through things you didn't choose. It showed up — imperfectly, and completely.

The world has opinions about women's bodies. It has been having them for a very long time. And somewhere along the way, many of us internalized those opinions as our own. The number on a scale became a verdict. The size of clothing became a statement about worth.

It is not.

Your body is not a project to finish before you're allowed to live. The body you are in — with its stretch marks and its softness and its scars and its wrinkles and its strength — is worthy of care right now. There is no asterisk.

What would it mean to be at peace with the body you have today? Not to have fixed it first. Not to reach a goal and then allow peace. Peace today, in this body, as it is.

That is not resignation. That is kindness.

What is one thing your body did today that you could thank it for? Even something small. That it breathed. That it moved. That it held you together.

Say thank you. And mean it.

Breathe. You are not a project to be finished. You are a person.
"""
    ),
    WomenMindSession(
        id: "women_worth_knowing",
        title: "Worth More Than You Know",
        category: "Self-Worth",
        durationSeconds: 420,
        blurb: "When you've forgotten who you are outside of what you do for others.",
        script: """
If you've spent so long being what everyone else needs that you've lost track of who you are on your own — this is for you.

When did you last do something purely for yourself? Not to be a better mother, partner, or employee — just for you? When did you last have a full thought that wasn't about someone else?

Take a breath.

There is a version of selflessness that is beautiful. And then there is a version that becomes self-erasure — where you give so completely that you disappear inside the giving.

You are not meant to disappear.

You have a name. Needs. Preferences. Things that bring you alive. Things that only you notice. A sense of humor, a dream, a fear, a past, a future. These things are not extras to get to when everyone else is taken care of. They are you. And you matter.

You are not a better person the more invisible you are. You are not more worthy the more you suppress yourself.

Who were you before you became what everyone needed you to be? What did you love? What did you want? What made you laugh?

Those things did not go away. They waited.

You are worth knowing. Not as someone's mother, someone's partner, someone's employee — as yourself. A whole and interesting person with an interior life that matters.

What is one thing that is true about you that has nothing to do with what you do for others?

Say it. And remember it.

Breathe. You are still there.
"""
    ),
]

// MARK: - Screen

struct WomenMindView: View {
    @ObservedObject private var account = AccountStore.shared
    /// The session Grace is reading now (played through the sermon player, like the stories).
    @State private var listen: Sermon?
    @State private var played: Set<String> = {
        Set(UserDefaults.standard.stringArray(forKey: "womenMindPlayed") ?? [])
    }()
    @State private var selectedCat = "All"
    @State private var showPaywall = false

    /// First two sessions of the master list are always free.
    private func isLocked(_ s: WomenMindSession) -> Bool {
        guard let i = womenMindSessions.firstIndex(where: { $0.id == s.id }) else { return false }
        return i >= 2 && !account.canUse(.womenMindAudio)
    }

    private let cats = ["All", "Anxiety", "PMS/PMDD", "Postpartum", "Grief", "Self-Worth", "Burnout"]
    private var filtered: [WomenMindSession] {
        selectedCat == "All" ? womenMindSessions : womenMindSessions.filter { $0.category == selectedCat }
    }
    private let catColors: [String: Color] = [
        "Anxiety":    Color(hex: 0x0EA5E9),
        "PMS/PMDD":   Color(hex: 0xA78BFA),
        "Postpartum": Color(hex: 0xF472B6),
        "Grief":      Color(hex: 0x64748B),
        "Self-Worth": Color(hex: 0xF59E0B),
        "Burnout":    Color(hex: 0xF43F5E),
    ]
    private let catEmoji: [String: String] = [
        "Anxiety":    "🌊",
        "PMS/PMDD":   "🌙",
        "Postpartum": "🤱",
        "Grief":      "🕊️",
        "Self-Worth": "✨",
        "Burnout":    "🔥",
    ]

    var body: some View {
        ZStack {
            HSBackground()
            listBody
        }
        .toolbar(.hidden, for: .navigationBar)
        .hsBackButton()
        .fullScreenCover(item: $listen) { s in SermonPlayerView(sermon: s) }
        .sheet(isPresented: $showPaywall) { PlansView(feature: .womenMindAudio) }
    }

    private func play(_ s: WomenMindSession) {
        if !played.contains(s.id) { EngagementStore.shared.recordAudioPlay() }
        played.insert(s.id)
        UserDefaults.standard.set(Array(played), forKey: "womenMindPlayed")
        listen = MindStories.session(id: s.id, title: s.title, subtitle: s.blurb, script: s.script, hub: "women")
    }

    private var listBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        T("💜").font(.system(size: 28))
                        T("Women's Mental Health").font(.hs(24, .bold)).foregroundStyle(HS.text)
                    }
                    T("Spoken guidance for anxiety, PMS/PMDD, postpartum, grief, burnout, and self-worth.\nMade for what women actually go through.")
                        .font(.hs(13)).foregroundStyle(HS.textMuted).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 58).padding(.bottom, 8)

                // Stats bar
                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        T("\(played.count)").font(.hs(22, .bold)).foregroundStyle(Color(hex: 0xF472B6))
                        T("listened").font(.hs(11)).foregroundStyle(HS.textMuted)
                    }
                    Rectangle().frame(width: 1, height: 32).foregroundStyle(HS.overlay(0.1))
                    VStack(spacing: 2) {
                        T("\(womenMindSessions.count)").font(.hs(22, .bold)).foregroundStyle(HS.text)
                        T("sessions").font(.hs(11)).foregroundStyle(HS.textMuted)
                    }
                    Spacer()
                    T("Private · On-device").font(.hs(11)).foregroundStyle(HS.textMuted)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(HS.overlay(0.07)))
                }
                .padding(.horizontal, 20).padding(.vertical, 12)

                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(cats, id: \.self) { cat in
                            Button(cat) { selectedCat = cat }
                                .font(.hs(13, .medium))
                                .foregroundStyle(selectedCat == cat ? .white : HS.textMuted)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Capsule().fill(
                                    selectedCat == cat
                                        ? (catColors[cat] ?? Color(hex: 0xF472B6))
                                        : HS.cardFill
                                ))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)

                MindTalksEntryCard(hub: "women", tint: Color(hex: 0xF472B6))

                // Session list: everyday guidance, no faith content (the Bible stories sit below).
                VStack(alignment: .leading, spacing: 2) {
                    T("Everyday sessions, read by Grace").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                    T("Practical guidance with no faith content.").font(.hs(12)).foregroundStyle(HS.textMuted)
                }
                .padding(.horizontal, 20).padding(.bottom, 10)

                // Session list
                VStack(spacing: 10) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, session in
                        WomenMindCard(
                            session: session,
                            isPlayed: played.contains(session.id),
                            catColor: catColors[session.category] ?? Color(hex: 0xF472B6),
                            catEmoji: catEmoji[session.category] ?? "💜",
                            isFeatured: idx == 0 && selectedCat == "All",
                            isLocked: isLocked(session),
                            onTap: { if isLocked(session) { showPaywall = true } else { play(session) } }
                        )
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)

                MindStoriesSection(hub: "women", selectedCat: selectedCat, tint: Color(hex: 0xF472B6), catEmoji: catEmoji)

                // Separator
                Rectangle().frame(height: 1).foregroundStyle(HS.overlay(0.08))
                    .padding(.horizontal, 20).padding(.vertical, 8)

                // Tools section
                VStack(alignment: .leading, spacing: 10) {
                    T("Assessment Tools").font(.hs(15, .semibold)).foregroundStyle(HS.text)
                        .padding(.horizontal, 20)
                    T("Track how you're doing over time.")
                        .font(.hs(12)).foregroundStyle(HS.textMuted)
                        .padding(.horizontal, 20)

                    NavigationLink(destination: CycleMoodTestsView()) {
                        WomenMindToolRow(emoji: "🌸", title: "Mood & tests", sub: "Daily mood scale and pregnancy-test log", color: Color(hex: 0xF472B6))
                    }
                    NavigationLink(destination: SeverityView()) {
                        WomenMindToolRow(emoji: "📈", title: "Symptom severity", sub: "Rate pain and mood daily — PMS, PMDD, PCOS, endo", color: Color(hex: 0xA78BFA))
                    }
                    NavigationLink(destination: PostpartumView()) {
                        WomenMindToolRow(emoji: "🤱", title: "Postpartum check-in", sub: "EPDS screening and postpartum support", color: Color(hex: 0xF472B6))
                    }
                    NavigationLink(destination: HeadacheView()) {
                        WomenMindToolRow(emoji: "🤕", title: "Headache diary", sub: "Log menstrual migraines and find patterns", color: Color(hex: 0x0EA5E9))
                    }
                }
                .padding(.bottom, 100)
            }
        }
    }
}

// MARK: - Featured / regular card

private struct WomenMindCard: View {
    let session: WomenMindSession
    let isPlayed: Bool
    let catColor: Color
    let catEmoji: String
    let isFeatured: Bool
    var isLocked: Bool = false
    var isFreeTag: Bool { womenMindSessions.prefix(2).contains { $0.id == session.id } }
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            if isFeatured {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 18).fill(
                        LinearGradient(colors: [catColor.opacity(0.9), catColor.opacity(0.4)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            T("Featured").font(.hs(11, .semibold)).foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Capsule().fill(.white.opacity(0.2)))
                            Spacer()
                            if isPlayed {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.white).font(.system(size: 18))
                            }
                        }
                        Spacer()
                        T(catEmoji).font(.system(size: 40))
                        T(session.title).font(.hs(22, .bold)).foregroundStyle(.white)
                        T(session.blurb).font(.hs(13)).foregroundStyle(.white.opacity(0.85))
                        HStack(spacing: 10) {
                            Label(session.durationLabel, systemImage: "headphones")
                                .font(.hs(12, .medium)).foregroundStyle(.white.opacity(0.9))
                            T("·").foregroundStyle(.white.opacity(0.5))
                            T(session.category).font(.hs(12)).foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Image(systemName: isLocked ? "lock.circle.fill" : "play.circle.fill").font(.system(size: 32)).foregroundStyle(.white)
                        }
                    }
                    .padding(18)
                }
                .frame(height: 220)
            } else {
                HStack(spacing: 14) {
                    T(catEmoji).font(.system(size: 26))
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(catColor.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            T(session.title).font(.hs(15, .semibold)).foregroundStyle(HS.text)
                            Spacer()
                            if isPlayed {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(catColor).font(.system(size: 15))
                            }
                        }
                        T(session.blurb).font(.hs(12)).foregroundStyle(HS.textMuted).lineLimit(2)
                        HStack(spacing: 8) {
                            Label(session.durationLabel, systemImage: "headphones")
                                .font(.hs(11)).foregroundStyle(HS.textMuted)
                            T(session.category).font(.hs(11, .medium)).foregroundStyle(catColor)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Capsule().fill(catColor.opacity(0.12)))
                            if isLocked {
                                T("Cycle plan").font(.hs(11, .medium)).foregroundStyle(HS.textMuted)
                            } else if !isPlayed && isFreeTag {
                                T("Free").font(.hs(11, .semibold)).foregroundStyle(Color(hex: 0x10B981))
                            }
                        }
                    }
                    Image(systemName: isLocked ? "lock.fill" : "play.circle").font(.system(size: isLocked ? 18 : 24)).foregroundStyle(isLocked ? HS.textMuted : catColor)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tool row

private struct WomenMindToolRow: View {
    let emoji: String; let title: String; let sub: String; let color: Color
    var body: some View {
        HStack(spacing: 14) {
            T(emoji).font(.system(size: 22))
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.13)))
            VStack(alignment: .leading, spacing: 2) {
                T(title).font(.hs(14, .semibold)).foregroundStyle(HS.text)
                T(sub).font(.hs(12)).foregroundStyle(HS.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(HS.textMuted)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 13).fill(HS.cardFill))
        .padding(.horizontal, 20)
    }
}

// MARK: - Player

private struct WomenMindPlayerView: View {
    let session: WomenMindSession
    let isPlayed: Bool
    let onComplete: () -> Void
    let onClose: () -> Void

    @State private var progress: Double = 0
    @State private var playing = false
    @State private var elapsed = 0
    @State private var timer: Timer?
    @State private var marked = false

    var body: some View {
        ZStack {
            HSBackground()
            VStack(spacing: 0) {
                HStack {
                    Button(action: { timer?.invalidate(); onClose() }) {
                        Image(systemName: "xmark").font(.system(size: 17, weight: .medium))
                            .foregroundStyle(HS.text).padding(10)
                            .background(Circle().fill(HS.cardFill))
                    }
                    Spacer()
                    T(session.category).font(.hs(13, .medium)).foregroundStyle(HS.textMuted)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(HS.cardFill))
                }
                .padding(.horizontal, 20).padding(.top, 54)

                ScrollView {
                    VStack(spacing: 24) {
                        T("💜").font(.system(size: 72)).padding(.top, 24)

                        VStack(spacing: 6) {
                            T(session.title).font(.hs(24, .bold)).foregroundStyle(HS.text).multilineTextAlignment(.center)
                            T(session.durationLabel).font(.hs(13)).foregroundStyle(HS.textMuted)
                        }

                        VStack(spacing: 8) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(HS.overlay(0.1)).frame(height: 6)
                                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0xF472B6))
                                        .frame(width: geo.size.width * progress, height: 6)
                                }
                            }
                            .frame(height: 6)
                            HStack {
                                T(timeLabel(elapsed)).font(.hs(11)).foregroundStyle(HS.textMuted)
                                Spacer()
                                T(session.durationLabel).font(.hs(11)).foregroundStyle(HS.textMuted)
                            }
                        }
                        .padding(.horizontal, 20)

                        Button(action: togglePlay) {
                            Image(systemName: playing ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 72))
                                .foregroundStyle(Color(hex: 0xF472B6))
                        }

                        if isPlayed || marked {
                            Label("Session complete", systemImage: "checkmark.circle.fill")
                                .font(.hs(13, .medium)).foregroundStyle(Color(hex: 0x10B981))
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            T("Session transcript").font(.hs(13, .semibold)).foregroundStyle(HS.textMuted)
                                .padding(.bottom, 10)
                            T(session.script).font(.hs(14)).foregroundStyle(HS.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(HS.cardFill))
                        .padding(.horizontal, 20)

                        Spacer().frame(height: 60)
                    }
                }
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    private func timeLabel(_ s: Int) -> String {
        "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    private func togglePlay() {
        playing.toggle()
        if playing {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                guard elapsed < session.durationSeconds else {
                    timer?.invalidate(); playing = false
                    if !marked { marked = true; onComplete() }
                    return
                }
                elapsed += 1
                progress = Double(elapsed) / Double(session.durationSeconds)
            }
        } else {
            timer?.invalidate()
        }
    }
}
