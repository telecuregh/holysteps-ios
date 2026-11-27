import SwiftUI

/// Android's Explainers.kt and HowItWorksScreen.kt: every feature explained in one place, with who can see what.
/// Generated from the Android text; features not on iPhone yet are left out.
struct Explainer: Identifiable { let id, emoji, title, what, why: String; let how: [String]; let privacy: String }

enum Explainers {
    static let all: [Explainer] = [
        .init(id: "cycle", emoji: "🌸", title: "Cycle tracker",
              what: "Tracks where you are in your menstrual cycle and predicts your next period.",
              why: "Your energy, mood, sleep and appetite shift through the month. Knowing the phase lets HolySteps suggest workouts, rest and devotions that fit how you probably feel.",
              how: ["Enter the first day of your last period, your cycle length and period length.", "The Home ring shows your cycle day and phase; Cycle shows what to expect next.", "Log a period start when it comes and predictions adjust."],
              privacy: "Stays on your phone. Only shared if you invite a partner (daily tips, never raw dates) or post in a circle yourself. Predictions are estimates, not contraception or medical advice."),
        .init(id: "mens_health", emoji: "💪", title: "Men's wellness",
              what: "A weekly rhythm of strength, rest and purpose for men.",
              why: "Consistency beats intensity. Each day has a focus so you always know the next right thing.",
              how: ["Check in daily to log how you feel.", "Follow the day's focus: train, recover, serve or reflect.", "Your streak and points grow as you show up."],
              privacy: "Your check-ins stay on your phone."),
        .init(id: "cycle_circles", emoji: "💗", title: "Cycle Circles",
              what: "A small, moderated support group (up to 12 people) for women to encourage each other.",
              why: "Some things are easier to share with a few trusted women than with the whole world.",
              how: ["Start a circle and share its invite code, or join with a code.", "Post encouragement or prayer requests; only circle members can read them.", "Report anything inappropriate; reported posts are reviewed and removed."],
              privacy: "Only the posts you write are shared with the circle, under your display name, or with no name if you choose. Your cycle dates are never shown."),
        .init(id: "partner_coaching", emoji: "💞", title: "Partner Coaching",
              what: "Lets your husband or partner get a short daily tip on how to support you, without seeing your data.",
              why: "Many partners want to help but don't know how. This gives them the 'what to do today' without exposing anything private.",
              how: ["Tap Invite my partner and send them the code; they enter it on their phone.", "They see a daily tip (for example 'cook dinner tonight, she may need rest'), never raw symptoms, mood or dates.", "You can pause or stop sharing at any time."],
              privacy: "Only the tip is shared, never your logs. You stay in control and can revoke access instantly."),
        .init(id: "habit_circles", emoji: "⭕", title: "Habit Circles",
              what: "A small group that does one daily habit together, like walking, praying or reading.",
              why: "People keep habits longer when others are counting on them.",
              how: ["Create a circle (or join with a code), then choose the daily habit.", "Check in each day; some habits check in automatically when you finish them.", "The calendar shows how many of you showed up. You can cheer each other on."],
              privacy: "Members see your display name and when you check in. Your streak and the days you missed are shown only to you."),
        .init(id: "family_relay", emoji: "🔥", title: "Family Faith Relay",
              what: "A household takes turns carrying one daily 'baton' of prayer or encouragement.",
              why: "It makes faith a shared family rhythm, not something each person does alone.",
              how: ["Start a relay for your household or join with an invite code.", "Each day the baton passes to the next family member.", "Pass it on after you've completed the day's moment."],
              privacy: "Only your display name and baton activity are visible to your household."),
        .init(id: "challenges", emoji: "🎯", title: "Challenges",
              what: "Set a personal goal and a pledge to hold yourself to it.",
              why: "Putting a goal in writing with something at stake makes you more likely to finish.",
              how: ["Pick a goal (like steps or prayer days) and a pledge amount.", "Track your progress inside the app.", "No real money ever moves. HolySteps does not process or hold payments."],
              privacy: "Private to you."),
        .init(id: "testimony_wall", emoji: "🕊️", title: "Testimony & Prayer Wall",
              what: "A public wall where people share what God has done and ask others to pray.",
              why: "Testimonies encourage faith, and no one should carry a burden alone.",
              how: ["Share a testimony or a prayer request.", "Tap 'praying' to let someone know you're lifting them up.", "Report anything that doesn't belong; reports are reviewed."],
              privacy: "Posts are visible to other HolySteps users. Don't include private details you wouldn't tell a stranger."),
        .init(id: "freedom", emoji: "🕊", title: "Freedom",
              what: "A private space for anyone working to break free from a habit or struggle.",
              why: "Breaking a pattern needs a plan, honest tracking and help in the moment, without shame.",
              how: ["Set your 'why' and a personal plan.", "Use the urge button when it gets hard: it walks you through getting past the moment.", "If you slip, log it honestly and restart. Progress isn't erased by one day."],
              privacy: "Everything here stays on your phone. It is never uploaded, never shown to other users, and never sent to the AI. You can lock it with Face ID or your passcode."),
        .init(id: "form_coach", emoji: "📷", title: "Form Coach",
              what: "Uses your camera to check your exercise form in real time.",
              why: "Good form prevents injury and gets more from each rep.",
              how: ["Allow the camera when asked, then prop your phone so your whole body is visible.", "Pick an exercise and start; you'll get live feedback.", "Stop any time."],
              privacy: "Analyzed on your phone only. Nothing is recorded or uploaded."),
        .init(id: "sanctuary", emoji: "🎧", title: "Audio Sanctuary",
              what: "Guided audio for prayer, rest and focus, with calming background sound.",
              why: "Quiet your mind and rest in God's presence, especially for sleep or stress.",
              how: ["Pick a session and tap play.", "It keeps playing with the screen off.", "Voice packs download once and then work offline."],
              privacy: "Plays on your device. We don't record what you listen to."),
        .init(id: "coach", emoji: "🧭", title: "Daily Coach",
              what: "One short, personal plan for today that blends movement, faith and rest.",
              why: "Instead of choosing from dozens of options, you get the next best step for your day.",
              how: ["Open it each morning for today's plan.", "Start a guided routine in one tap.", "The plan adapts as you complete things."],
              privacy: "Built from your data on your phone. Some context may be sent to our AI provider to write the text (see Privacy Policy)."),
        .init(id: "trends", emoji: "📈", title: "Life & Health Trends",
              what: "Charts of your steps, prayer, mood and rest over time.",
              why: "Patterns you can't feel day to day become clear over weeks, so you can see what helps.",
              how: ["Switch between week and month.", "Tap a metric to see how it changed.", "Use it to adjust your routine."],
              privacy: "Calculated on your phone."),
        .init(id: "rewards", emoji: "🎁", title: "Rewards & streaks",
              what: "Points, levels and streaks for the good habits you keep.",
              why: "Small wins add up. Seeing progress keeps you motivated.",
              how: ["Earn points for steps, prayer, devotionals, workouts and more.", "Level up as your points grow.", "Streak Shields protect your streak if you miss a day: one shield for each day, up to 2 days in a row."],
              privacy: "Your points stay with your account. Others only see what leagues and groups show."),
        .init(id: "journeys", emoji: "🗺️", title: "Bible Journeys",
              what: "Walk real biblical routes with your own steps, like the Road to Emmaus.",
              why: "Every walk moves you closer to the next story, so moving and Scripture go together.",
              how: ["Pick a route.", "Walk as usual. Your steps carry you along the route.", "Reach a stop to unlock its story, then read it or tap Listen."],
              privacy: "Your progress stays on your phone."),
        .init(id: "verses", emoji: "📖", title: "Verse Memory",
              what: "Spaced practice for memorizing Scripture.",
              why: "God's word is easier to recall in hard moments when it's been hidden in your heart.",
              how: ["Add or pick a verse.", "Practice with blanks and recall.", "Verses you know well appear less often."],
              privacy: "Stays on your phone."),
        .init(id: "prayer_list", emoji: "🙏", title: "Prayer List",
              what: "A private list of what you're praying for and answered prayers.",
              why: "Remembering and recording answers builds faith.",
              how: ["Add a request.", "Mark it answered and add a note.", "Pray through your list each day."],
              privacy: "Stays on your phone. Today's open requests may be sent to our AI provider if you use the personalized devotional (see Privacy Policy)."),
        .init(id: "chat", emoji: "💬", title: "Faith Companion",
              what: "An AI chat for questions about the Bible, prayer and Christian living.",
              why: "Get a thoughtful answer at any hour, in your tradition.",
              how: ["Ask a question in your own words.", "Answers are scripture-based and short.", "Free accounts have a daily allowance."],
              privacy: "Your messages and a little profile context are sent to our AI providers to produce a reply. AI can be wrong and isn't medical or pastoral advice. Don't type anything you wouldn't want sent."),
    ]
}

struct HowItWorksView: View {
    @State private var open: String?
    var body: some View {
        ZStack {
            HSBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    T("How HolySteps works").font(.hs(22)).foregroundStyle(HS.text)
                    T("Tap any feature to see what it's for and who can see what.").font(.hs(12)).foregroundStyle(HS.textMuted).padding(.bottom, 6)
                    ForEach(Explainers.all) { e in
                        Button { withAnimation { open = open == e.id ? nil : e.id } } label: {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack { D(e.emoji); T(e.title).font(.hs(15, .bold)).foregroundStyle(HS.text); Spacer()
                                        Image(systemName: open == e.id ? "chevron.up" : "chevron.down").foregroundStyle(HS.textMuted) }
                                    T(e.what).font(.hs(13)).foregroundStyle(HS.textSecondary).multilineTextAlignment(.leading)
                                    if open == e.id {
                                        T(e.why).font(.hs(13)).foregroundStyle(HS.textSecondary).multilineTextAlignment(.leading)
                                        ForEach(Array(e.how.enumerated()), id: \.offset) { i, s in
                                            D("\(i + 1). " + tr(s)).font(.hs(13)).foregroundStyle(HS.text).multilineTextAlignment(.leading)
                                        }
                                        D("🔒 " + tr(e.privacy)).font(.hs(12)).foregroundStyle(HS.textMuted).multilineTextAlignment(.leading)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }.buttonStyle(.plain)
                    }
                }.padding(20)
            }
        }
    }
}
