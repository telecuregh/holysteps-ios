# Women's mental health talks. No faith content. Every figure is from a named, current source (listed per talk).
T = []
def talk(id, category, title, subtitle, free, sources, script):
    T.append(dict(id=id, hub="women", category=category, title=title, subtitle=subtitle, free=free,
                  sources=[dict(title=t, url=u) for t, u in sources], script=script.strip()))

talk("wtalk_depression", "Depression", "It's Not Just a Bad Week",
     "Women are about twice as likely as men to face depression. How to tell, and what actually helps.", True,
     [("NIH Office of Research on Women's Health: Depression", "https://discoverwhr.nih.gov/research/depression/"),
      ("BMJ (2024): Effect of exercise for depression, network meta-analysis", "https://www.bmj.com/content/384/bmj-2023-075847")], """
Let's talk about depression. Not the bad day, not the rough week after a breakup or a hard work project. The kind that settles in and stays.

Here's something worth knowing. According to the NIH Office of Research on Women's Health, after puberty women are about twice as likely as men to develop depression. That doesn't mean women are weaker. Researchers point to a mix of reasons. Hormone shifts across the cycle, pregnancy, postpartum and perimenopause. Higher rates of certain kinds of trauma. And the sheer weight of what a lot of women carry, at work and at home.

So how do you know if it's depression? Doctors look for symptoms that last most of the day, nearly every day, for two weeks or more. A low or empty mood. Losing interest in things you used to enjoy. Sleep and appetite changes. Feeling worthless or guilty. Trouble concentrating. Exhaustion. Sometimes it shows up as irritability, or feeling numb.

And here's the good news. Depression is one of the most treatable conditions there is. Therapy works. Medication helps many people. And movement helps too. A 2024 review in the British Medical Journal looked at two hundred eighteen trials and found that walking or jogging, yoga, and strength training all reduced depression. Interestingly, strength training seemed to work especially well for women.

Here's what I want you to take with you.

Name it. If this has been going on for two weeks or more, it's worth taking seriously. You're not being dramatic.

Talk to your doctor or your OB-GYN. You can simply say, I think I might be depressed. They can screen you and talk through options.

Move a little every day. Even a ten minute walk counts. Try lifting something, too. Body weight squats, light weights, carrying groceries. Strength training helps mood.

Tell one person you trust. Depression thrives in isolation. Letting someone in is a big step.

Be gentle with yourself. Depression makes everything harder, including getting help. Small steps count.

And if you ever have thoughts of not wanting to be here, call or text nine eight eight, any time, day or night.

You deserve to feel like yourself again. And you can.
""")

talk("wtalk_anxiety", "Anxiety", "When Worry Runs Everything",
     "The what-ifs, the tight chest, the mind that won't rest. Practical ways to calm an anxious brain.", True,
     [("MedlinePlus: Panic disorder (more common in women)", "https://medlineplus.gov/ency/article/000924.htm"),
      ("NIMH: Panic Disorder, When Fear Overwhelms (CBT as first-line treatment)", "https://www.nimh.nih.gov/sites/default/files/documents/health/publications/panic-disorder-when-fear-overwhelms/22-MH-8077_PanicDisorder.pdf")], """
If your mind is always running ahead to what could go wrong, this one's for you.

Maybe you're the planner in your family. The one who remembers the dentist appointments and the permission slips and whether there's milk in the fridge. And somewhere along the way your brain decided its job is to see every possible problem before it happens. Your kid is ten minutes late and you're picturing the worst. Your boss says, can we talk, and you're up half the night.

Anxiety is very common, and it's more common in women. MedlinePlus, the National Library of Medicine's health site, notes that panic disorder, for example, is twice as common in women as in men.

Here's what's going on inside. Your brain has an alarm system meant to keep you safe. In anxiety, the alarm gets oversensitive. It goes off for things that aren't actually dangerous, and floods your body with stress chemicals. Racing heart, tight chest, upset stomach, tense shoulders.

The good news is, there are real ways to turn the volume down. One of the simplest is grounding. When your mind runs into the future, use your senses to pull it back to right now. Name five things you can see. Four you can feel. Three you can hear. Two you can smell. One you can taste. Try it the next time you notice the spiral.

And try a long exhale. Breathe in through your nose for four counts, and out slowly for six or seven, like you're blowing on hot soup. A longer out breath tells your body you're safe. Let's do a couple together.

[PAUSE 10 SECONDS]

Here's what I want you to take with you.

Write the worries down. On paper, they shrink. Sort them into things you can act on, and things you can't.

Ask, is this a problem for right now? If not, give yourself permission to set it down until tomorrow.

Ground yourself with your senses. Five, four, three, two, one.

Watch caffeine and alcohol. Both can make anxiety worse.

You don't have to carry everyone's safety on your shoulders. That's too heavy for one person.

And if anxiety is running your life for weeks at a time, talk to your doctor. Cognitive behavioral therapy is a first-line treatment, and medication can help too.

Your mind is trying to protect you. You can teach it that you're safe.
""")

talk("wtalk_pmdd", "PMS/PMDD", "The Week Before",
     "If you feel like a different person the same week every month, it's not in your head.", False,
     [("ACOG Clinical Practice Guideline No. 7: Management of Premenstrual Disorders (2023)", "https://www.acog.org/clinical/clinical-guidance/clinical-practice-guideline/articles/2023/12/management-of-premenstrual-disorders"),
      ("American Family Physician (2024): Premenstrual Disorders, ACOG guidelines summary", "https://www.aafp.org/afp/2024/1200/practice-guidelines-premenstrual-disorders")], """
Does this sound familiar? For most of the month you feel like yourself. Then, about a week or two before your period, something shifts. You're irritable, weepy, anxious, or flat. Small things feel huge. You snap at people you love. You feel hopeless, or exhausted, or out of control. And then, a day or two after your period starts, it lifts, like a storm passing.

A lot of women have been told for years that this is just PMS, or that they're being emotional. But there's real medicine behind what you're feeling.

In late 2023, the American College of Obstetricians and Gynecologists published its first clinical guideline on premenstrual disorders. According to that guidance, about twenty to thirty percent of menstruating women have symptoms that meet the criteria for premenstrual syndrome, or PMS. And about two to five percent have premenstrual dysphoric disorder, or PMDD, where the mood symptoms are severe enough to seriously interfere with work, relationships, and daily life.

The key thing is the timing. These symptoms show up in the second half of your cycle, after ovulation, and go away shortly after your period starts. Researchers think people with these disorders aren't making abnormal hormones. Their brains are more sensitive to the normal rise and fall of estrogen and progesterone.

And there's good news. There are treatments with real evidence. A review of the ACOG guidelines in American Family Physician noted that certain antidepressants help, even when taken only in the second half of the cycle. Some birth control pills help. And cognitive behavioral therapy appears to work about as well as fluoxetine, a common antidepressant, for PMDD.

Here's what I want you to take with you.

Track it. Every day, for at least two cycles, rate your mood, irritability, anxiety, energy, and sleep. You can do it right here in the app. Patterns help you get taken seriously.

Bring your tracking to your doctor or OB-GYN. Say, I think this might be PMDD. Ask about treatment options.

Name your hard week. Mark it on your calendar. Lighten your schedule if you can. Tell the people closest to you what helps.

Be kind to yourself that week. Your body is going through something real.

Some women with PMDD have very dark thoughts during that week, even thoughts of not wanting to be here. If that's you, you're not alone, and it's not your fault. Call or text nine eight eight any time, and tell your doctor.

It's real. It's common. And it's treatable.
""")

talk("wtalk_postpartum", "Postpartum", "Not the Joy You Expected",
     "About 1 in 8 new moms has symptoms of postpartum depression. It can start months later, too.", False,
     [("CDC: Identifying Maternal Depression (1 in 8 report symptoms)", "https://archive.cdc.gov/www_cdc_gov/reproductivehealth/vital-signs/identifying-maternal-depression/index.html"),
      ("CDC Preventing Chronic Disease (2023): Timing of Postpartum Depressive Symptoms", "https://www.cdc.gov/pcd/issues/2023/23_0107.htm"),
      ("HRSA: National Maternal Mental Health Hotline", "https://mchb.hrsa.gov/national-maternal-mental-health-hotline")], """
If you just had a baby and you don't feel the way you thought you would, please listen to this.

Everyone talks about the joy. And there can be joy. But a lot of new moms also feel exhausted down to their bones, anxious, teary, numb, or overwhelmed. Some feel disconnected from their baby, and then crushed by guilt about it. Some have scary thoughts that come out of nowhere, about something bad happening to the baby, and those thoughts are terrifying.

First, the baby blues are very common. Mood swings, crying, and worry in the first couple of weeks usually get better on their own.

But postpartum depression is different. It's more intense, it lasts longer, and it gets in the way of daily life. And it's common. The CDC reports that about one in eight women have symptoms of depression after giving birth.

Here's something a lot of people don't know. It doesn't always start right away. A CDC study published in 2023 found that about seven percent of mothers had depressive symptoms nine to ten months after birth, and more than half of them hadn't had symptoms in the first few months. So if you felt okay at first and you're struggling now, that still counts.

Postpartum depression is not your fault. It doesn't mean you're a bad mother, or that you don't love your baby. It's a medical condition, linked to huge hormone shifts, sleep loss, and the massive changes that come with a new baby. And it's treatable, with therapy, medication, or both, including options that are safe while breastfeeding.

Here's what I want you to take with you.

Tell your doctor or midwife. You don't have to wait for your six week checkup. Call and say, I'm not okay. Tell them about scary thoughts, too. They hear this often, and they can help.

Save this number: the National Maternal Mental Health Hotline. One eight three three, T L C, M A M A. That's one eight three three, eight five two, six two six two. It's free, confidential, and open twenty-four hours a day. You can call or text.

Let people help. Let your partner, your mom, or a friend take a feeding or a night, so you can sleep. Sleep is part of healing.

Lower the bar. The house can be messy. Dinner can be cereal. You're keeping a person alive. That's enough.

And if you ever have thoughts of harming yourself or your baby, or of not wanting to be here, call or text nine eight eight, or call nine one one, right away.

You're not alone in this. And you will feel like yourself again.
""")

talk("wtalk_pregnancy_anxiety", "Postpartum", "Worried All Through Pregnancy",
     "Anxiety during pregnancy is common and often missed. How to cope, and when to ask for help.", False,
     [("CDC: CDC Activities, Improving Maternal Mental Health Care", "https://www.cdc.gov/reproductive-health/depression/cdc-activities.html"),
      ("HRSA: National Maternal Mental Health Hotline", "https://mchb.hrsa.gov/national-maternal-mental-health-hotline")], """
Pregnancy is supposed to be this glowing, happy time. But for a lot of women, it's also full of worry. Is the baby okay? Did I eat the wrong thing? What if something goes wrong at the next ultrasound? What if I'm not ready? What if labor is awful?

Some worry is completely normal. You're growing a whole person, and you care deeply. But for some women, the worry takes over. You can't stop checking symptoms online. You can't sleep. You feel on edge all the time. Maybe you have panic attacks. Maybe you've been through a loss before, and every twinge brings it all back.

Anxiety and depression during pregnancy are common, and they're often missed. The CDC has found that health care providers are missing chances to ask about it. In one CDC study, about one in five pregnant women weren't asked about symptoms of depression at a prenatal visit. So you may have to bring it up yourself.

And it matters to bring it up. Your mental health during pregnancy matters for you, and it matters for your baby. Treatment can help, and there are options that are considered safe during pregnancy. Your provider can walk you through the choices.

Here's what I want you to take with you.

Tell your OB-GYN or midwife how you're really feeling. Say the actual words. I'm anxious all the time. I'm not sleeping. I'm scared.

Limit the late night searching. The internet is full of worst case stories. Pick one or two trusted sources and step away from the rest.

Ask your provider what's normal. A lot of worry shrinks when you know what to expect, and what to call about.

Practice calming your body. Slow breathing, a gentle walk, a warm shower, prenatal yoga. These help your nervous system settle.

If you've had a past loss, tell your care team. They can offer extra check-ins and support, and they won't think you're overreacting.

Call the National Maternal Mental Health Hotline any time. One eight three three, T L C, M A M A. That's one eight three three, eight five two, six two six two. It's for pregnancy too, not just after the baby comes.

And if you ever have thoughts of not wanting to be here, call or text nine eight eight.

Caring for your mind is caring for your baby.
""")

talk("wtalk_pregnancy_loss", "Grief", "After a Pregnancy Loss",
     "Miscarriage is common, and the grief is real. What research shows, and how to get through it.", False,
     [("American Journal of Obstetrics & Gynecology (2020): Posttraumatic stress, anxiety and depression after miscarriage and ectopic pregnancy", "https://pubmed.ncbi.nlm.nih.gov/31953115/"),
      ("NIHR Evidence: PTSD after early pregnancy loss", "https://evidence.nihr.ac.uk/alert/pregnancy-loss-post-traumatic-stress")], """
If you've lost a pregnancy, I'm so sorry. Whether it was very early or later on, whether anyone else even knew, it's a real loss. You lost a future you'd already started picturing.

And a lot of women grieve in silence. Because people don't know what to say. Because some people say the wrong thing, like, at least it was early, or, you can try again. Because you may have gone back to work two days later like nothing happened.

Here's something important. Research shows how deeply this can affect women. A study published in 2020 in the American Journal of Obstetrics and Gynecology followed women after early pregnancy loss, including miscarriage and ectopic pregnancy. One month after the loss, about twenty-nine percent met the criteria for post-traumatic stress, about twenty-four percent had moderate to severe anxiety, and about eleven percent had moderate to severe depression. Nine months later, about eighteen percent still had post-traumatic stress symptoms.

So if you're having flashbacks, nightmares, panic, or can't stop thinking about it, you're not overreacting. Your mind is responding to something that was genuinely traumatic.

And your partner may be hurting too. A related study from the same researchers found that some partners also experience post-traumatic stress, anxiety, and depression after a pregnancy loss, though often at lower rates, and they tend to hide it.

Here's what I want you to take with you.

Your grief is valid, no matter how far along you were. You don't need anyone's permission to mourn.

Give yourself time. Physically and emotionally. Grief comes in waves, and anniversaries and due dates can bring it back.

Say what you need. Some people want to talk about it. Some don't. Tell the people close to you which you'd prefer.

Find a way to remember, if that helps. A name, a small keepsake, planting something, writing a letter.

Talk to your doctor if you're struggling. Especially if you have flashbacks, panic, or depression weeks later. Trauma-focused therapy can really help.

Know that it wasn't your fault. Most early losses happen because of things nobody could control.

And if the grief ever turns into thoughts of not wanting to be here, call or text nine eight eight.

You loved them. That love is real, and so is this grief.
""")

talk("wtalk_infertility", "Grief", "The Waiting and the Hoping",
     "Infertility affects about 1 in 6 people worldwide. The emotional toll is real, and you're not alone.", False,
     [("World Health Organization (2023): 1 in 6 people globally affected by infertility", "https://www.who.int/news/item/04-04-2023-1-in-6-people-globally-affected-by-infertility")], """
If you've been trying to get pregnant, and month after month it hasn't happened, you know a particular kind of pain. The hope at the start of each cycle. The waiting. The test. And then the disappointment, again. Maybe the appointments, the shots, the procedures, the bills. And all the while, everyone around you seems to be announcing pregnancies.

You're far from alone. In 2023, the World Health Organization released a major report finding that about one in six people around the world experience infertility at some point in their lives. In the Americas, it was about one in five.

The WHO also pointed out that infertility can cause significant distress, stigma, and financial hardship, affecting people's mental health. That matches what so many women describe. Grief, anxiety, jealousy and guilt about the jealousy, feeling like your body is failing you, strain on your relationship, and a kind of loneliness, because it's hard to talk about.

Here's something worth knowing. Infertility affects both men and women. It's not a personal failure, and it's not your fault. It's a medical condition.

Here's what I want you to take with you.

Name the grief. Each month that doesn't work out can be a small loss. It's okay to be sad about it.

Protect your heart around triggers. It's okay to skip a baby shower, mute certain accounts, or step out of a conversation. That's self-care, not selfishness.

Talk with your partner as a team. Infertility can put stress on a relationship. Make time to be together that isn't about trying, schedules or treatment.

Find people who get it. Infertility support groups, online or in person, can make you feel much less alone.

Ask about counseling. Many fertility clinics have counselors who specialize in this. Therapy can help with the anxiety, grief, and decision making.

Set limits that make sense for you. Around money, time, and how much treatment you want. You get to decide what's right.

And if you're feeling hopeless, or having thoughts of not wanting to be here, call or text nine eight eight, and talk to your doctor.

Your worth is not measured by what your body can or can't do.
""")

talk("wtalk_perimenopause", "Depression", "Is It Me, or Is It Perimenopause?",
     "Mood swings, anxiety and low mood in your forties are often hormonal. A 2024 study shows how much.", False,
     [("Journal of Affective Disorders (2024): The risk of depression in the menopausal stages", "https://www.ucl.ac.uk/news/2024/may/women-are-40-more-likely-experience-depression-during-perimenopause")], """
If you're somewhere in your late thirties, forties, or early fifties, and you suddenly don't feel like yourself, this one's for you.

Maybe you're more anxious than you've ever been. Maybe you're irritable, or crying over things that wouldn't have bothered you before. Your sleep is off. Your memory feels foggy. Your periods are changing. And part of you is wondering, what is happening to me?

This might be perimenopause. That's the transition leading up to menopause, when your hormone levels start to rise and fall unpredictably. It usually begins a few years before your periods stop, and it can last several years.

And here's the important part. It can really affect your mood. In 2024, researchers at University College London published a review in the Journal of Affective Disorders that pooled data from studies around the world. They found that women in perimenopause were about forty percent more likely to have depressive symptoms or a depression diagnosis, compared with women before perimenopause.

Forty percent. That's not you being weak or overreacting. That's your brain responding to big hormonal changes.

The problem is, a lot of women don't connect the dots. And sometimes doctors don't either. So women are left thinking they're just stressed, or that something is wrong with them.

Here's what I want you to take with you.

Track your symptoms. Mood, sleep, hot flashes, periods, memory. You can do it right in the app. Patterns help your doctor see what's going on.

Ask your doctor directly. Could this be perimenopause? There are treatments that can help, including hormone therapy for some women, and other options. Ask what's right for you.

Protect your sleep. Poor sleep makes mood swings worse. Keep a cool bedroom, a steady wake time, and limit late caffeine and alcohol.

Move and lift. Exercise helps mood, sleep, and bone strength, which matters more in this stage.

Talk to other women. You'd be amazed how many friends are going through the same thing quietly.

And if you're feeling hopeless, or having thoughts of not wanting to be here, call or text nine eight eight.

This is a season of change, not the end of you.
""")

talk("wtalk_menopause", "Burnout", "Hot Nights, Foggy Days",
     "Hot flashes can last years and wreck sleep and mood. What the research says and what helps.", False,
     [("JAMA Internal Medicine (2015, SWAN study): Duration of menopausal vasomotor symptoms", "https://pubmed.ncbi.nlm.nih.gov/25686030/"),
      ("CDC NCHS Data Brief 559: Short Sleep Duration Among Adults, 2024", "https://www.cdc.gov/nchs/products/databriefs/db559.htm")], """
Let's talk about the part of menopause that nobody warned you would take this long.

Hot flashes and night sweats. You wake up drenched at two in the morning. You throw the covers off, then you're freezing. You lie there wide awake. And the next day, you're exhausted, short-tempered, and foggy. And then it happens again.

These are called vasomotor symptoms, and up to eighty percent of women experience them during the menopause transition. Many women were told they'd last a year or two. But a large U.S. study called SWAN, the Study of Women's Health Across the Nation, followed women for years and found that frequent hot flashes and night sweats lasted a median of about seven and a half years. For many women, it was longer.

That's a long time to not be sleeping well. And sleep loss hits mood hard. The CDC recommends at least seven hours of sleep for adults, and about thirty percent of adults already get less than that. When night sweats are breaking up your sleep, everything feels harder. Anxiety goes up. Patience goes down. Memory gets fuzzy.

So if you're feeling worn down, irritable, or low, it's not a character flaw. Your sleep and your hormones are both under real strain.

Here's what I want you to take with you.

Talk to your doctor about treatment. There are effective options for hot flashes, including hormone therapy for many women and non-hormonal medications. You don't have to just tough it out.

Cool your bedroom. Layered bedding you can kick off, a fan, breathable pajamas, cool water by the bed.

Notice your triggers. For some women, alcohol, spicy food, caffeine, or stress make hot flashes worse.

Keep a steady wake time, even after a bad night. It helps your body clock recover.

Be honest with the people around you. A simple, I didn't sleep, I'm running low today, helps others give you grace.

Ask about brain fog, too. Trouble with memory and focus is common in this stage. It often improves, and there are ways to manage it.

And if you're feeling persistently low or hopeless, talk to your doctor, and call or text nine eight eight if you ever think about not wanting to be here.

You deserve to sleep. And you deserve help getting there.
""")

talk("wtalk_body_image", "Self-Worth", "The Mirror and the Feed",
     "Comparison on social media hits how we see our bodies. A 2023 study shows what cutting back does.", False,
     [("American Psychological Association (2023): Reducing social media use significantly improves body image", "https://www.apa.org/news/press/releases/2023/02/social-media-body-image")], """
How many times today did you look at someone else's body on your phone? Probably a lot more than you think. Perfect skin, perfect stomach, perfect vacation photos. And how did you feel about your own body afterward?

A lot of women carry a running commentary about how they look. Too big here, too soft there, too old, too tired. It can start before you even get out of bed. And social media can turn the volume way up, because you're comparing your real, unfiltered self to hundreds of edited, filtered, perfectly lit images every day.

Here's some encouraging research. In 2023, the American Psychological Association published a study of young adults who already had symptoms of anxiety or depression. Some of them cut their social media use roughly in half, down to about an hour a day, for a few weeks. Compared with people who kept scrolling as usual, they felt significantly better about both their overall appearance and their weight. In just a few weeks.

The lead researcher pointed out that social media exposes people to images that lead us to internalize beauty ideals that are unattainable for almost everyone. That's the key word. Unattainable. You're comparing yourself to something that doesn't really exist.

Here's what I want you to take with you.

Try a social media cut. Half your usual time, for three weeks. Notice how you feel about yourself at the end.

Curate your feed. Mute or unfollow accounts that leave you feeling worse. Follow people who look like real people, and accounts about things you love that aren't about bodies.

Talk to yourself like you'd talk to a friend. If you wouldn't say it to your best friend or your daughter, don't say it to yourself.

Focus on what your body does. It carries you, hugs people, climbs stairs, heals. Gratitude for function is a powerful antidote to criticism of looks.

Move for joy, not punishment. Dance, walk, swim, stretch. Exercise that feels good, not exercise to fix something.

And if thoughts about your body or food are taking over your life, please reach out. The National Alliance for Eating Disorders has a free helpline staffed by licensed therapists: one eight six six, six six two, one two three five.

Your body isn't a project. It's your home.
""")

talk("wtalk_eating", "Self-Worth", "When Food Feels Like a Fight",
     "Warning signs of an eating disorder, why it's not about willpower, and where to get help.", False,
     [("National Alliance for Eating Disorders: What Is an Eating Disorder Helpline?", "https://www.allianceforeatingdisorders.com/what-is-an-eating-disorder-helpline/"),
      ("womenshealth.gov: National Eating Disorders Awareness Week", "https://womenshealth.gov/topics/national-eating-disorders-awareness-week")], """
This talk is for anyone who feels like food has become a battle. And it's also for anyone worried about someone they love.

Eating disorders are serious mental health conditions, and they're not about vanity or willpower. They can affect anyone, at any age, any body size, any background. And they often start quietly. A diet that becomes rigid. Rules about food that keep getting stricter. Exercising to make up for eating. Eating in secret, or feeling out of control around food and then deeply ashamed afterward. Thinking about food, weight, or your body almost all the time.

Some warning signs to notice, in yourself or someone else. Skipping meals or making excuses not to eat with others. Big swings in eating, like restricting and then bingeing. Going to the bathroom right after meals. Intense fear of gaining weight. Exercising even when sick or injured. Feeling that your worth depends on what you ate today, or what the scale said.

Here's what's important to understand. Eating disorders often grow out of a need to feel in control, especially when life feels overwhelming. They can be tied up with anxiety, depression, trauma, or perfectionism. And they're very treatable, especially when caught early. Recovery is absolutely possible.

You don't have to be in crisis, or have a certain diagnosis, to reach out. The National Alliance for Eating Disorders runs a free helpline staffed by licensed therapists who specialize in eating disorders. They can talk through what you're experiencing and help you find treatment. That number is one eight six six, six six two, one two three five. It's open weekdays, nine to seven Eastern.

Here's what I want you to take with you.

If something here sounded like you, that's worth paying attention to. Not with shame. With care.

Tell someone you trust. Eating disorders thrive in secrecy. Saying it out loud is often the turning point.

Talk to your doctor. Eating disorders can affect your heart, your bones, and your whole body, so it's important to get checked.

If you're worried about someone else, approach them gently and privately. Lead with care, not comments about their weight or food. Tell them what you've noticed, and that you're there for them.

And if you're having thoughts of harming yourself, or not wanting to be here, call or text nine eight eight right away.

You deserve peace with food. And you deserve help finding it.
""")

talk("wtalk_mental_load", "Burnout", "The Invisible To-Do List",
     "Running the household in your head on top of everything else. Burnout, the mental load, and relief.", False,
     [("World Health Organization: Burn-out an occupational phenomenon (ICD-11)", "https://www.who.int/news/item/28-05-2019-burn-out-an-occupational-phenomenon-international-classification-of-diseases")], """
Let's talk about the to-do list that lives in your head. The one nobody else sees.

The dentist appointment that needs scheduling. The birthday gift for the party Saturday. The kid who needs new shoes. What's for dinner, and is there enough for lunches tomorrow. Whether your mom took her medication. The bill that's due Thursday. And all of that is running in the background while you do your actual job.

People call it the mental load. It's the planning, remembering, organizing, and worrying that keeps a household running. And a lot of women carry most of it, even in homes where both partners work, and even where the other person is willing to help. Because helping when asked still means someone has to do the asking, the noticing, and the managing.

Over time, carrying all that can lead to burnout. The World Health Organization defines burnout in the context of work, as chronic workplace stress that hasn't been managed. It describes three parts: exhaustion, feeling distant or cynical, and feeling less effective. A lot of women recognize those exact feelings, coming from the combination of a job and running a home.

So if you're tired in a way that sleep doesn't fix, snapping at people you love, or feeling like you're failing at everything even though you're doing so much, you're not imagining it.

Here's what I want you to take with you.

Get the list out of your head. Write it all down. Every single thing. Seeing it on paper helps you and others understand how much there is.

Hand off whole jobs, not tasks. Instead of asking someone to buy the shoes, let them own everything about the kids' clothes. Noticing, planning and doing. That's what actually lightens the load.

Let some things be good enough. Store-bought cupcakes are fine. Not every load of laundry needs folding the same day.

Protect a little time that's only yours. Even thirty minutes, a few times a week, that isn't about being useful to anyone.

Say no to one thing this week. You're allowed.

And watch for signs of depression. If rest isn't helping, you're losing interest in everything, or feeling hopeless, talk to your doctor. If you ever have thoughts of not wanting to be here, call or text nine eight eight.

You're not supposed to carry it all alone. Put some of it down.
""")

talk("wtalk_caregiving", "Burnout", "Caring for Everyone But You",
     "63 million Americans are family caregivers, and two in three feel the stress. How to keep going.", False,
     [("AARP & National Alliance for Caregiving: Caregiving in the US 2025", "https://www.aarp.org/caregiving/basics/caregiving-in-us-survey-2025/"),
      ("American Psychiatric Association: Supporting the Mental Health of Family Caregivers", "https://psychiatry.org/News-room/APA-Blogs/Supporting-the-Mental-Health-of-Family-Caregivers")], """
If you're taking care of an aging parent, a sick partner, or a child with special needs, on top of everything else in your life, this one's for you.

You're part of a very large group. A 2025 report from AARP and the National Alliance for Caregiving found that about sixty-three million Americans are now family caregivers. That's nearly one in four adults, and about twenty million more than in 2015. Many of them are in the sandwich generation, caring for kids and aging parents at the same time.

And it's taking a toll. According to that report, as summarized by the American Psychiatric Association, about two in three caregivers experience high emotional stress, nearly half report physical strain, and about one in four feel isolated and alone. Nearly a quarter say they struggle to take care of their own health.

If you're a caregiver, you probably know this already. The appointments. The medications. The phone calls with insurance. The guilt that you're not doing enough, and the guilt when you take a break. The grief of watching someone you love decline. The resentment you feel bad about feeling.

Here's what I want you to take with you.

Your feelings are normal. Exhaustion, frustration, sadness, even resentment are common caregiver feelings. They don't mean you don't love them.

Ask for specific help. Instead of, let me know if you need anything, try, can you sit with Mom on Tuesday afternoon? Specific asks get real yeses.

Look into respite care. That's short-term care that gives you a break. Ask your loved one's doctor, a hospital social worker, or your local Area Agency on Aging what's available.

Check your benefits. Some employers now offer caregiving support, flexible hours, or leave. It's worth asking.

Keep your own appointments. Your health matters too. If you go down, everyone you care for is affected.

Find other caregivers. Support groups, in person or online, can be a lifeline. People who get it.

And watch for signs of depression or burnout. If you're feeling hopeless, numb, or overwhelmed most days, talk to your doctor. If you ever have thoughts of not wanting to be here, call or text nine eight eight.

Taking care of yourself isn't selfish. It's how you keep being able to take care of them.
""")

talk("wtalk_people_pleasing", "Self-Worth", "Learning to Say No",
     "If you always put everyone first and feel guilty saying no, here's how to set kind, clear limits.", False,
     [("American Psychological Association: Stress in America 2025, A crisis of connection", "https://www.apa.org/pubs/reports/stress-in-america/2025")], """
Let's talk about saying yes when you really want to say no.

Yes to the extra project at work. Yes to hosting the holiday again. Yes to the friend who always needs a favor. Yes to staying late, driving across town, covering for someone, and being the one who keeps everybody happy. And then lying awake, exhausted and a little resentful, wondering why you never have any time for yourself.

A lot of women are raised to be helpful, agreeable, and easy to be around. Those are good qualities. But when you can't say no, they turn into a trap. You end up giving away your time and energy until there's nothing left, and your own needs fall to the bottom of the list.

And many of us aren't getting much back. In the American Psychological Association's 2025 Stress in America survey, about seven in ten adults said they needed more emotional support in the past year than they received. When you're always the one giving, that gap gets wide.

Here's something worth hearing. Saying no isn't selfish, and it isn't mean. A boundary is just a clear line that protects your time, your energy, and your relationships. Healthy relationships can handle a no. And honestly, people tend to trust your yes more when they know you can say no.

Here's what I want you to take with you.

Pause before you answer. Try, let me check my calendar and get back to you. That gives you space to decide what you actually want.

Keep it short. You don't need a long explanation. I'm not able to take that on right now, is a complete sentence.

Offer an alternative if you want to. I can't host this year, but I'd love to bring dessert.

Expect some discomfort. The first few times you set a boundary, you'll probably feel guilty. That's normal. It doesn't mean you're doing something wrong. It means you're doing something new.

Notice who respects your limits. The people who care about you will adjust. The ones who push back hard are showing you something important.

Start small. Say no to one small thing this week. See how it feels.

You're allowed to have needs. You're allowed to protect your time. You matter too.
""")

talk("wtalk_loneliness", "Loneliness", "Lonely in a Full Life",
     "You can be surrounded by people and still feel alone. Why connection matters, and how to rebuild it.", False,
     [("U.S. Surgeon General Advisory: Our Epidemic of Loneliness and Isolation (2023)", "https://www.hhs.gov/sites/default/files/surgeon-general-social-connection-advisory.pdf"),
      ("Survey Center on American Life: The State of American Friendship (2021)", "https://www.americansurveycenter.org/commentary/american-men-suffer-a-friendship-recession/")], """
Here's something a lot of women don't say out loud. You can have a partner, kids, coworkers, and a phone full of contacts, and still feel deeply lonely.

Maybe your friends drifted after you had kids, or moved, or changed jobs. Maybe your days are so full of taking care of people that there's no time for anyone who takes care of you. Maybe you have plenty of people around you, but nobody who really knows what's going on inside.

You're not alone in feeling alone. A national survey from the Survey Center on American Life found that in 2021, about one in ten women said they had no close friends, and the share of women with six or more close friends had dropped since 1990.

And loneliness isn't just a sad feeling. In 2023, the U.S. Surgeon General issued an official advisory calling loneliness and isolation a public health epidemic. It warned that lacking social connection raises the risk of heart disease, stroke, depression, anxiety, and dementia, with a risk of early death comparable to smoking up to fifteen cigarettes a day.

The advisory made another point that matters. Loneliness is about the quality of your connections, not just the number. That's why you can feel it even in a full house.

Here's what I want you to take with you.

Reach out to one person this week. An old friend, a cousin, a neighbor. Something simple. I've been thinking about you. Want to grab coffee?

Make it regular. A standing walk, a monthly dinner, a weekly call. Friendship grows from repetition.

Go a little deeper. When someone asks how you are, try answering honestly sometimes. Vulnerability invites closeness.

Join something around an interest. A class, a book club, a walking group, a volunteer shift. Shared activities make connection easier.

Put the phone down when you're with people. Scrolling can make you feel more connected while actually making you lonelier.

And if loneliness has turned into a heavy, persistent low mood, talk to your doctor. If you ever have thoughts of not wanting to be here, call or text nine eight eight.

You deserve to be known, not just needed.
""")

talk("wtalk_relationship", "Self-Worth", "When the Relationship Hurts",
     "Breakups, divorce, or a relationship that's struggling. How to take care of yourself through it.", False,
     [("American Psychological Association: Stress in America 2025, A crisis of connection", "https://www.apa.org/pubs/reports/stress-in-america/2025")], """
Relationships can bring the most joy in life, and the most pain. If you're going through a breakup, a divorce, or a relationship that just feels hard right now, this one's for you.

Maybe it ended and you're trying to figure out who you are without them. Maybe you're still together, but it feels like you're roommates, or you're fighting about the same things over and over. Maybe you're the one who left, and you're surprised by how much it still hurts.

Whatever it is, it's a real loss, or a real strain, and it can shake your sense of yourself. Your routines change. Your plans for the future change. Sometimes your home, your money, and your time with your kids change too.

And a lot of women go through it without enough support. In the American Psychological Association's 2025 Stress in America survey, about seven in ten adults said they needed more emotional support than they got in the past year.

Here's what I want you to take with you.

Let yourself feel it. Sad, angry, relieved, confused, all at once. Grief after a relationship is normal, even if you were the one who ended it.

Lean on your people. This is the time to call your sister, your best friend, your mom. Tell them what's going on. Let them help.

Keep your basics steady. Sleep, meals, movement, work. Structure helps when everything else feels upside down.

Don't decide your worth based on this. A relationship ending doesn't mean you weren't enough.

If you have kids, protect them from the conflict. Keep them out of the middle. A family therapist or mediator can help with co-parenting.

If you're still together and struggling, consider couples counseling. Many couples find it helps them communicate and reconnect. You can also go on your own.

And know the difference between hard and unsafe. If your partner controls you, threatens you, or hurts you, that's not a rough patch. The National Domestic Violence Hotline is free and confidential: one eight hundred, seven nine nine, seven two three three. You can also text the word START to eight eight seven eight eight.

And if you ever have thoughts of not wanting to be here, call or text nine eight eight.

This chapter may be ending, or changing. Your story isn't over.
""")

talk("wtalk_safety", "Self-Worth", "Is This Love, or Control?",
     "Abuse isn't always physical. Signs of an unhealthy relationship, and how to get confidential help.", False,
     [("National Domestic Violence Hotline", "https://www.thehotline.org")], """
Before we start, if you're listening somewhere you could be overheard or watched, it's okay to stop this and come back when you're safe.

Let's talk about something that's hard to see from the inside. A relationship that's slowly become controlling, frightening, or hurtful.

Abuse isn't always hitting. A lot of the time it starts in quieter ways. Checking your phone. Telling you what to wear, or who you can see. Getting angry if you spend time with friends or family, until you just stop seeing them. Controlling the money so you can't make decisions. Putting you down, calling you names, making you feel crazy, or telling you nobody else would ever want you. Threatening to leave, to take the kids, or to hurt themselves or you. And sometimes it does turn physical, or sexual.

One of the hardest parts is that it often comes mixed with love, apologies, and good times. So you start to doubt yourself. Maybe I'm overreacting. Maybe if I just try harder.

If any of this sounds familiar, please hear this. It's not your fault. You don't deserve to be treated this way. And you're not alone.

The National Domestic Violence Hotline is free, confidential, and available twenty-four hours a day. You can call one eight hundred, seven nine nine, S A F E. That's one eight hundred, seven nine nine, seven two three three. You can also text the word START to eight eight seven eight eight, or chat on their website, thehotline dot org. You don't have to be ready to leave to call. They can just listen, and help you think through your options and a safety plan.

Here's what I want you to take with you.

Trust what you feel. If you feel afraid, small, or like you're walking on eggshells, that matters.

You don't need to decide everything today. Just reaching out to someone safe is a big step.

Make a safety plan with an advocate. Things like a code word with a friend, important documents in one place, and a safe place to go.

Be careful with your devices. If someone may be checking your phone, use a safer phone or computer, and clear your history when needed.

If you're in immediate danger, call nine one one.

And if you're struggling with thoughts of not wanting to be here, call or text nine eight eight.

You deserve to feel safe at home. Help is real, and it's confidential.
""")

talk("wtalk_grief", "Grief", "Living With Loss",
     "Grief comes in waves and doesn't keep a schedule. When it's normal, and when to get more help.", False,
     [("American Psychiatric Association: Prolonged Grief Disorder", "https://www.psychiatry.org/patients-families/prolonged-grief-disorder")], """
When someone you love dies, the world can feel like it should stop. But it doesn't. The bills still come. People go back to their lives. And you're left trying to figure out how to keep going with a hole where that person used to be.

Grief is one of the most human experiences there is. And it rarely follows a neat path. You might feel sad, angry, numb, guilty, relieved, or all of those in one afternoon. You might be okay for a week, then a song in the grocery store knocks you to your knees. Holidays, birthdays, and anniversaries can bring it all rushing back. That's normal. It doesn't mean you're going backward.

For most people, the intensity of grief slowly softens over time. Not because the love fades, but because you gradually learn to carry it.

But for some people, grief stays stuck at full strength. In 2022, the American Psychiatric Association added a diagnosis called prolonged grief disorder. For adults, it's when, at least a year after the loss, intense longing for the person, or being consumed by thoughts of them, continues nearly every day and makes it hard to function. The APA estimates that about seven to ten percent of bereaved adults experience it. And importantly, there are specific, effective therapies for it.

Here's what I want you to take with you.

There's no right way or right timeline to grieve. Yours is yours.

Say their name. Tell stories. Look at photos. Keeping their memory alive is part of healthy grieving.

Let people in. Grief can make you want to withdraw. Even one person to talk to makes a difference. Grief support groups can help too.

Take care of your body. Grief is exhausting. Try to eat, sleep, and move, even a little.

Be ready for the hard days. Plan ahead for anniversaries and holidays. Do something meaningful, or give yourself permission to skip things.

If you were a caregiver, give yourself extra gentleness. You may be grieving the person and the role at the same time.

And if a year has passed and you're still stuck, or you're having thoughts of not wanting to be here, please talk to your doctor or a grief counselor. If you're in crisis, call or text nine eight eight.

Grief is love that's still looking for them. Let it be part of you.
""")

talk("wtalk_adhd", "Self-Worth", "Maybe It's Not a Character Flaw",
     "Many women with ADHD are diagnosed years later than men, often after years of anxiety. Signs to know.", False,
     [("PsyPost (2025): Women with ADHD are diagnosed later and experience more severe symptoms (European Psychiatry study)", "https://www.psypost.org/women-with-adhd-are-diagnosed-later-and-experience-more-severe-symptoms/"),
      ("Psychiatric Times (2025): Women are diagnosed with ADHD 5 years later than men", "https://www.psychiatrictimes.com/view/women-are-diagnosed-with-adhd-5-years-later-than-men")], """
Have you spent years feeling like you're always behind? Always late, always losing things, always one forgotten email away from disaster? Do you start ten projects and finish two? Do you feel like everyone else got a manual for life that you never received? And have you blamed yourself, calling it laziness, or being a mess?

For some women, there's a reason behind it that nobody ever named. ADHD.

ADHD used to be seen as something hyperactive little boys had. But it's now understood that it often looks different in girls and women, and they're often missed. Instead of bouncing off the walls, many girls are dreamy, distracted, talkative, or anxious. They work twice as hard to keep up, and they hide their struggles.

A 2025 study published in the journal European Psychiatry found that although ADHD symptoms started at about the same age in men and women, women were diagnosed much later. On average, about age twenty-nine for women, compared with about twenty-four for men. And by the time they were diagnosed, women reported more severe symptoms. Researchers also note that many women are first treated for anxiety or depression for years, before anyone recognizes the ADHD underneath.

Some common signs in adult women. Trouble keeping track of time, appointments, and details. Feeling overwhelmed by household tasks and paperwork. Starting things and not finishing. Getting intensely focused on things that interest you and unable to start things that don't. Emotional ups and downs. And a lot of shame about it all.

Here's what I want you to take with you.

If this sounds like you, it's worth getting evaluated. Ask your doctor for a referral to someone who assesses adult ADHD. Bring examples from childhood and your life now.

A diagnosis isn't an excuse. It's an explanation. And many women describe it as a huge relief, like their life finally makes sense.

Treatment can help a lot. That might include medication, therapy, coaching, and practical systems built for how your brain works.

Drop the shame. Not finishing things doesn't make you lazy. Your brain may just work differently.

Use outside structure. Reminders, alarms, calendars, body doubling, breaking tasks into tiny steps. These aren't crutches. They're tools.

And if you've been struggling with depression or anxiety, keep getting help for those too. They often come along with ADHD.

You're not broken. You might just finally be understood.
""")

talk("wtalk_sleep", "Anxiety", "The 2 a.m. Mind",
     "When your body is tired but your mind won't stop. How sleep and mood feed each other, and what helps.", False,
     [("CDC NCHS Data Brief 559: Short Sleep Duration Among Adults, 2024", "https://www.cdc.gov/nchs/products/databriefs/db559.htm"),
      ("CDC Preventing Chronic Disease (2021): Effect of inadequate sleep on frequent mental distress", "https://www.cdc.gov/pcd/issues/2021/20_0573.htm")], """
You finally get everyone to bed. The house is quiet. You lie down, completely exhausted. And then your brain switches on. The thing you forgot to do. The conversation you keep replaying. Tomorrow's schedule. That weird pain. The kids. Your mom. Money.

For a lot of women, nighttime is the only quiet moment of the day, so that's when all the worries come out.

And you're definitely not alone in being short on sleep. A CDC report from this past April, using 2024 data, found that about thirty percent of American adults sleep less than seven hours on average. Experts recommend at least seven.

Sleep and mental health are deeply connected. A CDC study of more than two hundred seventy thousand adults found that people who averaged six hours of sleep or less were about two and a half times more likely to report frequent mental distress. And it goes both ways. Anxiety and depression make sleep harder, and poor sleep makes anxiety and depression worse.

The good news is that you can break the cycle.

Here's what I want you to take with you.

Give your worries an appointment. Earlier in the evening, take ten minutes to write down everything on your mind, and one next step for each. Then close the notebook. When the thoughts come at night, remind yourself, it's written down. I'll deal with it tomorrow.

Keep the same wake time every day, even weekends. It's the most powerful way to steady your sleep.

Get morning light. A few minutes outside soon after you wake up helps set your body clock.

Create a wind-down routine. Dim lights, a warm shower, stretching, a book. Same order each night, so your body learns it's time to sleep.

Keep screens out of bed if you can. The light and the scrolling both keep your brain alert.

If you can't sleep, get up after about twenty minutes. Do something calm in low light, then go back to bed when you feel sleepy.

Watch afternoon caffeine and evening alcohol. Both disrupt sleep.

And talk to your doctor if sleep has been a problem most nights for weeks. Insomnia has very effective treatments, including a type of therapy called CBT-I. Hormone changes, like perimenopause, can also play a role.

Your mind deserves rest too. You can teach it how to let go at night.
""")

# ───────────── Divorce and separation (women) ─────────────
APA_DIV = ("American Psychological Association: Healthy divorce, how to make your split as smooth as possible", "https://www.apa.org/topics/healthy-divorce")
CDC_DIV = ("CDC NCHS FastStats: Marriage and Divorce", "https://www.cdc.gov/nchs/fastats/marriage-divorce.htm")
AAP_TALK = ("American Academy of Pediatrics, HealthyChildren.org: How to Talk to Your Children about Divorce", "https://www.healthychildren.org/English/healthy-living/emotional-wellness/Building-Resilience/Pages/How-to-Talk-to-Your-Children-about-Divorce.aspx")
AAP_ADJ = ("American Academy of Pediatrics, HealthyChildren.org: Divorce and Separation, How to Help Your Child Adjust", "https://www.healthychildren.org/English/family-life/family-dynamics/types-of-families/Pages/Adjusting-to-Divorce.aspx")
AAP_SUP = ("American Academy of Pediatrics, HealthyChildren.org: How to Support Children after Parents Separate or Divorce", "https://www.healthychildren.org/English/healthy-living/emotional-wellness/Building-Resilience/Pages/How-to-Support-Children-after-Parents-Separate-or-Divorce.aspx")
AACAP = ("American Academy of Child and Adolescent Psychiatry, Facts for Families: Children and Divorce", "https://www.aacap.org/AACAP/Families_and_Youth/Facts_for_Families/FFF-Guide/Children-and-Divorce-001.aspx")
UMICH = ("University of Michigan Population Studies Center (July 2025): Economic consequences of divorce vary by gender, race and ethnicity", "https://psc.isr.umich.edu/news/research-shows-economic-consequences-of-divorce-in-the-us-vary-by-gender-race-and-ethnicity/")
SG = ("U.S. Surgeon General Advisory (2023): Our Epidemic of Loneliness and Isolation", "https://www.hhs.gov/sites/default/files/surgeon-general-social-connection-advisory.pdf")
FTC_ROM = ("FTC data via Axios (Feb 2024): Romance scams reported in 2023", "https://www.axios.com/2024/02/13/charted-love-can-hurt-closer")

talk("wtalk_div_first_months", "Divorce", "The First Months After the Split",
     "Grief, relief, rage and fear, sometimes all before lunch. How to get through the early months.", False,
     [APA_DIV, CDC_DIV, ("National Domestic Violence Hotline", "https://www.thehotline.org/")], """
If your marriage just ended, or it's ending right now, this is for you. Let's talk about the first few months, because they're often the hardest.

You're far from alone. In 2023, the CDC counted about six hundred seventy thousand divorces in this country, and that's not even counting a few states that don't report. Behind every one of those numbers is someone lying awake, replaying conversations, wondering what comes next.

The American Psychological Association says the end of a marriage usually unleashes a flood of emotions, including anger, grief, anxiety and fear. And here's what surprises a lot of women. You might also feel relief. Or guilt about feeling relief. Or miss him on Monday and be furious at him by Wednesday. All of it is normal. Grief after divorce isn't a straight line.

It's also exhausting. You may be handling lawyers, paperwork, a move, kids who are upset, and a job, all while running on four hours of sleep. No wonder it feels like too much.

Here's what I want you to take with you.

Lower the bar for now. This is a season for survival, not perfection. Cereal for dinner sometimes is fine.

Protect your sleep, eat real food, and move your body a little every day. It sounds basic. It's what keeps you standing.

Pick your people. Two or three friends you can call at ten at night and say, I'm not okay. The APA says leaning on your support network matters. Let them help.

Write things down. The APA notes it's hard to remember important details when emotions are running high. Keep a notebook for dates, agreements, and questions for your lawyer.

Think about mediation instead of a courtroom fight, if it's safe to do so. The APA says mediation is often a good alternative, and less conflict is better for you and your kids.

Talk to a therapist. A counselor can help you grieve, think clearly, and make decisions you won't regret.

And one important note. If you're leaving a relationship where you've been hurt, threatened, or controlled, your safety comes first. Call the National Domestic Violence Hotline at one eight hundred, seven nine nine, seven two three three, or text the word START to eight eight seven eight eight. And if you ever have thoughts of not wanting to be here, call or text nine eight eight.

This is the hardest stretch. It does get lighter. One day at a time.
""")

talk("wtalk_div_coparent", "Divorce", "Co-Parenting Without Fighting",
     "You can't control your ex. You can control the temperature. How to keep the kids out of the middle.", False,
     [AAP_SUP, AAP_ADJ, APA_DIV], """
Let's talk about one of the hardest parts of divorce when you have kids. You're not married to him anymore, but you're still raising children with him. How do you do that without it turning into a war?

Start with the good news from the research. The American Academy of Pediatrics says many kids have painful feelings after a divorce, and many bounce back within two to three years. Kids are more resilient and less stressed when there's less conflict between their parents.

So the biggest thing you can do for your kids isn't keeping the marriage together. It's keeping the fighting down. Ongoing conflict between parents is what hurts kids most.

The AAP is clear. Never involve your kids in your arguments, and never force them to take sides. They love both parents. Even if you feel he doesn't deserve that love right now, they need it.

What does that look like day to day?

It means no venting about their dad where they can hear. Not on the phone, not to your sister, not under your breath. Kids hear everything.

It means not asking them to spy. Did daddy have anyone over? Keep those questions to yourself.

It means talking to your ex directly about schedules and money, or through email or a co-parenting app. Not through the kids.

It means keeping handoffs calm and short. A smile for the kids, a quick update for him, and done.

The AAP says kids thrive with warmth and consistent boundaries. Your house doesn't have to match his. It just has to be steady and loving.

And if every conversation with your ex turns into a fight, you can try parallel parenting. You each run your own home your own way, contact stays brief and focused on the kids, and everything important goes in writing. A mediator can help set the schedule. And if there's been abuse or threats, talk to a lawyer about safe exchanges and protections. Your safety matters.

Here's what I want you to take with you.

The fighting hurts kids more than the two homes do.

No bad-mouthing, no spying, no messengers.

Keep it short, calm and in writing with your ex.

Be the steady, warm house.

You can't control how he acts. But you can control the temperature on your side. And your kids will feel the difference.
""")

talk("wtalk_div_kids", "Divorce", "Telling the Kids",
     "What to say, when to say it, and the one thing every child needs to hear more than once.", False,
     [AAP_TALK, AAP_ADJ, AACAP], """
How do you tell your kids that their family is changing? It might be the conversation you're dreading most. Here's what the experts recommend.

Don't keep it a secret, and don't wait until the last minute. The American Academy of Child and Adolescent Psychiatry says kids should hear it before things change. Children often sense the tension anyway. When they don't get answers, they make up their own, and they often blame themselves.

If you can, tell them together, with their dad. One message, both parents. It shows them that even though you won't be married, you're both still their parents. If that's not safe or possible, that's okay. Tell them yourself, calmly.

Keep it simple and fit it to their age. For little ones, something like, mommy and daddy are going to live in two different houses, and we both love you very much. Older kids can hear a little more, but they don't need the adult details. The reasons for the divorce are grown-up business.

The American Academy of Pediatrics says to make sure your kids know it's not their fault, and that they can't fix it or get you back together. Young kids especially need to hear this again and again. The AAP also suggests extra affection and keeping routines steady for little ones.

Kids mostly want to know if they'll be safe. Where will I sleep? Will I still see Dad? Do I have to change schools? Have answers ready for what you know, and be honest about what you don't. We're still figuring that out, and we'll tell you as soon as we know.

Then let them react. Some kids cry, some get angry, some shrug and ask what's for dinner. All of that is normal. The AAP says the earlier you tell them and the more often you talk, the more comfortable they'll feel. Let them share their worries.

Here's what I want you to take with you.

Tell them early and simply, together if you can.

Say the words they need. It's not your fault. You can't fix it. We both love you, and that won't change.

Answer the practical questions. Where they'll live, when they'll see each parent.

Keep blame out of it, even if it's hard.

Keep talking. This is a conversation, not an announcement.

And if your child is still struggling a lot after a few months, talk to their pediatrician. A kids' counselor can help them work through it.
""")

talk("wtalk_div_money", "Divorce", "Money Stress After Divorce",
     "Women's family income drops about half after divorce. Here's how to get your footing back.", False,
     [UMICH, APA_DIV], """
Let's talk honestly about money after divorce, because for a lot of women, this is where the fear lives.

Here's what the research shows. A University of Michigan study, released in July 2025, found that women's family income dropped by forty-six to fifty percent after divorce. That's nearly double the drop men experienced. And that's even though women often carry more of the costs of raising the kids. The researchers also found many women increase their hours at work after a split, just to stay afloat.

So if you're scared about money right now, you're not being dramatic. You're seeing clearly. And seeing clearly is the first step to fixing it.

Here's what I want you to take with you.

Know your numbers. Every account, every debt, the mortgage, the car loan, the retirement accounts, the insurance. If he handled the money in your marriage, this might feel overwhelming. That's okay. Pull statements, make a list, and learn it one piece at a time.

Open accounts in your own name. A checking account, a savings account, a credit card. Building your own credit history matters for renting, buying, and borrowing later.

Make a survival budget for the next six months. Housing, food, utilities, childcare, transportation, insurance. Everything else can wait.

Don't give up your fair share to make the fighting stop. A lot of women sign away things they need just to get it over with. Talk to a family law attorney before you agree to anything. Many areas have legal aid if money is tight. The APA says mediation can also be a calmer, less expensive path than a courtroom battle.

Ask about child support and make sure it's set up through the proper channels, so it's tracked and enforceable.

Check your health insurance. If you were on his plan, find out your options early, so you're not left without coverage.

Update the paperwork. Beneficiaries, your will, passwords, and who has access to your accounts.

Get help with the plan. A fee-only financial planner or a nonprofit credit counselor can help you build a path forward.

And if money stress is turning into hopelessness, talk to someone. If you ever think about not being here, call or text nine eight eight.

This is a hard season, not a life sentence. Many women rebuild stronger, because now every decision is theirs.
""")

talk("wtalk_div_empty_house", "Divorce", "Loneliness and the Empty House",
     "The kids are at their dad's and the house is too quiet. How to fill the space without numbing it.", False,
     [SG, APA_DIV], """
Let's talk about the nights when the house is too quiet. The kids are at their dad's for the weekend. The dishes are done. And there's no one to talk to. Even if the marriage was lonely, this kind of alone can feel brand new.

Loneliness is one of the most common and least talked about parts of divorce. And it's not just in your head. In 2023, the U.S. Surgeon General put out an advisory on loneliness. It found that about half of American adults report feeling lonely, and that lacking social connection raises the risk of dying early by about as much as smoking up to fifteen cigarettes a day. Connection isn't a luxury. It's health.

Divorce can shrink your world fast. Couple friends pick sides or drift away. Family holidays change. Maybe you moved, and you don't know anyone in the new neighborhood. And on the weeks without your kids, the silence can feel like a weight.

Here's what I want you to take with you.

Plan the kid-free weekends ahead of time. Don't wait to see how you feel. Put something on the calendar. Coffee with a friend, a class, a hike, a volunteer shift.

Reach out first. It's easy to wait for people to call. Most people want to help but don't know how. Text one friend today and say, I could really use some company this week.

Find your regulars. A book club, a gym class, a walking group, a divorce support group. Same faces, same time each week. That's where real friendships grow.

Let yourself grieve, but don't hide. Some nights a good cry and an early bedtime is exactly right. But if you're isolating for days at a time, that's a sign to reach out.

Make the space yours. Rearrange the furniture. Paint a wall. Make it feel like home for the life you're building now.

Watch for numbing. A few more glasses of wine, hours of scrolling, shopping you can't afford. Those can be loneliness looking for a quick fix.

And if the loneliness turns into a sadness that won't lift for weeks, talk to your doctor or a therapist. The APA says a psychologist can help you work through the emotions of a divorce. If you ever think about not wanting to be here, call or text nine eight eight.

The quiet is temporary. You're not starting over from nothing. You're starting over from experience.
""")

talk("wtalk_div_dating", "Divorce", "Dating Again",
     "Ready or not, how to tell, how to protect your heart and your kids, and how to spot a scam.", False,
     [APA_DIV, FTC_ROM, AAP_ADJ], """
Maybe it's been a few months. Maybe a few years. Maybe your friends keep telling you to get back out there, and you're not sure. Let's talk about dating again after divorce.

First, how do you know if you're ready? Ask yourself a few questions. Can you talk about your ex without your chest tightening? Do you want someone to share your life with, or someone to make the pain stop? Are you dating to prove something to him? If it's mostly about filling a hole, give it a little more time. There's no deadline, and nobody else gets to set one for you.

Second, look back before you look forward. The American Psychological Association says a psychologist can help you think carefully about what went wrong in your marriage, so you can avoid repeating the same patterns in your next relationship. That's not about blaming yourself. It's about learning what you need, what you won't accept again, and what red flags you might have ignored.

Third, protect your kids. Keep dating separate from them in the early stages. Wait until a relationship is serious and stable before introducing anyone. The American Academy of Pediatrics says kids need routines and consistency after a divorce. Meeting a string of new people can shake that.

Fourth, be careful online. People told the FTC they lost more than a billion dollars to romance scams in 2023. Scammers look for people who are lonely and going through a big change. The pattern is always similar. They're charming and move fast, they say I love you quickly, they can't meet in person or do a video call, and then there's an emergency and they need money. Gift cards, crypto, a wire transfer. Never send money to someone you haven't met in person.

And trust your gut on safety. Meet in public, drive yourself, tell a friend where you'll be.

Here's what I want you to take with you.

Date when you're curious and steady, not when you're desperate or trying to prove something.

Learn your patterns first. A counselor can help.

Keep new partners away from the kids until it's real.

Never send money to someone online, and meet in public.

And remember, your marriage ending doesn't mean you failed at love. It means you know more now about what a good partner looks like. Including the one you see in the mirror.
""")
