enum class MensPhase(
    val label: String,
    val emoji: String,
    val colorHex: String,
    val tip: String,
    /** Larger content pools — [moveIdeasToday]/[nourishTipsToday]/[mindsetTipToday]
     *  rotate a fresh daily slice so the Move/Nourish card doesn't feel static. */
    val moveIdeasPool: List<String>,
    val nourishTipsPool: List<String>,
    val mindsetTipPool: List<String>
) {
    PEAK(
        "Peak Drive", "⚡", "#10B981",
        "Push day in your week: go hard on steps, heavy workouts and your biggest tasks.",
        moveIdeasPool = listOf(
            "Heaviest lifting session of the week",
            "Push for your longest or fastest walk/run",
            "Interval training: a good day for your hardest session",
            "Tackle the physically demanding task you've been putting off",
            "A sport or activity that pushes your top-end speed",
            "Add an extra set or rep to your usual routine today",
            "Race a personal best — pace, distance, or weight"
        ),
        nourishTipsPool = listOf(
            "Protein with every meal to support harder training",
            "Don't skimp on carbs — you need the fuel for intensity",
            "Hydrate well before and after harder sessions",
            "A real breakfast today — you'll need the fuel early",
            "Electrolytes if today's session runs long or hot",
            "Don't let a big training day turn into a big skipped-meal day"
        ),
        mindsetTipPool = listOf(
            "Use this high-energy window for the task you'd normally avoid.",
            "Spend today's energy on your hardest priority, not just your busiest one.",
            "This is the day to have the conversation you've been putting off.",
            "Peak energy doesn't last — use it on purpose, not just on autopilot."
        )
    ),
    BUILD(
        "Build Mode", "💪", "#F59E0B",
        "Great energy for consistency. Build your step streak and repeat yesterday's habits.",
        moveIdeasPool = listOf(
            "Repeat a workout that worked well earlier this week",
            "Steady-pace walk or run — consistency over intensity",
            "Moderate strength session at the same weights as last time",
            "Stack one small new habit on top of an existing one",
            "A workout that's easy to repeat tomorrow, not just today",
            "Keep today's session short but don't skip it",
            "Trade intensity for consistency — show up at the same time as usual"
        ),
        nourishTipsPool = listOf(
            "Keep meals consistent and simple — repeatable beats perfect",
            "Batch-prep something today to make tomorrow easier",
            "Steady hydration through the day, not just around workouts",
            "Same meal times as yesterday — rhythm matters more than variety this phase",
            "Keep a protein source on hand for when you don't feel like cooking",
            "Don't let a busy day turn into a skipped-meal day"
        ),
        mindsetTipPool = listOf(
            "This is a maintenance phase — discipline matters more than intensity.",
            "Boring and consistent beats exciting and occasional.",
            "Repeat what worked yesterday instead of reinventing today.",
            "Small, steady reps build the week — don't overthink it."
        )
    ),
    REST(
        "Active Rest", "🌙", "#8B5CF6",
        "Recovery time. Focus on gentle walks, mobility work, and good sleep.",
        moveIdeasPool = listOf(
            "Easy walk, no pace targets",
            "Mobility work — hips, shoulders, lower back",
            "Light stretching or foam rolling before bed",
            "An extra rest day is a win today, not a loss",
            "A slow bike ride or swim instead of a hard session",
            "Gentle yoga or breathing work to wind the week down",
            "Just move enough to stay loose — nothing performance-driven"
        ),
        nourishTipsPool = listOf(
            "Prioritize sleep-supporting foods — skip heavy, late meals",
            "Protein and carbs after training help your muscles recover",
            "Ease off caffeine later in the day",
            "Hydrate well — recovery runs on water as much as rest",
            "A lighter dinner tonight if you're winding down",
            "Protein still matters on rest days — don't skip it entirely"
        ),
        mindsetTipPool = listOf(
            "Recovery is training too — protect your sleep tonight.",
            "Listen more than you speak today.",
            "A quiet night in is a legitimate plan, not a consolation prize.",
            "Give yourself permission to do less today — it's part of the plan."
        )
    ),
    RESET(
        "Reset Day", "🔄", "#F43F5E",
        "Full reset. Prioritize sleep, time with people you love, and planning the week.",
        moveIdeasPool = listOf(
            "Walk with no goal other than being outside",
            "Play — a sport or game that doesn't feel like training",
            "A full rest day if your body is asking for it",
            "Light movement with family or friends over solo training",
            "A hike or outdoor activity with no pace pressure",
            "Stretch and reset before the week ahead",
            "Whatever movement sounds fun today — let that decide it"
        ),
        nourishTipsPool = listOf(
            "Cook something you enjoy, not just something efficient",
            "Share a meal with people you care about if you can",
            "Don't overthink food today — keep it low-pressure",
            "Prep one thing today that makes Monday easier",
            "Hydrate well heading into the new week",
            "A relaxed, unhurried meal beats a rushed, perfect one"
        ),
        mindsetTipPool = listOf(
            "Plan next week's priorities today, while your mind is clear.",
            "Full rest today pays off as full energy later in the week.",
            "Reflect before you plan — what actually worked this week?",
            "Protect today's downtime; the week will ask for output again soon enough."
        )
    );

    companion object {
        fun fromDay(dayOfWeek: Int): MensPhase = when (dayOfWeek) {
            java.util.Calendar.MONDAY, java.util.Calendar.TUESDAY -> PEAK
            java.util.Calendar.WEDNESDAY, java.util.Calendar.THURSDAY -> BUILD
            java.util.Calendar.FRIDAY -> REST
            else -> RESET // SAT, SUN
        }
    }
}
fun q(s: String) = "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\""
fun arr(l: List<String>) = "[" + l.joinToString(",") { q(it) } + "]"
fun main() {
    val s = "{" + MensPhase.values().joinToString(",") { p ->
        q(p.name.lowercase()) + ":{\"move\":" + arr(p.moveIdeasPool) + ",\"nourish\":" + arr(p.nourishTipsPool) + ",\"mindset\":" + arr(p.mindsetTipPool) + "}" } + "}"
    java.io.File("mens.json").writeText(s)
}
