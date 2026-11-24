enum class EnergyZone(val label: String, val emoji: String, val colorHex: String, val rank: Int, val headline: String) {
    RECOVER("Rest & restore", "🛌", "#EC4899", 0, "Today is for recovery — rest is part of the plan, not a break from it."),
    LOW("Gentle day", "🌙", "#8B5CF6", 1, "Go gentle today — restorative movement and grounding Scripture."),
    STEADY("Steady day", "🌤️", "#3B82F6", 2, "A steady day — consistent, moderate effort is the win."),
    HIGH("High-energy day", "⚡", "#10B981", 3, "High-energy day — go bold in body and in faith.");

    /** The headline for the user's content mode (Wellness has no Scripture or faith wording). */
    fun headlineFor(faith: Boolean): String = if (faith) headline else when (this) {
        LOW -> "Go gentle today — restorative movement and calming breath."
        HIGH -> "High-energy day — go bold with your body and your goals."
        else -> headline
    }

    fun down(): EnergyZone = values().firstOrNull { it.rank == rank - 1 } ?: this
    fun up(): EnergyZone = values().firstOrNull { it.rank == rank + 1 } ?: this

    companion object {
        fun minOf(a: EnergyZone, b: EnergyZone): EnergyZone = if (a.rank <= b.rank) a else b
    }
}

enum class MoveKind(val label: String, val emoji: String) {
    HIIT("HIIT", "🔥"),
    STRENGTH("Strength", "🏋️"),
    CARDIO("Cardio", "🏃"),
    CORE("Core", "🎯"),
    YOGA("Yoga", "🧘"),
    MOBILITY("Mobility", "🤸"),
    BALANCE("Balance", "🦩"),
    WALK("Walk", "🚶"),
    RESTORE("Restore", "🌙")
}

/** Where a workout is done. EITHER means no equipment or terrain is needed, so it works inside or outside. */
enum class Venue(val label: String, val emoji: String) {
    INDOOR("Indoor", "🏠"),
    OUTDOOR("Outdoor", "🌳"),
    EITHER("Indoor or outdoor", "🏠🌳")
}

data class RoutineStep(val name: String, val seconds: Int, val cue: String, val isRest: Boolean = false)

/**
 * A guided session. Either a timed step list played by the in-app routine player,
 * or — when [externalRoute] is set — a hand-off to an existing tracked feature
 * (the step-counting walk screens), so walks still count steps and points.
 */
data class GuidedRoutine(
    val id: String,
    val title: String,
    val kind: MoveKind,
    val zones: Set<EnergyZone>,
    val summary: String,
    val equipment: String,
    val steps: List<RoutineStep>,
    val caution: String = "",
    val externalRoute: String? = null,
    val nominalMinutes: Int = 0,
    val venue: Venue = Venue.INDOOR
) {
    val minutes: Int get() =
        if (steps.isEmpty()) nominalMinutes else ((steps.sumOf { it.seconds } + 30) / 60).coerceAtLeast(1)
}

// ── Building blocks ────────────────────────────────────────────────────────────

private fun rest(seconds: Int = 15) = RoutineStep("Rest", seconds, "Breathe. Shake it out. Next one's coming.", isRest = true)

private val WARMUP = listOf(
    RoutineStep("March in place", 45, "Drive your knees up and swing your arms — warm, not winded."),
    RoutineStep("Arm circles", 30, "Small circles growing bigger. Switch direction halfway."),
    RoutineStep("Hip circles", 30, "Hands on hips, slow circles both ways."),
    RoutineStep("Easy bodyweight squats", 45, "Sit back like into a chair, chest tall, easy pace."),
    RoutineStep("Torso twists", 30, "Rotate gently side to side and let your arms swing.")
)

private val COOLDOWN = listOf(
    RoutineStep("Slow walk in place", 45, "Let your breathing settle."),
    RoutineStep("Forward fold", 40, "Soft knees. Let your head hang heavy."),
    RoutineStep("World's greatest stretch — left", 35, "Lunge, left hand down, right arm reaches to the sky. Open through your chest."),
    RoutineStep("World's greatest stretch — right", 35, "Switch sides."),
    RoutineStep("Three deep breaths", 25, "In through the nose, long slow exhale. Thank God for this body.")
)

private fun rounds(n: Int, roundRestSeconds: Int, block: List<RoutineStep>): List<RoutineStep> =
    (1..n).flatMap { r ->
        block.map { it.copy(name = if (it.isRest) it.name else "${it.name} · round $r/$n") } +
            if (r < n) listOf(RoutineStep("Round rest", roundRestSeconds, "Sip water. Round ${r + 1} next.", isRest = true)) else emptyList()
    }

private const val LOW_BONE_CAUTION =
    "Skip the jumps if you're pregnant, have joint pain, or have been told you have low bone density — use the low-impact option in each cue."

private const val OSTEO_CAUTION =
    "Have osteoporosis or a past fracture? Skip loaded forward-bending and twisting, and ask your doctor or a physical therapist which moves are right for you."

// ── Routine library ────────────────────────────────────────────────────────────

val ROUTINES: List<GuidedRoutine> = listOf(
    GuidedRoutine(
        id = "hiit_power", title = "HIIT Power", kind = MoveKind.HIIT, zones = setOf(EnergyZone.HIGH),
        summary = "Three fast rounds of 40 seconds on, 20 off. Short, hard, done.",
        equipment = "None",
        caution = LOW_BONE_CAUTION,
        steps = WARMUP + rounds(3, 30, listOf(
            RoutineStep("Squat jumps", 40, "Land softly through your whole foot. Low-impact: squat, then rise onto your toes."),
            rest(20),
            RoutineStep("Mountain climbers", 40, "Hands under shoulders, drive your knees in. Slow down if your hips pop up."),
            rest(20),
            RoutineStep("Push-ups", 40, "Knees down is perfectly fine — keep one straight line from head to knees."),
            rest(20),
            RoutineStep("Skater hops", 40, "Leap side to side. Low-impact: step wide and tap your back foot behind."),
            rest(20)
        )) + COOLDOWN,
        venue = Venue.EITHER
    ),
    GuidedRoutine(
        id = "strength_builder", title = "Strength Builder", kind = MoveKind.STRENGTH,
        zones = setOf(EnergyZone.HIGH, EnergyZone.STEADY),
        summary = "Full-body strength in three rounds — legs, push, pull, hips and core.",
        equipment = "Optional: dumbbells, water jugs, or a loaded backpack",
        steps = WARMUP + rounds(3, 60, listOf(
            RoutineStep("Squats", 45, "Hold a weight at your chest if you have one. Sit back, knees track over toes."),
            rest(),
            RoutineStep("Reverse lunges", 45, "Step back, lower until both knees are about 90°. Alternate legs."),
            rest(),
            RoutineStep("Push-ups", 40, "From the floor, knees, or a counter — pick the version you can do with good form."),
            rest(),
            RoutineStep("Bent-over rows", 45, "Hinge at the hips, flat back, pull the weight to your ribs."),
            rest(),
            RoutineStep("Glute bridges", 45, "Feet flat, press through your heels, squeeze at the top."),
            rest(),
            RoutineStep("Plank", 30, "Elbows under shoulders, long body, breathe. Knees down if you need.")
        )) + COOLDOWN,
        venue = Venue.INDOOR
    ),
    GuidedRoutine(
        id = "tempo_intervals", title = "Walk-Run Intervals", kind = MoveKind.CARDIO, zones = setOf(EnergyZone.HIGH),
        summary = "Six fast efforts with easy recovery between. Outside or in place.",
        equipment = "Good shoes",
        steps = listOf(RoutineStep("Warm-up walk", 240, "Start easy and build to a brisk pace.")) +
            (1..6).flatMap { i ->
                listOf(
                    RoutineStep("Fast effort $i/6", 60, "Run, or power-walk as fast as you can — you should be breathing hard."),
                    RoutineStep("Easy walk", 90, "Slow right down and let your breathing come back.", isRest = true)
                )
            } +
            listOf(
                RoutineStep("Cool-down walk", 180, "Easy pace. Let your heart rate settle."),
                RoutineStep("Calf and quad stretch", 60, "Hold a wall. Thirty seconds each side.")
            ),
        venue = Venue.EITHER
    ),
    GuidedRoutine(
        id = "steady_strength", title = "Steady Strength", kind = MoveKind.STRENGTH, zones = setOf(EnergyZone.STEADY),
        summary = "Two controlled rounds. Slow reps, steady breathing, solid form.",
        equipment = "A sturdy chair",
        steps = WARMUP + rounds(2, 45, listOf(
            RoutineStep("Squat to chair", 45, "Lower slowly until you just touch the chair, then stand. Three seconds down."),
            rest(),
            RoutineStep("Incline push-ups", 40, "Hands on a counter or table. Lower your chest, press away."),
            rest(),
            RoutineStep("Glute bridges", 45, "Pause for a breath at the top of every rep."),
            rest(),
            RoutineStep("Bird dog", 45, "On hands and knees, reach opposite arm and leg long. Alternate slowly."),
            rest(),
            RoutineStep("Side plank — left", 30, "Knees down is fine. Lift your hips and hold."),
            RoutineStep("Side plank — right", 30, "Same on this side. Breathe."),
            rest(),
            RoutineStep("Dead bug", 40, "Low back pressed to the floor, lower opposite arm and leg slowly.")
        )) + COOLDOWN,
        venue = Venue.INDOOR
    ),
    GuidedRoutine(
        id = "pilates_core", title = "Pilates Core Flow", kind = MoveKind.CORE, zones = setOf(EnergyZone.STEADY, EnergyZone.LOW),
        summary = "Controlled core work on the floor — deep strength without the strain.",
        equipment = "A mat or carpet",
        steps = listOf(
            RoutineStep("Breathing warm-up", 45, "On your back, knees bent. Breathe wide into your ribs."),
            RoutineStep("Modified hundred", 45, "Head down or lifted. Pump your arms gently, five counts in, five out."),
            rest(),
            RoutineStep("Dead bug", 45, "Low back stays down. Slow and controlled."),
            rest(),
            RoutineStep("Single-leg stretch", 40, "Hug one knee in, extend the other leg long. Switch smoothly."),
            rest(),
            RoutineStep("Bridge with march", 45, "Lift your hips, then lift one foot at a time without dropping."),
            rest(),
            RoutineStep("Side-lying leg lifts — left", 40, "Lie on your side, lift the top leg slowly."),
            RoutineStep("Side-lying leg lifts — right", 40, "Switch sides."),
            rest(),
            RoutineStep("Swimming", 40, "On your belly, lift opposite arm and leg in small, steady flutters."),
            rest(),
            RoutineStep("Plank shoulder taps", 30, "Knees down if needed. Keep your hips still."),
            RoutineStep("Child's pose", 45, "Sink back and breathe into your back.")
        ),
        venue = Venue.INDOOR
    ),
    GuidedRoutine(
        id = "brisk_prayer_walk", title = "Brisk Prayer Walk", kind = MoveKind.WALK, zones = setOf(EnergyZone.STEADY),
        summary = "A brisk walk with guided prayer prompts. Steps count toward your goal.",
        equipment = "Shoes", steps = emptyList(), externalRoute = "prayer_walk", nominalMinutes = 25,
        venue = Venue.OUTDOOR
    ),
    GuidedRoutine(
        id = "gentle_yoga", title = "Gentle Yoga Flow", kind = MoveKind.YOGA, zones = setOf(EnergyZone.LOW, EnergyZone.RECOVER),
        summary = "Slow, restorative poses to release tension and settle your mind.",
        equipment = "A mat or carpet",
        steps = listOf(
            RoutineStep("Bird dog", 60, "From hands and knees, reach one arm and the opposite leg long. Alternate slowly, breathing with each reach."),
            RoutineStep("Child's pose", 60, "Knees wide, arms long, forehead down. Breathe into your back."),
            RoutineStep("Low lunge — left", 45, "Left foot forward, back knee down. Sink your hips gently."),
            RoutineStep("Low lunge — right", 45, "Switch sides."),
            RoutineStep("World's greatest stretch", 45, "Lunge, one hand down, the other arm reaching to the sky. Switch sides halfway."),
            RoutineStep("Forward fold", 60, "Legs long, knees soft. Fold from the hips, no forcing."),
            RoutineStep("Standing twist — left", 45, "Feet planted, rotate gently to the left. Let your arms swing with you."),
            RoutineStep("Standing twist — right", 45, "Rotate to the right."),
            RoutineStep("Child's pose", 90, "Come back down, knees wide, and settle in longer this time."),
            RoutineStep("Rest", 120, "Lie still. Let the floor hold you. Be still, and know that He is God.")
        ),
        venue = Venue.INDOOR
    ),
    // Offered by itself when someone starts moving in the morning (MorningStretch). Not part of the daily plan.
    GuidedRoutine(
        id = MorningStretch.ROUTINE_ID, title = "Wake-up Stretch", kind = MoveKind.MOBILITY, zones = emptySet(),
        summary = "Three easy minutes to wake your body up. Standing, no mat needed.",
        equipment = "None",
        steps = listOf(
            RoutineStep("Arm circles", 30, "Stand tall, small circles growing bigger. Switch direction halfway."),
            RoutineStep("Neck half-circles", 30, "Chin to chest, then roll slowly from ear to ear."),
            RoutineStep("World's greatest stretch", 30, "Step one foot back into a lunge, hand down, reach your other arm to the sky."),
            RoutineStep("Standing twist", 30, "Feet planted, rotate gently side to side and let your arms swing."),
            RoutineStep("Hip circles", 30, "Hands on hips, slow circles both ways."),
            RoutineStep("Calf raises & breath", 30, "Rise onto your toes, lower slowly. Breathe in: This is the day the Lord has made. Breathe out: I will rejoice.")
        ),
        venue = Venue.EITHER
    ),
    GuidedRoutine(
        id = "mobility_reset", title = "Mobility Reset", kind = MoveKind.MOBILITY, zones = setOf(EnergyZone.LOW, EnergyZone.STEADY),
        summary = "Joint-by-joint mobility. Great on stiff mornings or after sitting all day.",
        equipment = "None",
        steps = listOf(
            RoutineStep("Neck half-circles", 40, "Chin to chest, roll ear to ear. Slowly."),
            RoutineStep("Arm circles", 30, "Small circles growing bigger. Switch direction halfway."),
            RoutineStep("Standing twist — left", 30, "Feet planted, rotate gently to the left. Let your arms swing with you."),
            RoutineStep("Standing twist — right", 30, "Rotate to the right."),
            RoutineStep("Hip circles", 40, "Standing, big slow circles both directions."),
            RoutineStep("Dead bug", 45, "On your back, knees and arms up. Slowly lower opposite arm and leg, keeping your low back still."),
            RoutineStep("World's greatest stretch — left", 40, "Lunge, left hand down, right arm reaches to the sky."),
            RoutineStep("World's greatest stretch — right", 40, "Switch sides."),
            RoutineStep("Forward fold", 40, "Soft knees. Let your head hang heavy and your hamstrings release."),
            RoutineStep("Calf raises", 30, "Hold a wall. Rise onto your toes, lower slowly."),
            RoutineStep("Supported squat hold", 45, "Hold a counter and sink into a comfortable squat. Breathe.")
        ),
        venue = Venue.INDOOR
    ),
    GuidedRoutine(
        id = "easy_walk", title = "Easy Outdoor Walk", kind = MoveKind.WALK, zones = setOf(EnergyZone.LOW, EnergyZone.RECOVER),
        summary = "An easy walk, ideally in daylight. Steps count toward your goal.",
        equipment = "Shoes", steps = emptyList(), externalRoute = "walk_live?venue=outdoor&plan=easy_20", nominalMinutes = 15,
        venue = Venue.OUTDOOR
    ),
    GuidedRoutine(
        id = "restorative_stretch", title = "Restorative Stretch", kind = MoveKind.RESTORE, zones = setOf(EnergyZone.RECOVER, EnergyZone.LOW),
        summary = "Long, supported holds that tell your nervous system it's safe to rest.",
        equipment = "A wall and a pillow",
        steps = listOf(
            RoutineStep("Forward fold", 180, "Soft knees, hang your head heavy and let gravity do the work — a long, slow release for your back and hamstrings."),
            RoutineStep("Child's pose", 120, "Pillow under your chest if you like. Breathe slowly."),
            RoutineStep("Low lunge — left", 60, "Left foot forward, back knee down. Sink your hips gently and let your hips open."),
            RoutineStep("Low lunge — right", 60, "Switch sides."),
            RoutineStep("Standing twist — left", 60, "Feet planted, rotate gently to the left."),
            RoutineStep("Standing twist — right", 60, "Rotate to the right."),
            RoutineStep("Belly breathing", 120, "One hand on your belly. Breathe so it rises and falls slowly.")
        ),
        venue = Venue.INDOOR
    ),
    GuidedRoutine(
        id = "cramp_relief", title = "Cramp Relief Flow", kind = MoveKind.RESTORE, zones = setOf(EnergyZone.RECOVER, EnergyZone.LOW),
        summary = "Gentle movement and warmth for period days. A heating pad pairs well.",
        equipment = "A pillow, and a heating pad if you have one",
        caution = "Pain bad enough to stop your day isn't something to push through — talk to your doctor.",
        steps = listOf(
            RoutineStep("Forward fold", 60, "Fold forward over a pillow in your lap. Let your belly soften and breathe."),
            RoutineStep("Bird dog", 60, "On hands and knees, reach one arm and the opposite leg long. Move slowly, following your breath."),
            RoutineStep("Wide-knee child's pose", 90, "Knees wide, belly soft, forehead down."),
            RoutineStep("Low lunge — left", 60, "Sink your hips gently and let the front of your hip open. Heat on your belly if you have it."),
            RoutineStep("Low lunge — right", 60, "Switch sides."),
            RoutineStep("Standing twist — left", 45, "Feet planted, rotate gently to the left."),
            RoutineStep("Standing twist — right", 45, "Rotate to the right."),
            RoutineStep("Child's pose", 120, "Come back down for this last, long rest before we breathe."),
            RoutineStep("Warm belly breathing", 60, "Hands on your belly. Breathe slowly into the warmth.")
        ),
        venue = Venue.INDOOR
    ),

    // ── Built for post-menopause (also fine for anyone) ─────────────────────
    GuidedRoutine(
        id = "bone_strength", title = "Bone Strength", kind = MoveKind.STRENGTH, zones = setOf(EnergyZone.STEADY, EnergyZone.HIGH),
        summary = "Weight-bearing strength for bones and muscle — chair, stairs and household weights.",
        equipment = "A chair, a stair, and two grocery bags or dumbbells",
        caution = OSTEO_CAUTION,
        steps = WARMUP + rounds(3, 60, listOf(
            RoutineStep("Sit-to-stand", 45, "Stand up from the chair without using your hands, then sit down slowly."),
            rest(),
            RoutineStep("Step-ups", 45, "Bottom stair, hold the rail. Step up, step down, switch the lead leg."),
            rest(),
            RoutineStep("Counter push-ups", 40, "Hands on the counter, body straight. Lower and press away."),
            rest(),
            RoutineStep("Rows", 45, "Band around a doorknob, or a bag in each hand bent over a chair. Squeeze your shoulder blades."),
            rest(),
            RoutineStep("Calf raises", 40, "Hold the counter. Rise up onto your toes, lower slowly."),
            rest(),
            RoutineStep("Farmer's carry", 60, "A heavy bag in each hand. Walk tall around the room."),
            rest(),
            RoutineStep("Glute bridges", 45, "Press through your heels and squeeze.")
        )) + COOLDOWN,
        venue = Venue.INDOOR
    ),
    GuidedRoutine(
        id = "balance_drills", title = "Balance & Fall-Proofing", kind = MoveKind.BALANCE, zones = setOf(EnergyZone.STEADY, EnergyZone.LOW),
        summary = "Short drills that train the balance you use every day. Keep a counter within reach.",
        equipment = "A kitchen counter to hold",
        steps = listOf(
            RoutineStep("Low lunge — left", 30, "Light fingertips on the counter. Sink into a low lunge on your left leg and hold steady."),
            RoutineStep("Low lunge — right", 30, "Switch legs."),
            rest(10),
            RoutineStep("Hip circles", 60, "Hold the counter. Big slow circles both directions — keep your standing leg steady."),
            rest(10),
            RoutineStep("Side-lying leg lifts — left", 40, "Lie on your side, lift the top leg slowly. This builds the hip strength that keeps you steady on one leg."),
            RoutineStep("Side-lying leg lifts — right", 40, "Switch sides."),
            rest(10),
            RoutineStep("Bird dog — left", 45, "On hands and knees, reach your right arm and left leg long. Hold steady."),
            RoutineStep("Bird dog — right", 45, "Switch — left arm and right leg."),
            rest(10),
            RoutineStep("Slow sit-to-stand", 60, "Five seconds down, stand smoothly, no hands if you can."),
            RoutineStep("Glute bridges", 45, "Press through your heels and squeeze — strong hips keep you steady on your feet."),
            RoutineStep("Calf raises", 40, "Up onto your toes, slowly down.")
        ),
        venue = Venue.INDOOR
    ),
    GuidedRoutine(
        id = "heart_walk", title = "Heart Health Walk", kind = MoveKind.CARDIO, zones = setOf(EnergyZone.STEADY),
        summary = "Thirty brisk minutes — talk-but-not-sing pace. Steps count toward your goal.",
        equipment = "Shoes", steps = emptyList(), externalRoute = "walk_live?venue=outdoor&plan=steady_30", nominalMinutes = 30,
        venue = Venue.OUTDOOR
    ),
    GuidedRoutine(
        id = "gentle_intervals", title = "Low-Impact Intervals", kind = MoveKind.CARDIO, zones = setOf(EnergyZone.STEADY, EnergyZone.HIGH),
        summary = "Brisk one-minute efforts with easy minutes between — no jumping.",
        equipment = "None",
        steps = listOf(RoutineStep("Warm-up walk", 180, "In place or outside. Build gently to a brisk pace.")) +
            (1..6).flatMap { i ->
                listOf(
                    RoutineStep("Brisk effort $i/6", 60, "March fast with big arm swings, or walk briskly uphill."),
                    RoutineStep("Easy pace", 60, "Slow down and recover.", isRest = true)
                )
            } +
            listOf(
                RoutineStep("Easy walk", 120, "Let your breathing settle."),
                RoutineStep("Calf and hip stretch", 60, "Hold a wall. Stretch each calf, then each hip.")
            ),
        venue = Venue.EITHER
    ),

    // ── Outdoor and treadmill sessions ───────────────────────────────────────
    GuidedRoutine(
        id = "park_bench_circuit", title = "Park Bench Circuit", kind = MoveKind.STRENGTH,
        zones = setOf(EnergyZone.STEADY, EnergyZone.HIGH),
        summary = "Strength outdoors with nothing but a park bench or a low wall. Three rounds.",
        equipment = "A sturdy park bench or low wall (check it is dry and solid)",
        caution = "Test the bench before you put weight on it, and keep your feet on dry ground.",
        steps = WARMUP + rounds(3, 45, listOf(
            RoutineStep("Bench step-ups", 45, "One whole foot on the bench. Drive up through your heel, step down slowly, switch the lead leg halfway."),
            rest(),
            RoutineStep("Bench incline push-ups", 40, "Hands on the bench edge, body in one straight line. Lower your chest, press away."),
            rest(),
            RoutineStep("Reverse lunges", 45, "Step back, lower until both knees are about 90°. Alternate legs."),
            rest(),
            RoutineStep("Bodyweight squats", 45, "Sit back like into the bench, chest tall, then stand."),
            rest(),
            RoutineStep("Calf raises", 40, "Up onto your toes, slowly down. Hold the bench for balance."),
            rest(),
            RoutineStep("Bench plank", 30, "Forearms on the bench, long body from head to heels. Breathe.")
        )) + COOLDOWN,
        venue = Venue.OUTDOOR
    ),
    GuidedRoutine(
        id = "hill_stair_intervals", title = "Hill & Stair Intervals", kind = MoveKind.CARDIO, zones = setOf(EnergyZone.HIGH),
        summary = "Six hard climbs up a hill or a flight of stairs, with an easy walk down to recover.",
        equipment = "A hill or a flight of stairs, and good shoes",
        caution = "Pick ground with firm footing and a handrail if there is one, and walk the way down. Stop if you feel dizzy or any chest pain.",
        steps = listOf(RoutineStep("Warm-up walk", 240, "Start easy and build to a brisk pace on flat ground.")) +
            (1..6).flatMap { i ->
                listOf(
                    RoutineStep("Fast effort $i/6", 45, "Power up the hill or stairs, arms swinging. Hard, but with good form."),
                    RoutineStep("Easy walk down", 75, "Walk back down slowly and let your breathing come back.", isRest = true)
                )
            } +
            listOf(
                RoutineStep("Cool-down walk", 180, "Easy pace on flat ground. Let your heart rate settle."),
                RoutineStep("Calf and quad stretch", 60, "Hold a wall or railing. Thirty seconds each side.")
            ),
        venue = Venue.OUTDOOR
    ),
    GuidedRoutine(
        id = "outdoor_power_walk", title = "Outdoor Power Walk", kind = MoveKind.WALK, zones = setOf(EnergyZone.STEADY, EnergyZone.HIGH),
        summary = "A brisk, guided walk with a live map, pace bands and a built-in warm-up and cool-down.",
        equipment = "Shoes",
        steps = emptyList(), externalRoute = "walk_live?venue=outdoor&plan=brisk_30", nominalMinutes = 30,
        venue = Venue.OUTDOOR
    ),
    GuidedRoutine(
        id = "treadmill_walk", title = "Treadmill or Indoor Walk", kind = MoveKind.WALK, zones = setOf(EnergyZone.LOW, EnergyZone.STEADY),
        summary = "A steady walk at home or on a treadmill, counted by your steps, with warm-up and cool-down.",
        equipment = "Shoes, and a treadmill if you have one",
        steps = emptyList(), externalRoute = "walk_live?venue=indoor&plan=steady_30", nominalMinutes = 30,
        venue = Venue.INDOOR
    )
)
data class DevotionalFocus(
    val id: String,
    val theme: String,
    val reference: String,
    val verse: String,
    val reflection: String,
    val prayer: String
)

private val BOLD_WORDS = listOf(
    DevotionalFocus("bold_joshua", "Courage", "Joshua 1:9",
        "Haven't I commanded you? Be strong and courageous. Don't be afraid. Don't be dismayed, for the LORD your God is with you wherever you go.",
        "Courage isn't the absence of fear — it's moving forward because God goes with you. Today you have energy to spare; spend it on something that takes courage.",
        "Lord, You go with me today. Make me bold for what matters. Amen."),
    DevotionalFocus("bold_isaiah", "Renewed strength", "Isaiah 40:31",
        "But those who wait for the LORD will renew their strength. They will mount up with wings like eagles. They will run, and not be weary. They will walk, and not faint.",
        "Your strength today is a gift, not an achievement. Run with it — and remember where it comes from.",
        "Father, thank You for strength today. Let me run and not grow weary. Amen."),
    DevotionalFocus("bold_hebrews", "Run your race", "Hebrews 12:1",
        "…let's run with perseverance the race that is set before us,",
        "Your race is yours — not anyone else's pace or distance. Lay down what weighs you down and run today with purpose.",
        "Jesus, help me lay aside what holds me back and run my race well. Amen."),
    DevotionalFocus("bold_timothy", "Power, love, self-control", "2 Timothy 1:7",
        "For God didn't give us a spirit of fear, but of power, love, and self-control.",
        "High-energy days are perfect for the thing you've been avoiding. Fear isn't from God; power, love and self-control are.",
        "Holy Spirit, fill me with Your power and love today. Amen."),
    DevotionalFocus("bold_corinthians", "Run to win", "1 Corinthians 9:24",
        "Don't you know that those who run in a race all run, but one receives the prize? Run like that, so that you may win.",
        "Paul used the athlete's discipline as a picture of faith. Train your body with purpose today — and train your soul the same way.",
        "Lord, let my discipline today honor You, body and soul. Amen."),
    DevotionalFocus("bold_philippians", "All things through Christ", "Philippians 4:13",
        "I can do all things through Christ, who strengthens me.",
        "Paul wrote this about contentment in every circumstance — strong days and hard ones alike. Today is a strong one; give Him the credit.",
        "Christ, You are my strength on the good days too. Amen.")
)

private val STEADY_WORDS = listOf(
    DevotionalFocus("steady_colossians", "Whole-hearted", "Colossians 3:23",
        "And whatever you do, work heartily, as for the Lord, and not for men,",
        "Steady days are where faithfulness is built — the ordinary reps of life done for an audience of One.",
        "Lord, I offer You the ordinary work of today. Amen."),
    DevotionalFocus("steady_galatians", "Don't give up", "Galatians 6:9",
        "Let's not be weary in doing good, for we will reap in due season, if we don't give up.",
        "Consistency rarely feels dramatic. Keep showing up — the harvest comes in due season.",
        "Father, give me patience to keep sowing. Amen."),
    DevotionalFocus("steady_psalm118", "This is the day", "Psalm 118:24",
        "This is the day that the LORD has made. We will rejoice and be glad in it!",
        "Not a perfect day — this day. Find one ordinary thing to rejoice in before lunch.",
        "Lord, open my eyes to the gifts in this ordinary day. Amen."),
    DevotionalFocus("steady_lamentations", "New every morning", "Lamentations 3:22–23",
        "It is because of the LORD's loving kindnesses that we are not consumed, because his compassion doesn't fail. They are new every morning. Great is your faithfulness.",
        "Yesterday doesn't define today. His mercy arrived fresh this morning — start from there.",
        "Thank You for new mercy this morning. Great is Your faithfulness. Amen."),
    DevotionalFocus("steady_romans", "A living offering", "Romans 12:1",
        "…present your bodies a living sacrifice, holy, acceptable to God, which is your spiritual service.",
        "Caring for your body is worship when you offer it to God. Today's movement can be a prayer.",
        "Lord, I offer You this body and this day. Amen."),
    DevotionalFocus("steady_temple", "Your body matters to God", "1 Corinthians 6:19",
        "Or don't you know that your body is a temple of the Holy Spirit which is in you, which you have from God?",
        "Not a project to perfect — a temple to care for. Eat, move and rest today like it belongs to Someone who loves you.",
        "Holy Spirit, help me care for this temple well today. Amen.")
)

private val GROUNDING_WORDS = listOf(
    DevotionalFocus("ground_matthew", "Come and rest", "Matthew 11:28",
        "Come to me, all you who labor and are heavily burdened, and I will give you rest.",
        "Jesus doesn't say \"try harder.\" He says come. On a low-energy day, coming to Him is the whole assignment.",
        "Jesus, I'm tired. I come to You. Give me Your rest. Amen."),
    DevotionalFocus("ground_psalm23", "Still waters", "Psalm 23:2–3",
        "He makes me lie down in green pastures. He leads me beside still waters. He restores my soul.",
        "Sometimes the Shepherd makes us lie down. A slower day isn't a failure — it may be His leading.",
        "Good Shepherd, lead me to still waters today. Restore my soul. Amen."),
    DevotionalFocus("ground_psalm46", "Be still", "Psalm 46:10",
        "Be still, and know that I am God.",
        "Stillness is an act of trust. Give God three quiet minutes today before you reach for your phone.",
        "Lord, I'm choosing stillness. You are God, and I am not. Amen."),
    DevotionalFocus("ground_isaiah30", "Quiet strength", "Isaiah 30:15",
        "You will be saved in returning and rest. Your strength will be in quietness and in confidence.",
        "Strength isn't always loud. Today it may look like quietness and confidence in God.",
        "Father, be my quiet strength today. Amen."),
    DevotionalFocus("ground_corinthians", "Grace in weakness", "2 Corinthians 12:9",
        "My grace is sufficient for you, for my power is made perfect in weakness.",
        "You don't need to feel strong for God to be strong in you. Low days are exactly where His power shows up.",
        "Lord, Your grace is enough for today. Be strong in my weakness. Amen.")
)

private val REST_WORDS = listOf(
    DevotionalFocus("rest_psalm4", "Lie down in peace", "Psalm 4:8",
        "In peace I will both lay myself down and sleep, for you, the LORD alone, make me live in safety.",
        "Rest is trust in action — you lie down because Someone else keeps watch.",
        "Lord, You keep me safe. I lay this day down in peace. Amen."),
    DevotionalFocus("rest_psalm127", "He gives sleep", "Psalm 127:2",
        "…for he gives sleep to his loved ones.",
        "You don't have to earn rest. It's a gift He gives to the people He loves — and that includes you.",
        "Father, I receive Your rest as a gift. Amen."),
    DevotionalFocus("rest_exodus", "Be still", "Exodus 14:14",
        "The LORD will fight for you, and you shall be still.",
        "Some battles are His, not yours. Today, let Him fight while you recover.",
        "Lord, I hand You what I can't carry today. Amen."),
    DevotionalFocus("rest_psalm62", "Rest in God alone", "Psalm 62:1",
        "My soul rests in God alone. My salvation is from him.",
        "Not in productivity, not in a perfect streak — in God alone.",
        "My soul rests in You, Lord. Amen."),
    DevotionalFocus("rest_john", "His peace", "John 14:27",
        "Peace I leave with you. My peace I give to you; not as the world gives, give I to you. Don't let your heart be troubled, neither let it be fearful.",
        "The world's peace depends on circumstances. His doesn't. Receive it on a day you can't produce it yourself.",
        "Jesus, I receive Your peace today. Amen."),
    DevotionalFocus("rest_psalm34", "Near to you", "Psalm 34:18",
        "The LORD is near to those who have a broken heart, and saves those who have a crushed spirit.",
        "If today is heavy, He is not far off. He comes close.",
        "Lord, come close today. I need You. Amen.")
)


fun q(s: String) = "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\""
fun main() {
    val sb = StringBuilder("{\"routines\":[")
    sb.append(ROUTINES.joinToString(",") { r ->
        "{\"id\":${q(r.id)},\"title\":${q(r.title)},\"kind\":${q(r.kind.name)},\"zones\":[${r.zones.joinToString(","){q(it.name)}}],\"summary\":${q(r.summary)},\"equipment\":${q(r.equipment)},\"caution\":${q(r.caution)},\"externalRoute\":${r.externalRoute?.let{q(it)} ?: "null"},\"nominalMinutes\":${r.nominalMinutes},\"venue\":${q(r.venue.name)},\"steps\":[" +
        r.steps.joinToString(",") { s -> "{\"name\":${q(s.name)},\"seconds\":${s.seconds},\"cue\":${q(s.cue)},\"rest\":${s.isRest}}" } + "]}"
    })
    sb.append("],\"devotionals\":{")
    fun pool(n: String, l: List<DevotionalFocus>) = q(n) + ":[" + l.joinToString(",") { d -> "{\"id\":${q(d.id)},\"theme\":${q(d.theme)},\"reference\":${q(d.reference)},\"verse\":${q(d.verse)},\"reflection\":${q(d.reflection)},\"prayer\":${q(d.prayer)}}" } + "]"
    sb.append(listOf(pool("HIGH", BOLD_WORDS), pool("STEADY", STEADY_WORDS), pool("LOW", GROUNDING_WORDS), pool("RECOVER", REST_WORDS)).joinToString(","))
    sb.append("}}")
    java.io.File("coach.json").writeText(sb.toString())
    println("routines " + ROUTINES.size)
}
object MorningStretch { const val ROUTINE_ID = "wake_stretch" }
