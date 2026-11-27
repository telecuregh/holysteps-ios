# Men's mental health talks. No faith content. Every figure is from a named, current source (listed per talk).
T = []
def talk(id, category, title, subtitle, free, sources, script):
    T.append(dict(id=id, hub="men", category=category, title=title, subtitle=subtitle, free=free,
                  sources=[dict(title=t, url=u) for t, u in sources], script=script.strip()))

talk("mtalk_depression", "Depression", "When It Doesn't Look Like Sadness",
     "Depression in men often shows up as anger, numbness or overwork. Here's how to spot it.", True,
     [("CDC NCHS Data Brief 564: Mental Health Treatment Among Adults, 2024", "https://www.cdc.gov/nchs/products/databriefs/db564.htm")], """
Let's talk about something a lot of guys miss in themselves. Depression doesn't always look like crying in bed. For a lot of men it looks like being short with everybody. It looks like working sixty hours so you don't have to sit still. It looks like a few more drinks than usual, or zoning out on your phone until two in the morning, or just feeling flat, like the color got turned down on your life.

And here's the thing. Men are a lot less likely to get help for it. The CDC put out a report in June of this year, using 2024 survey data, and it found that about thirteen percent of men took medication for their mental health in the past year, compared to about twenty-five percent of women. For counseling or therapy, it was about eleven percent of men versus seventeen percent of women. That gap isn't because men hurt less. It's because men wait longer, or never go at all.

So how do you know if it's more than a rough patch? Doctors look at whether it's been going on most days for two weeks or more. Losing interest in things you used to enjoy. Sleep that's way off, too much or too little. Feeling worthless or guilty. Trouble focusing. Low energy. Irritability counts too, especially for men.

If you're nodding along right now, that's not weakness. That's information. And depression is one of the most treatable things a doctor sees. Therapy works. Medication works for a lot of people. Exercise helps. Most guys who get treatment feel real relief, often within weeks.

Here's what I want you to take with you.

Notice the signs that don't look like sadness. Anger, numbness, overworking, drinking more. Those count.

Make one call. Your regular doctor is a fine place to start. You can literally say, I think I might be depressed, and they'll take it from there.

Tell one person. Not everybody. One. A text like, hey, I've been in a weird place lately, is enough to open the door.

And if it ever gets heavy enough that you think about not being here, call or text nine eight eight. Any time, day or night. Somebody will answer.

You don't have to feel this way forever. Getting help is how a lot of strong men got their lives back.
""")

talk("mtalk_dark_thoughts", "Depression", "If You've Thought About Not Being Here",
     "You're not the only one, and these thoughts can pass. What to do right now.", True,
     [("CDC: Suicide Data and Statistics", "https://www.cdc.gov/suicide/facts/data.html"),
      ("SAMHSA NSDUH 2024: Treatment among adults with serious thoughts of suicide", "https://www.samhsa.gov/data/sites/default/files/reports/rpt56991/2025-nsduh-mh-tx-adult-suicide.pdf")], """
If you're listening to this because you've had thoughts about not wanting to be alive, I'm really glad you pressed play. Stay with me for a few minutes.

First, you're not the only one. A national survey from SAMHSA estimated that in 2024, about fourteen million adults in this country had serious thoughts of suicide. Fourteen million. That's a lot of people sitting with the same heavy thing you are, most of them not saying it out loud.

And this hits men especially hard. The CDC reports that men make up about half the population but nearly eighty percent of suicide deaths. Men are also less likely to reach out first. So if you're a man feeling this, you're right in the middle of something a lot of men face, and a lot of men have come through.

Here's something important. These thoughts usually come in waves. They feel permanent when you're in them. They're not. The pain is real, but the feeling that it'll never change is the depression talking, not the truth.

If you're in that wave right now, here's what to do.

Call or text nine eight eight. That's the Suicide and Crisis Lifeline. It's free, it's confidential, and it's there twenty-four hours a day. You don't have to be on the edge to call. You can call because you're scared of your own thoughts. Veterans can press one.

If there's anything in your home you've thought about using to hurt yourself, put some distance between you and it. Ask a friend or family member to hold onto it for a while. That one step saves lives. Time and distance matter.

Tell one person. You can say, I've been having thoughts about not wanting to be here, and I need you to know. If saying it feels impossible, text it.

And if you're in immediate danger, call nine one one or go to the nearest emergency room.

Here's what I want you to take with you.

The wave passes. You don't have to fix your whole life tonight. You just have to get through tonight, and reach out.

Nine eight eight. Call or text. Any time.

Distance from anything that could hurt you. Ask someone to hold it.

One person. Tell one person.

You matter more than this moment is letting you believe. Make the call.
""")

talk("mtalk_anxiety", "Anxiety", "The Racing Mind",
     "Worry that won't shut off, a tight chest, and a brain stuck on what-ifs. How to slow it down.", False,
     [("NIMH: Panic Disorder, When Fear Overwhelms (CBT as first-line treatment)", "https://www.nimh.nih.gov/sites/default/files/documents/health/publications/panic-disorder-when-fear-overwhelms/22-MH-8077_PanicDisorder.pdf")], """
You know the feeling. You're lying in bed, or sitting at your desk, and your brain just won't quit. What if the deal falls through. What if the test results are bad. What if I'm messing up as a dad. One worry leads to the next, and your chest gets tight, and your jaw is clenched, and you didn't even notice it happening.

A lot of men don't call that anxiety. They call it stress, or being on edge, or just how they're wired. But when worry is running your days most of the time, and it's hard to control, and it's messing with your sleep or your focus or your body, that's worth paying attention to.

Here's what's actually going on. Your brain's alarm system is doing its job a little too well. It's built to protect you from danger. But it can't always tell the difference between a bear in the woods and an email from your boss. So it floods your body with the same stress response either way.

The good news is that anxiety is very treatable. Talk therapy, especially cognitive behavioral therapy, and medication both have strong evidence behind them. And there are things you can start doing today.

Try this right now. Breathe in through your nose for four counts. Hold for four. Breathe out slowly for four. Hold for four. That's called box breathing, and a lot of first responders and athletes use it. Do it a few rounds.

[PAUSE 8 SECONDS]

Here's what I want you to take with you.

Write the worries down. All of them. On paper they look smaller, and you can sort them into, things I can do something about, and things I can't.

Ask yourself, is there anything I can do about this right now? If the answer's no, give yourself permission to set it down until tomorrow.

Watch the caffeine and the alcohol. Both can make anxiety worse, especially alcohol the next day.

Move your body. A walk, a workout, anything. It burns off some of that stress chemistry.

And if anxiety is taking over your days for weeks at a time, see your doctor. You don't have to white knuckle this.

Your mind is trying to protect you. You can teach it to stand down.
""")

talk("mtalk_panic", "Anxiety", "What a Panic Attack Really Is",
     "Racing heart, can't breathe, sure something's wrong. What's happening and how to ride it out.", False,
     [("NIMH: Panic Disorder, When Fear Overwhelms", "https://www.nimh.nih.gov/sites/default/files/documents/health/publications/panic-disorder-when-fear-overwhelms/22-MH-8077_PanicDisorder.pdf"), ("Mayo Clinic: Panic attacks and panic disorder", "https://www.mayoclinic.org/health/panic-attacks/DS00338/DSECTION=1")], """
If you've ever had a panic attack, you know it's one of the scariest things a body can do. Out of nowhere your heart is pounding. You can't catch your breath. Your chest is tight, your hands are tingling, maybe you're sweating or shaking. And a lot of guys are sure they're having a heart attack. Plenty of men have ended up in the ER the first time it happened.

So first, a really important point. If you've never had these symptoms checked out, get checked. Chest pain and trouble breathing should always be looked at by a doctor at least once. Don't assume.

But if you've been checked, and it's panic, here's what's actually going on. Your body's alarm system fired at full blast, even though there's no real danger. It's the fight or flight response, the same one that would kick in if a car swerved at you. Your heart speeds up to pump blood to your muscles. Your breathing gets fast. It feels like you're dying. You're not. The Mayo Clinic notes that panic symptoms usually peak within minutes, and the National Institute of Mental Health describes attacks that last several minutes. Then it passes.

And here's the weird part. The more you fight it, the worse it tends to get. Because now you're scared of the fear itself.

So next time, try this. Instead of fighting it, name it. Say to yourself, this is a panic attack. It's uncomfortable, but it's not dangerous, and it will pass. Then slow your breathing down, especially the out breath. Breathe in for a count of four, and out for a count of six or seven.

Plant your feet on the floor. Feel the chair under you. Look around and name five things you can see. That brings your brain back into the room.

Here's what I want you to take with you.

Get checked by a doctor once, so you know what you're dealing with.

When it hits, name it. This is panic. It will pass.

Breathe out longer than you breathe in.

Don't start avoiding places just because you had an attack there. Avoidance makes panic grow.

And know that panic disorder is very treatable. Therapy, especially cognitive behavioral therapy, works really well for it. Talk to your doctor.

It feels like the end of the world. It's not. It's an alarm. And alarms can be reset.
""")

talk("mtalk_anger", "Anger", "Under the Anger",
     "Anger is usually covering something else. Learning to find it changes everything.", False,
     [("American Psychological Association: Control anger before it controls you", "https://www.apa.org/topics/anger/control")], """
Let's talk about anger. Not because anger is bad. It isn't. Anger is a normal human emotion, and sometimes it's exactly the right response. Something unfair happens, somebody crosses a line, and anger is what tells you something matters.

The problem is what happens when anger runs the show. When you're snapping at your kids over small stuff. When your partner walks on eggshells. When you punch a wall, or say things you can't take back, and then sit there afterward feeling awful.

Here's something psychologists talk about a lot. Anger is often a cover emotion. It shows up first because it feels powerful, but underneath it there's usually something softer. Fear. Embarrassment. Feeling disrespected. Feeling like you're failing. Being exhausted. For a lot of men, anger is the only emotion that felt acceptable growing up, so everything gets routed through it.

So next time you feel it rising, try asking one question. What's underneath this?

Maybe you're not really mad that the dishes aren't done. Maybe you're scared about money, and you haven't told anybody. Maybe you're not really mad at your son for being slow. Maybe you got chewed out at work and you're carrying it home.

The American Psychological Association suggests some practical things that help. Notice your early warning signs, like a hot face, a tight jaw, clenched fists. Take a timeout before you respond. Literally walk away for ten or twenty minutes. Slow your breathing. And when you come back, talk about what you need, not just what they did wrong.

Here's what I want you to take with you.

Know your warning signs. The earlier you catch it, the easier it is to steer.

Walk it off before you talk it out. Leave the room, go around the block, let your body come down.

Ask what's underneath. Find the fear or hurt under the heat.

When you blow it, repair it. Go back, own it, no excuses. I was wrong to yell. That wasn't about you. I'm sorry.

And if your anger is scaring the people you love, or it's getting physical, get help. A counselor can teach you real tools. Strong men work on this all the time.

Anger is a messenger. Listen to the message. Don't let it drive the truck.
""")

talk("mtalk_loneliness", "Loneliness", "The Friendship Recession",
     "Fewer men have close friends than ever. Why it matters for your health, and how to rebuild.", False,
     [("Survey Center on American Life: The State of American Friendship (2021)", "https://www.americansurveycenter.org/commentary/american-men-suffer-a-friendship-recession/"),
      ("U.S. Surgeon General Advisory: Our Epidemic of Loneliness and Isolation (2023)", "https://www.hhs.gov/sites/default/files/surgeon-general-social-connection-advisory.pdf")], """
Here's a question. If something really bad happened to you tonight, who would you call? Not your partner, not your mom. A friend. Who's the guy you'd call?

If you had to think about that for a while, you're not alone. Researchers have a name for what's happening to men right now. They call it the friendship recession. A national survey from the Survey Center on American Life found that in 2021, fifteen percent of American men said they had no close friends at all. Back in 1990, that number was three percent. It went up five times. And the share of men with at least six close friends dropped from more than half to about a quarter.

And this isn't just about being bored on Saturday nights. In 2023, the U.S. Surgeon General put out an official advisory on loneliness. It said that being socially disconnected carries a risk of early death comparable to smoking up to fifteen cigarettes a day. Loneliness is tied to heart disease, depression, anxiety, and dementia.

So why is this happening to men? Part of it is that a lot of men's friendships were built around school, sports, or work. When those end, the friendships kind of fade. And a lot of men don't feel comfortable reaching out just to talk. It can feel awkward, or needy.

But here's the good news. Friendship is a skill, and it can be rebuilt. And most other guys are waiting for someone else to make the first move.

Here's what I want you to take with you.

Pick one guy you've lost touch with. Send him a text today. Something simple. Hey man, been thinking about you. How are you doing?

Do things side by side. Men often bond best doing something together. Fishing, a pickup game, working on a car, a hike. Invite somebody along.

Make it regular. Same time every week or every month. Friendships grow from repetition, not one big night.

Go a little deeper than sports and work. Ask, how are you really doing? And answer that question honestly yourself when someone asks you.

Join something. A gym class, a rec league, a volunteer group, a men's group. Show up enough times and people become friends.

You weren't built to carry life alone. Go find your people.
""")

talk("mtalk_burnout", "Burnout", "Running on Empty at Work",
     "Exhausted, cynical, and feeling like nothing you do matters? That has a name.", False,
     [("World Health Organization: Burn-out an occupational phenomenon (ICD-11)", "https://www.who.int/news/item/28-05-2019-burn-out-an-occupational-phenomenon-international-classification-of-diseases")], """
Let's talk about burnout. Because a lot of men are running on fumes and calling it normal.

You know the signs. You're tired all the time, and sleep doesn't fix it. You used to care about your work, and now you just don't. You feel cynical, kind of checked out, maybe even resentful. And no matter how hard you push, it feels like it doesn't make a difference.

The World Health Organization actually defines this. In its international classification of diseases, the WHO describes burnout as a result of chronic workplace stress that hasn't been successfully managed. And it lists three parts. Feeling drained or exhausted. Feeling mentally distant from your job, or negative and cynical about it. And feeling like you're not effective anymore.

Notice that. Not managed. Burnout isn't a sign you're weak. It's a sign the load has been too heavy for too long without enough recovery.

And men often make it worse by doing the one thing that feels right. Pushing harder. More hours, more coffee, fewer days off. That's like fixing a dead battery by driving faster.

So what actually helps?

Start with the basics your body needs. Sleep. Real meals. Water. Some movement. Burnout lives in the body as much as the mind.

Look at your load. Make a list of everything you're carrying, at work and at home. Find one thing you can drop, delegate, or delay. Just one to start.

Talk to your boss, if it's safe to. A lot of managers would rather adjust a workload than lose a good worker. Come with a specific ask.

Protect some time that's yours. An evening a week, a morning, an hour on Saturday. Something that has nothing to do with being useful.

And watch the line between burnout and depression. If rest doesn't help, if you're feeling hopeless, or you're losing interest in everything, not just work, see your doctor. Those can overlap.

Here's what I want you to take with you.

Burnout is what happens when you give and give and nothing gets put back in. Even the strongest engine needs fuel.

Rest is not quitting. It's maintenance.

Drop one thing this week. Then see how it feels.

And if you ever start thinking about not wanting to be here, call or text nine eight eight.

You can't pour from an empty tank. Fill it back up.
""")

talk("mtalk_job_loss", "Burnout", "After the Layoff",
     "Losing a job hits men's identity hard. How to protect your mind while you rebuild.", False,
     [("BMC Public Health (2015): Depressive symptoms as a cause and effect of job loss in men and women", "https://bmcpublichealth.biomedcentral.com/articles/10.1186/s12889-015-2377-y")], """
If you've just lost your job, or you're in a season of money stress that keeps you up at night, this one's for you.

For a lot of men, work isn't just a paycheck. It's identity. It's how you answer the question, what do you do? It's how you feel like you're providing, like you're useful, like you matter. So when the job goes away, it can feel like part of you went with it.

That's not in your head. Researchers in Sweden followed workers over time and found that losing a job consistently predicted later major depression in both men and women, with a somewhat bigger effect in men. So if you feel knocked flat, there's a real reason.

But knowing that can actually help you. Because it means you can protect yourself on purpose, instead of just waiting to feel better.

First, keep a structure. Get up at the same time. Get dressed. Have a plan for the morning, even if it's applying for two jobs and going for a walk. Days without shape are where depression likes to move in.

Second, separate your worth from your work. You were a person before this job, and you'll be one after. Your kids still need you. Your friends still like you. Your skills didn't disappear.

Third, don't hide it. A lot of men keep a layoff secret, even from their partner for a while. That just makes it heavier. Tell the people close to you. And tell your network. Most jobs come through people you know.

Fourth, face the money with a plan. Sit down and look at the actual numbers. What's coming in, what's going out, how many months you've got. Fear is usually worse than the real picture. Look into unemployment benefits right away, and call creditors early if you need to. Many have hardship programs.

Here's what I want you to take with you.

Keep your days structured. Routine is protection.

You are not your job title.

Tell people. Your partner, your friends, your network.

Look at the money head on, with a plan.

And watch for the signs of depression. If you're losing hope, not sleeping, or drinking more, see your doctor. If you ever think about not being here, call or text nine eight eight.

This is a chapter. It's not the whole book.
""")

talk("mtalk_grief", "Grief", "Grieving Like a Man",
     "Men often grieve through doing, not crying. Both count. How to carry loss without burying it.", False,
     [("American Psychiatric Association: Prolonged Grief Disorder (DSM-5-TR)", "https://www.psychiatry.org/patients-families/prolonged-grief-disorder")], """
When someone you love dies, people expect you to fall apart in a certain way. Crying at the funeral, talking about your feelings. And when that doesn't happen, a lot of men start to wonder if something's wrong with them.

Here's the truth. There isn't one right way to grieve. Grief researchers describe different styles. Some people grieve mostly through feelings, by crying and talking. Others grieve mostly through action and thinking. Fixing things. Building something. Taking care of the arrangements. Working out. Going back to the shop. Many men lean toward that second style. And that's real grief too.

So if you've been throwing yourself into a project since your dad died, or you haven't cried but you can't stop thinking about him, you're not doing it wrong.

But there's a trap. Doing can turn into avoiding. If you're staying so busy that you never let any of it in, or you're numbing it with alcohol, it tends to come out sideways later. As anger, as exhaustion, as getting sick.

Grief also doesn't follow a schedule. It comes in waves. You'll be fine for a week, and then a song in the truck knocks you sideways. That's normal. It doesn't mean you're going backward.

For most people, grief gradually becomes something they can carry. But for some, it stays stuck at full strength. In 2022, the American Psychiatric Association added a condition called prolonged grief disorder. For adults, it's when intense longing for the person, or being consumed by thoughts of them, keeps going for at least a year and makes it hard to function day to day. It's treatable, and there are therapies built specifically for it.

Here's what I want you to take with you.

Grieve your way. If doing something with your hands helps, do it. Fix the truck. Build the bench. Run the miles.

But let some of it in. Say their name out loud. Tell a story about them. Let the tears come if they come.

Tell one person what you're going through. Even just, it's been hard since my brother died.

Watch the numbing. If you're drinking to get through the nights, that's a sign to reach out.

And if a year has gone by and you're still stuck, or you're having thoughts of not wanting to be here, talk to your doctor or a grief counselor. If you're in crisis, call or text nine eight eight.

Grief is love with nowhere to go. Give it somewhere to go.
""")

talk("mtalk_new_dad", "Depression", "New Dads Get It Too",
     "About one in ten fathers gets depressed around a baby's birth. Here's what it looks like.", False,
     [("JAMA (2010): Prenatal and postpartum depression in fathers, a meta-analysis", "https://pubmed.ncbi.nlm.nih.gov/20483973/")], """
Everybody talks about how moms can get depressed after a baby comes. Far fewer people talk about dads. But it happens, and it happens more than most guys realize.

A big analysis published in JAMA looked at studies of more than twenty-eight thousand fathers. It found that about ten percent had depression sometime between early pregnancy and the baby's first birthday. One in ten. And it was most common in the stretch between three and six months after the baby was born.

So why would a new dad get depressed? There's a lot going on. Very little sleep. Money pressure, sometimes more than ever. Your relationship with your partner suddenly changes, and there's less time and attention for each other. You might feel left out, or like you don't know what you're doing. And if your partner is struggling with depression, your risk goes up too.

In dads it often doesn't look like sadness. It can look like irritability, working way more hours, pulling away from the family, drinking more, or just feeling numb and disconnected from the baby. Some guys feel guilty because they thought they'd feel instant love, and instead they feel nothing, or resentful. That's more common than people admit.

Here's what I want you to take with you.

You're not a bad father if you're struggling. You're a father who's struggling. Those are different things.

Protect your sleep where you can. Trade shifts with your partner so each of you gets a longer stretch.

Talk to your partner. Not to add to her load, but so you're on the same team. A lot of couples find out they're both struggling.

Get some time with the baby that's just yours. A bath, a walk, a feeding. Connection grows through doing.

Find another dad. Somebody a few months ahead of you who'll tell you the truth about how hard it is.

Tell your doctor. Ask to be screened for depression. And if your partner is seeing her doctor, it's fine to say, I'm having a hard time too.

If you ever have thoughts of harming yourself or the baby, call or text nine eight eight, or call nine one one, right away.

Taking care of yourself is part of taking care of your family.
""")

talk("mtalk_alcohol", "Recovery", "When the Drink Stops Helping",
     "Alcohol can feel like relief, then make anxiety and depression worse. How to tell, and what to do.", False,
     [("Alcohol Research: Current Reviews (2019): Co-occurring alcohol use disorder and anxiety", "https://pmc.ncbi.nlm.nih.gov/articles/PMC6927748/"),
      ("SAMHSA National Helpline", "https://www.samhsa.gov/find-help/helplines/national-helpline")], """
Let's be honest about drinking. For a lot of men, a couple of beers or a glass of whiskey is how the day ends. It takes the edge off. It helps you stop thinking. And at first, it kind of works.

But here's the catch. Alcohol is a depressant. It slows your brain down, which feels relaxing in the moment. Then, as it wears off, your nervous system bounces back the other way. That's why a lot of people wake up the next day feeling anxious, jumpy, or low. Some people call it hangxiety. And it can turn into a loop. You drink to calm down, you feel worse the next day, so you drink again.

Researchers see this connection all the time. A review in the journal Alcohol Research found that up to half of people getting treatment for problem drinking also met the criteria for at least one anxiety disorder. Drinking to cope with bad feelings is one of the strongest warning signs for future problems with alcohol.

So how do you know if your drinking has crossed a line? Ask yourself a few honest questions. Do you drink to deal with stress or sadness, more than to enjoy it? Have you tried to cut back and found it hard? Does it cause problems at home or at work? Do people who love you bring it up? Do you need more than you used to, to feel the same?

If you said yes to some of those, it's not a reason to beat yourself up. It's a reason to take a closer look.

Here's what I want you to take with you.

Try a break. Thirty days without alcohol. Notice how your sleep, mood, and anxiety change. A lot of men are surprised.

Find a replacement for what the drink was doing. If it was stress relief, try a walk, a workout, a shower, or calling someone. If it was a reward, find a different reward.

Don't drink to fall asleep. Alcohol wrecks the quality of your sleep, even if it knocks you out.

Talk to your doctor. Be honest about how much. There are medications and programs that help, and they're more private than you might think.

The SAMHSA National Helpline is free, confidential, and open all day, every day: one eight hundred, six six two, help. That's one eight hundred, six six two, four three five seven.

And if drinking is tied up with thoughts of not wanting to be here, call or text nine eight eight.

It's not about willpower. It's about getting the right help.
""")

talk("mtalk_betting", "Recovery", "When the Bet Is Betting You",
     "Sports betting apps are everywhere now. How to tell when it's a problem, and where to call.", False,
     [("NBC News (2024): Gambling addiction hotlines say volume is up as online sports betting booms", "https://www.nbcnews.com/health/mental-health/gambling-addiction-hotline-calls-online-sports-betting-rcna145539"),
      ("National Council on Problem Gambling: 1-800-MY-RESET", "https://www.ncpgambling.org/news/1-800-my-reset-announcement/")], """
A few years ago, betting on a game meant knowing a guy, or taking a trip. Now it's an app on your phone, open twenty-four seven, with ads during every commercial break. And for a lot of men, that's become a real problem, fast.

After the Supreme Court cleared the way in 2018, most states legalized sports betting. And problem gambling helplines across the country started seeing more calls. NBC News talked to directors of several problem gambling centers, and they said the callers are getting younger, often men in their twenties and thirties, and the situations are getting more serious. People losing savings, losing homes, losing relationships.

Here's why it gets its hooks in. Betting apps are fast. You can place bet after bet in minutes. Wins feel amazing, and near misses keep you coming back. And because it's sports, it can feel like skill, not luck. You know the teams, you know the stats, so it feels like you should be able to win it back.

So how do you know if it's a problem? Ask yourself honestly. Are you betting more than you planned to? Chasing losses, trying to win it back? Hiding it from your partner? Borrowing money, or using money meant for bills? Feeling irritable or anxious when you try to stop? Thinking about it all the time?

Here's what I want you to take with you.

Set hard limits in the app now, while you're thinking clearly. Most apps let you cap deposits, time, and bets. Or better, use the self-exclusion option to lock yourself out.

Delete the apps from your phone. Make it harder to bet on impulse.

Tell someone. Gambling problems thrive on secrecy. Telling your partner or a friend is hard, but it's often the turning point.

Hand over control of money for a while, if you need to. Let someone you trust help manage it.

And call the National Problem Gambling Helpline. In January 2026, the National Council on Problem Gambling launched a new number: one eight hundred, M Y, RESET. It's free and confidential. The older number, one eight hundred, five two two, four seven zero zero, still works too.

Gambling problems often come with depression, and with debt that feels hopeless. If you ever have thoughts of not wanting to be here, call or text nine eight eight.

You're not the first, and you're not alone. People get their lives back from this all the time.
""")

talk("mtalk_sleep", "Anxiety", "Sleep Is Not Optional",
     "Short sleep and bad moods feed each other. What the CDC data says, and how to reset.", False,
     [("CDC NCHS Data Brief 559: Short Sleep Duration Among Adults, 2024", "https://www.cdc.gov/nchs/products/databriefs/db559.htm"),
      ("CDC Preventing Chronic Disease (2021): Effect of inadequate sleep on frequent mental distress", "https://www.cdc.gov/pcd/issues/2021/20_0573.htm")], """
A lot of men wear short sleep like a badge of honor. Five hours and a pot of coffee, let's go. But your brain doesn't see it that way.

Here's where we are. The CDC released a report this past April, using 2024 data, and it found that about thirty percent of American adults sleep less than seven hours a night. Men and women were about the same. Sleep experts recommend at least seven hours for adults.

And sleep is tied directly to mental health. A CDC study of more than two hundred seventy thousand adults found that people who averaged six hours of sleep or less were about two and a half times more likely to have frequent mental distress, even after accounting for other factors. It works both ways too. Stress and depression wreck sleep, and bad sleep makes stress and depression worse. It's a loop.

When you're short on sleep, the part of your brain that handles emotion gets more reactive, and the part that keeps you level gets weaker. That's why everything feels like a bigger deal when you're tired. Small stuff makes you angry. Worries feel huge.

Here's what I want you to take with you.

Same wake time every day. Even weekends. This is the single most powerful thing for resetting your body clock.

Get light in the morning. Step outside for ten minutes after you wake up. It tells your brain it's daytime.

Cut caffeine after early afternoon. It hangs around in your system for hours.

Don't use alcohol to fall asleep. It might knock you out, but it breaks up your sleep later in the night.

Make your bedroom dark, cool, and quiet. Leave your phone across the room if you can.

If you can't sleep, get up. After about twenty minutes awake in bed, go do something calm in low light until you feel sleepy. That keeps your brain from linking bed with frustration.

And if you've had trouble sleeping most nights for weeks, or you snore loudly and wake up exhausted, talk to your doctor. Insomnia has very effective treatments, and sleep apnea is common in men and very treatable.

Sleep isn't laziness. It's how your brain repairs itself overnight.
""")

talk("mtalk_exercise", "Depression", "Move to Feel Better",
     "A 2024 BMJ review of 218 trials found exercise eases depression. Which kinds work best.", False,
     [("BMJ (2024): Effect of exercise for depression, systematic review and network meta-analysis", "https://www.bmj.com/content/384/bmj-2023-075847")], """
If someone told you there was a treatment for depression that was free, had almost no side effects, and made your heart and your sleep better at the same time, you'd want to know about it. That treatment is exercise.

In 2024, the British Medical Journal published one of the biggest reviews ever done on this. Researchers looked at two hundred eighteen trials, with more than fourteen thousand people who had depression. They found that walking or jogging, yoga, and strength training were among the most effective options. Even lower intensity activities like walking helped. And the more vigorous the exercise, the bigger the benefit tended to be.

Here's an interesting detail. In that review, walking and jogging worked well for both men and women. Yoga and qigong seemed to work especially well for men. So if you've always thought yoga wasn't for you, it might be worth a try.

Why does it work? Exercise changes brain chemistry. It boosts chemicals that improve mood and focus. It lowers stress hormones over time. It improves sleep. And it gives you something depression takes away: a sense that you did something, that you're capable.

Now, the hard part. When you're depressed, getting off the couch feels impossible. So don't start with a big plan. Start tiny.

Here's what I want you to take with you.

Start with ten minutes. A ten minute walk around the block counts. Do it today.

Schedule it like an appointment. Same time each day, so it doesn't depend on how you feel.

Lift something. Strength training doesn't need a gym. Push-ups, squats, carrying heavy things. Two or three times a week.

Do it with someone. A walking buddy, a gym partner, a pickup game. You'll show up more, and it helps with loneliness too.

Track how you feel before and after. Most people feel at least a little better after, even on bad days. Write it down so you remember.

And remember, exercise works best alongside other help, not always instead of it. If you're depressed, talk to your doctor too. Exercise can be part of the plan.

Your body and your mind are on the same team. Get them moving together.
""")

talk("mtalk_ptsd", "Grief", "After Something Terrible",
     "Trauma can stay in your body long after it's over. PTSD is common, and it's treatable.", False,
     [("VA National Center for PTSD: How Common Is PTSD in Adults?", "https://www.ptsd.va.gov/understand/common/common_adults.asp"),
      ("Journal of Clinical Psychiatry (2026): National trends in PTSD among U.S. veterans", "https://www.psychiatrist.com/jcp/national-trends-ptsd-us-veterans-2025-2026-national-health-resilience-veterans-study/faq/")], """
Some things you go through don't stay in the past. A car crash. Combat. An assault. A violent loss. Seeing someone get hurt. Long after it's over, your body acts like it's still happening.

Maybe you have nightmares, or flashbacks that hit out of nowhere. Maybe you're always on guard, scanning every room, sitting with your back to the wall. Maybe loud noises make you jump. Maybe you avoid certain places, or you've gone numb and detached. Maybe you've got a short fuse you didn't used to have.

That pattern has a name. Post-traumatic stress disorder, or PTSD. And it's more common than a lot of people think. According to the VA's National Center for PTSD, about six out of every hundred people in this country will have PTSD at some point in their lives. Men are more likely to go through things like accidents, physical assaults, and combat.

For veterans, the numbers are higher. A national study of U.S. veterans published this year found that about fourteen percent had PTSD at some point in their lives, and that the rate has gone up compared to earlier surveys. Younger veterans had the highest rates.

Here's what's important to understand. PTSD is not a sign of weakness. It's what can happen when your brain's survival system gets stuck in the on position after something overwhelming. It's a normal reaction to an abnormal experience.

And it's very treatable. The VA and most experts recommend trauma-focused therapy, like prolonged exposure or cognitive processing therapy. These are structured, usually time limited, and they work for a lot of people. Medication can help too.

Here's what I want you to take with you.

You're not broken. Your brain did what it was built to do. It just needs help standing down.

Avoidance feels safer, but it keeps PTSD going. Therapy helps you face it in a safe, controlled way.

Watch the self-medicating. Alcohol and drugs numb things for a night and make PTSD worse over time.

Tell someone you trust what you're carrying. You don't have to share every detail.

If you're a veteran, the VA has PTSD programs, and you can call nine eight eight and press one for the Veterans Crisis Line any time. Everyone else, call or text nine eight eight if you're in crisis.

What happened to you was real. Healing is real too.
""")

talk("mtalk_breakup", "Grief", "When the Relationship Ends",
     "Breakups and divorce hit men harder than many expect. How to get through the first months.", False,
     [("Survey Center on American Life: The State of American Friendship (2021)", "https://www.americansurveycenter.org/commentary/american-men-suffer-a-friendship-recession/")], """
When a relationship ends, especially a long one, it can feel like the ground went out from under you. Whether you saw it coming or not, whether you ended it or she did, it's a real loss. And a lot of men are caught off guard by how hard it hits.

Part of the reason is that for many men, their partner was their main emotional connection. The person they talked to, who knew what was going on in their life, who planned the social calendar. When that's gone, you don't just lose the relationship. You can lose your support system, your routines, your home, sometimes your daily time with your kids. All at once.

And single men are especially likely to be isolated. The Survey Center on American Life found that one in five unmarried men who aren't in a relationship said they had no close friends at all.

So after a breakup, a lot of men go one of two ways. Some shut down and isolate. Some go hard in the other direction, drinking, partying, jumping into something new right away. Both are ways of not feeling it. And both tend to make the hurt last longer.

Here's what I want you to take with you.

Let yourself grieve it. It's okay to be sad, angry, relieved and confused all at once. You lost something real.

Don't go through it alone. This is the time to reconnect with friends, family, your brother, your old roommate. Tell them you're going through a divorce or a breakup. Most people want to help.

Keep your routines. Work, gym, meals, sleep. Structure is a lifeline right now.

Go easy on the alcohol. Breakups and heavy drinking are a bad combination for mood.

Be careful with your words, especially if you have kids. Don't put them in the middle. If co-parenting is hard, a family counselor or mediator can help.

Give it time before jumping into something new. Not forever, but enough to know who you are on your own.

And watch for signs that it's turning into depression. If weeks go by and you can't function, or you're losing hope, talk to your doctor or a counselor. If you ever have thoughts of not wanting to be here, call or text nine eight eight.

This chapter ended. You didn't.
""")

talk("mtalk_body_image", "Self-Worth", "Big Enough",
     "The pressure to look a certain way is hitting men too. What social media does, and what helps.", False,
     [("American Psychological Association (2023): Reducing social media use significantly improves body image", "https://www.apa.org/news/press/releases/2023/02/social-media-body-image")], """
Body image used to be talked about mostly as a women's issue. But a lot of men are struggling with it too. Feeling too small, not muscular enough, not lean enough. Comparing yourself to guys online who seem to have perfect bodies. Spending hours in the gym and still feeling like it's never enough.

For some men, it goes further. Constantly checking the mirror. Feeling anxious if you miss a workout. Eating in a rigid, stressed-out way. Even thinking about steroids or other substances to get bigger. When the drive to look a certain way starts running your life, that's worth paying attention to.

Social media plays a big part. Your feed can show you hundreds of edited, filtered, perfectly lit bodies every day. Many of them are using lighting, angles, and sometimes drugs that they don't talk about. Your brain still compares you to them.

And here's some good news from the research. In 2023, the American Psychological Association published a study where young adults with anxiety or depression cut their social media use roughly in half for a few weeks. Compared with people who kept scrolling as usual, they felt significantly better about their appearance and their weight. In just a few weeks.

Here's what I want you to take with you.

Notice what your feed is doing to you. If certain accounts leave you feeling worse about yourself, mute them. You're allowed to protect your mind.

Try cutting your social media time in half for three weeks. See how you feel.

Train for what your body can do, not just how it looks. Strength, endurance, getting through a hike with your kids. Those goals are more satisfying and more sustainable.

Be very careful with steroids and unregulated supplements. They can seriously harm your heart, your hormones, and your mood. Talk to a doctor before taking anything.

Talk to someone if it's taking over. If you're obsessed with your body, anxious about food, or exercising even when you're hurt, a counselor can help. Body image problems and eating disorders happen in men too, and they're treatable. The National Alliance for Eating Disorders has a helpline staffed by licensed therapists: one eight six six, six six two, one two three five.

You are more than a body. And the body you have deserves respect, not punishment.
""")

talk("mtalk_therapy", "Recovery", "Your First Therapy Appointment",
     "What therapy actually is, what happens the first time, and how to find someone who fits.", False,
     [("CDC NCHS Data Brief 564: Mental Health Treatment Among Adults, 2024", "https://www.cdc.gov/nchs/products/databriefs/db564.htm"),
      ("SAMHSA: FindTreatment.gov", "https://findtreatment.gov")], """
A lot of men have never been to therapy, and honestly, a lot of men have no idea what it even looks like. So let's take the mystery out of it.

First, you'd be in the minority if you went. The CDC's most recent data, from 2024, found that about eleven percent of men got counseling or therapy from a mental health professional in the past year. Women were more likely to go. So if you've never been, that's normal. But it doesn't mean it isn't for you.

So what is therapy? It's mostly just talking, with someone who's trained to help you understand what's going on and actually change things. It's not lying on a couch talking about your childhood for years. A lot of modern therapy is practical and focused. Cognitive behavioral therapy, for example, works on how your thoughts, feelings and actions connect, and gives you specific skills to practice between sessions.

What happens the first time? Usually the therapist asks why you're there, what's been going on, and a little about your life. You can say as much or as little as you want. You don't have to have the right words. Something like, I've been angry all the time and I don't know why, is a perfectly good start.

Here's what I want you to take with you.

Start where it's easiest. Your regular doctor can refer you. Your job might have an employee assistance program with free sessions. Your insurance company's website will list therapists who take your plan.

You can also search FindTreatment dot gov, which is run by the federal government, to find mental health and substance use treatment near you.

Telehealth counts. If sitting in an office feels like too much, a video session from your truck or your kitchen table works.

Fit matters. If you don't click with the first therapist, try another. You're allowed to ask, have you worked with a lot of men? What's your approach?

Give it a few sessions. The first one can feel awkward. That's normal. Most people need several sessions before it starts to click.

And remember, the strongest move isn't handling everything alone. It's knowing when to bring in help, just like you would for your truck, your taxes, or your knee.

If you're in crisis before you can get an appointment, call or text nine eight eight.

Going to therapy isn't admitting defeat. It's taking control.
""")

talk("mtalk_provider", "Burnout", "The Weight of Providing",
     "When you feel like everyone depends on you and you can't let up. Carrying it without breaking.", False,
     [("BMC Public Health (2015): Depressive symptoms as a cause and effect of job loss in men and women", "https://bmcpublichealth.biomedcentral.com/articles/10.1186/s12889-015-2377-y")], """
There's a kind of pressure a lot of men carry that nobody really talks about. The pressure to provide. To be the one who keeps it all together. The mortgage, the car payment, the kids' braces, your parents getting older. You lie awake running numbers. You can't get sick. You can't slow down. Because who else is going to do it?

For a lot of men, providing is tied up with being a good man. And that's not a bad thing. Taking care of your people is honorable. But when the pressure is constant and you're carrying it alone, it starts to grind you down.

Research on men and work keeps finding the same thing. When work and money get shaky, men's mental health takes a real hit. Researchers in Sweden found that losing a job predicted later major depression for both men and women, with a somewhat stronger effect in men. A big part of that is how tightly men tie their worth to what they bring home.

Here's something worth hearing. The people who love you need more from you than a paycheck. Your kids will remember whether you were there, whether you laughed with them, whether you were kind. Your partner wants you, not just your income.

Here's what I want you to take with you.

Share the load out loud. Tell your partner what you're worried about. A lot of men protect their families by hiding the stress, and it ends up isolating them. Talk about the money as a team.

Make a plan for the numbers. Fear grows in vagueness. Sit down, look at the real figures, and make a plan, even a rough one. Talk to a financial counselor if you need to. Many nonprofits offer free help.

Separate what you can control from what you can't. You can't control the economy or the layoffs. You can control your effort, your spending, and how you treat people.

Protect some time that isn't about being useful. An hour with your kids, a game with friends, a walk. You're a person, not just a provider.

And watch for warning signs. Trouble sleeping, short temper, drinking more, losing interest in things. If those stick around, talk to your doctor. If you ever start thinking your family would be better off without you, that's depression lying to you. Call or text nine eight eight right away.

You can carry a lot. You don't have to carry it alone.
""")

talk("mtalk_purpose", "Recovery", "Who Am I Now?",
     "Retirement, kids leaving, slowing down. Finding purpose in the second half of life.", False,
     [("CDC: Suicide Data and Statistics", "https://www.cdc.gov/suicide/facts/data.html"),
      ("U.S. Surgeon General Advisory: Our Epidemic of Loneliness and Isolation (2023)", "https://www.hhs.gov/sites/default/files/surgeon-general-social-connection-advisory.pdf")], """
For years, your life had a clear shape. You got up, went to work, came home, took care of the family. You knew who you were, because you knew what you did. And then one day, things change. You retire. The kids move out. Your body slows down. Maybe you lose your partner.

And the question that comes up for a lot of men is, who am I now?

That question can be surprisingly heavy. Without the structure of a job, days can start to blur together. Without coworkers, your social circle can shrink fast. Without someone depending on you, it can feel like you've lost your purpose.

This matters more than people realize. The CDC reports that suicide rates are highest among the oldest adults, and men in that age group are at especially high risk. Loneliness is a big part of the picture. The Surgeon General's 2023 advisory on loneliness warned that social disconnection raises the risk of heart disease, depression, dementia, and early death.

But here's the other side. A lot of men find that this season, with a little intention, becomes one of the best of their lives. More time to build things, to mentor, to travel, to be the grandfather or uncle they never had time to be.

Here's what I want you to take with you.

Find a reason to get up. It doesn't have to be big. Volunteering, coaching, a part-time job, a garden, a woodshop. Something where somebody's counting on you.

Pass something on. Your skills and experience are valuable. Mentor a younger guy, teach a grandkid to fish, help a neighbor fix his truck.

Keep your people close. Schedule regular time with friends, on purpose. Breakfast every Tuesday. Golf every other Saturday. Connection won't happen by accident anymore.

Keep moving. Walking, swimming, strength training. It protects your body and your mood.

Get your health checked, including your mood. Depression in older men is often missed, because people assume being down is just part of getting older. It isn't.

And if you ever feel like you're just a burden, or you think about not being here, please call or text nine eight eight. Right away.

You've still got a lot to give. The world needs what you know.
""")

# ───────────── Divorce and separation (men) ─────────────
WILSON = ("Wilson et al., Psychological Bulletin 2025: Suicidality in men following relationship breakdown (Orygen summary)", "https://orygen.org.au/About/News-And-Events/2025/World-first-study-reveals-heartbreaking-risk-facto")
APA_DIV = ("American Psychological Association: Healthy divorce, how to make your split as smooth as possible", "https://www.apa.org/topics/healthy-divorce")
CDC_DIV = ("CDC NCHS FastStats: Marriage and Divorce", "https://www.cdc.gov/nchs/fastats/marriage-divorce.htm")
AAP_TALK = ("American Academy of Pediatrics, HealthyChildren.org: How to Talk to Your Children about Divorce", "https://www.healthychildren.org/English/healthy-living/emotional-wellness/Building-Resilience/Pages/How-to-Talk-to-Your-Children-about-Divorce.aspx")
AAP_ADJ = ("American Academy of Pediatrics, HealthyChildren.org: Divorce and Separation, How to Help Your Child Adjust", "https://www.healthychildren.org/English/family-life/family-dynamics/types-of-families/Pages/Adjusting-to-Divorce.aspx")
AAP_SUP = ("American Academy of Pediatrics, HealthyChildren.org: How to Support Children after Parents Separate or Divorce", "https://www.healthychildren.org/English/healthy-living/emotional-wellness/Building-Resilience/Pages/How-to-Support-Children-after-Parents-Separate-or-Divorce.aspx")
AACAP = ("American Academy of Child and Adolescent Psychiatry, Facts for Families: Children and Divorce", "https://www.aacap.org/AACAP/Families_and_Youth/Facts_for_Families/FFF-Guide/Children-and-Divorce-001.aspx")
UMICH = ("University of Michigan Population Studies Center (July 2025): Economic consequences of divorce vary by gender, race and ethnicity", "https://psc.isr.umich.edu/news/research-shows-economic-consequences-of-divorce-in-the-us-vary-by-gender-race-and-ethnicity/")
SG = ("U.S. Surgeon General Advisory (2023): Our Epidemic of Loneliness and Isolation", "https://www.hhs.gov/sites/default/files/surgeon-general-social-connection-advisory.pdf")
FTC_ROM = ("FTC data via Axios (Feb 2024): Romance scams reported in 2023", "https://www.axios.com/2024/02/13/charted-love-can-hurt-closer")

talk("mtalk_div_first_months", "Divorce", "The First Months After the Split",
     "The weeks right after a separation are the riskiest stretch for men. Here's how to get through them.", False,
     [WILSON, APA_DIV, CDC_DIV], """
If you just separated, or the papers just got signed, this one's for you. Let's talk straight about the first few months, because they're the hardest part.

You're not the only man going through this. In 2023, the CDC counted about six hundred seventy thousand divorces in this country, and that's with a few states not even reporting. Every one of those has a guy on the other side of it, sitting in a quiet car in a parking lot, wondering how his life got here.

Here's something every man should know. A big review published in Psychological Bulletin in 2025 looked at seventy-five studies covering more than a hundred million men. Separated men were nearly five times more likely to die by suicide than married men. For separated men under thirty-five, the odds were around eight times higher. And the risk was highest right after the split, not years later.

I'm not telling you that to scare you. I'm telling you because it means the next few months matter. This is the stretch where you need people around you, not fewer.

The researchers found a few things drive it. Men often lose their main emotional support when the marriage ends. They lose daily time with their kids. They lose the home, the routine, sometimes the friends who were really her friends. And a lot of men don't have words for what they're feeling, so it comes out as anger, drinking, or shutting down.

The American Psychological Association says the end of a marriage usually brings a flood of anger, grief, anxiety and fear. All of that is normal. You don't have to act like you're fine.

Here's what I want you to take with you.

Lock in your basics. Sleep, food, a walk every day. Skip the extra drinks. Alcohol makes the bad nights darker.

Tell two people what's really going on. A brother, a buddy, a coworker you trust. Not just, yeah, we split. Tell them it's hitting you hard.

Don't make big decisions in a rage. Don't quit the job, sell the house, or fire off the angry text. Give it a week.

Talk to a counselor. The APA says a psychologist can help you sort through decisions with less conflict. Lots of employers have a free assistance program. Check.

And if you have any thoughts of ending your life, call or text nine eight eight, tonight. If there's a gun or anything else in the house you've thought about, ask a friend to hold it for a while.

You will not feel like this forever. The first months are the storm. Get through the storm, and there's a life on the other side.
""")

talk("mtalk_div_coparent", "Divorce", "Co-Parenting Without the War",
     "Your marriage ended. Your job as a dad didn't. How to keep the fighting away from the kids.", False,
     [AAP_SUP, AAP_ADJ, APA_DIV], """
Your marriage is over. Your job as a dad isn't. So let's talk about how to raise kids with someone you might not even want to be in a room with.

Start with what the research says, because it's good news. The American Academy of Pediatrics says many kids have painful feelings after a divorce and bounce back within two to three years. And kids are more resilient and less stressed when there's less conflict between their parents.

Read that again. It's not the divorce itself that does the most damage. It's the fighting. Ongoing war between parents is what hurts kids. Which means you have a lot of power here.

The AAP is clear on this. Never involve your kids in your arguments, and never make them take sides. They love both of you. Asking them to pick is asking them to tear themselves in half.

So what does that look like on a Tuesday?

It looks like not trash-talking their mom in front of them. Not even a sigh or an eye roll. Kids catch all of it.

It looks like not using your kids as messengers. Tell your mom she's late with the check. Don't do that. Talk to your ex directly, or use a co-parenting app or email.

It looks like keeping handoffs short and boring. Hi, here's the bag, he had a good weekend, see you Sunday. That's it. Handoffs are not the time to settle old scores.

The AAP also says kids do best with warmth and clear, consistent rules. That doesn't mean both houses have to be identical. It means your house should be steady. Same bedtime, same expectations, same dad.

And if talking to your ex always turns into a fight, there's a thing called parallel parenting. You each run your own house, you keep contact to the facts, and you write things down. Less contact can mean less conflict. A mediator can help you build the schedule.

Here's what I want you to take with you.

The fighting is what hurts kids, not the two homes. Lower the heat, and you protect them.

No bad-mouthing, no messengers, no making them choose.

Keep it businesslike with your ex. Short, polite, in writing if you need to be.

Be the steady house. Show up when you say you will. Every time.

The marriage may be over. But you can be the kind of dad your kids will thank you for when they're grown.
""")

talk("mtalk_div_kids", "Divorce", "Telling the Kids",
     "What pediatricians and child psychiatrists say to tell your kids, and what to never say.", False,
     [AAP_TALK, AAP_ADJ, AACAP], """
Of all the hard talks in a divorce, this is the one most dads dread. How do you tell your kids? Let's walk through what the experts actually recommend.

First, don't hide it and don't wait until the last minute. The American Academy of Child and Adolescent Psychiatry says to tell kids before things change, not after one parent is already gone. Kids usually sense something's wrong anyway. Silence makes them fill in the blanks, and what they imagine is often worse.

Second, if you can, tell them together. Both parents, same room, same message. It shows them that even though you're splitting up, you're still both their parents, and you're still a team when it comes to them.

Third, keep it simple and honest, and match it to their age. A five-year-old needs something like, mom and dad aren't going to live together anymore, but we both love you, and that will never change. A teenager can handle more, but still doesn't need the adult details. Who did what is not their burden to carry.

The American Academy of Pediatrics says to make sure your kids know the divorce is not their fault. Also tell them they can't fix it, and they can't make you get back together. Little kids especially think they caused it. Say it more than once.

The AAP also says kids mostly want to know they're safe. Where am I going to live? Will I still see dad? What about my school, my dog, my room? Have answers ready for the practical stuff, or tell them honestly that you're still working it out, and you'll let them know.

Then let them feel what they feel. Angry, sad, quiet, whatever comes. Don't tell them to cheer up. The AAP says the earlier you tell them and the more often you talk, the more comfortable they'll feel.

Here's what I want you to take with you.

Tell them early, together if you can, in simple words.

Say it plainly. This is not your fault. You can't fix it. We both love you.

Answer the practical questions. Kids want to know what changes and what stays the same.

Don't blame their mom. Not in the talk, not after.

Keep the conversation open. One talk is not enough. Check in again next week, and the week after.

And if your child is still really struggling months later, talk to their pediatrician. A counselor for kids can help a lot.
""")

talk("mtalk_div_money", "Divorce", "Money Stress After Divorce",
     "Two households on the same paycheck. How to stay steady when the numbers don't work yet.", False,
     [UMICH, APA_DIV], """
Let's talk about money, because after a divorce, money stress can keep you up at night just as much as the heartbreak.

Here's the simple math. One income that used to run one household now has to run two. Two rents or mortgages, two sets of bills, maybe child support or alimony on top. It can feel like you're drowning, even if you make decent money.

Research from the University of Michigan, published in 2025, found that family income drops for everyone after a divorce, because you lose your spouse's earnings. Women usually take a harder hit, but men's household income drops too. And for a lot of men, the bigger shock is the new monthly bills.

Money stress is real stress. It messes with your sleep, your temper, and your focus. And when you're already grieving, it can make everything feel hopeless. So let's get practical.

Here's what I want you to take with you.

Get the whole picture on paper. Every bill, every account, every debt, every payment. You can't fix what you won't look at. One hour with a notepad or a spreadsheet does more than a month of worrying.

Build a bare-bones budget for now. Not forever. Just for the next six months. Rent, utilities, food, gas, insurance, child support. Everything else waits.

Pay child support first, on time, every time. It's for your kids, and falling behind creates legal trouble that gets expensive fast. If your income changes, ask the court to adjust it the right way. Don't just stop paying.

Watch out for spending your feelings. New truck, big trips, nights out you can't afford. It feels good for a week. The bill lasts a lot longer.

Update the paperwork. Beneficiaries on your life insurance and retirement accounts, your will, your bank accounts. A lot of men forget this for years.

Get real advice. A family law attorney or mediator for the settlement, and a fee-only financial planner or a nonprofit credit counselor for the budget. The APA says mediation is often a good alternative to a courtroom fight, and courtroom fights eat money.

And if money stress is tipping into hopelessness, or you think about not being here, call or text nine eight eight. Money problems can be fixed. You can't be replaced.

This tight season is not the rest of your life. Get steady, and then you rebuild.
""")

talk("mtalk_div_empty_house", "Divorce", "Loneliness and the Empty House",
     "No kids' noise, no one to talk to at dinner. What to do when the quiet gets loud.", False,
     [SG, WILSON], """
Let's talk about the quiet. You walk into the apartment after work, and there's nobody there. No kids yelling. No one asking about your day. The kids' room is empty on the weeks they're at their mom's. And the silence is loud.

That loneliness is one of the hardest parts of divorce for men, and nobody really prepares you for it.

Here's why it matters. In 2023, the U.S. Surgeon General put out an advisory on loneliness. It said about half of American adults report feeling lonely, and that lacking social connection raises the risk of dying early by about as much as smoking up to fifteen cigarettes a day. That's how serious being alone is for your body.

And for divorced men, it's often worse. The 2025 review in Psychological Bulletin on men after a breakup found that losing your support network is a big part of why the months after a split are so risky. A lot of men put all their emotional eggs in one basket, their partner. When that marriage ends, almost every deep conversation they had goes with it.

So you have to rebuild on purpose. It won't happen by accident.

Here's what I want you to take with you.

Make a plan for the empty nights. Especially the weeks without your kids. Don't just drift to the couch and the bottle. Pick something. The gym, a pickup game, a class, a volunteer shift.

Call one guy every week. An old friend, a brother, a cousin. Men tend to bond side by side, so make it something to do. Fishing, golf, fixing a car, watching the game together.

Join something with regulars. A league, a running group, a men's group, a volunteer crew. Same people, same time, every week. That's how friendships actually form.

Make the place feel like home. Hang a picture. Get a real bed for the kids. Cook a real meal sometimes. Your space affects your mood.

Watch your coping habits. More drinking, more hours of scrolling, more hours of work, all of those can be loneliness in disguise.

And if the loneliness turns into hopelessness, talk to your doctor or a counselor. If you ever think about not being here, call or text nine eight eight.

The quiet won't always feel this heavy. But you'll need to fill it on purpose, one person, one night, one week at a time.
""")

talk("mtalk_div_dating", "Divorce", "Dating Again",
     "How to know if you're ready, how not to repeat old patterns, and how to stay safe online.", False,
     [APA_DIV, FTC_ROM, AAP_ADJ], """
At some point after a divorce, the question comes up. Should I start dating again? Maybe your friends are pushing you. Maybe you're lonely. Maybe you're curious. Let's talk about how to do it well.

First, are you ready? Here's a simple test. Can you talk about your ex without getting heated, or without it taking over the whole conversation? Are you looking for a partner, or are you looking for a painkiller? If you're trying to fill a hole fast, or prove something to your ex, you're probably not there yet. And that's okay. There's no deadline.

Second, learn from the last one. The American Psychological Association says a psychologist can help you think through what went wrong in your marriage, so you don't repeat the same patterns in your next relationship. That's not about blame. It's about being honest. What did you bring to it? What would you do differently? The man who does that work usually picks better the next time.

Third, if you have kids, go slow. Keep dating separate from the kids for a while. Don't introduce someone new until it's serious and steady. Your kids are still adjusting, and the American Academy of Pediatrics says they need stability. A parade of new people is the opposite of stable.

Fourth, be smart online. The FTC reports that in 2023, people reported losing more than a billion dollars to romance scams. Recently divorced people can be prime targets, because scammers look for people who are lonely. The warning signs are always the same. They move fast, they say they love you early, they can't meet in person or do a video call, and sooner or later they need money. Crypto, gift cards, a wire transfer, an emergency. Never send money to someone you haven't met.

Here's what I want you to take with you.

There's no right timeline. Date when you're curious, not when you're desperate.

Do the work on yourself first. A counselor can help you see your own patterns.

Keep it away from the kids until it's real.

Meet in public, tell a friend where you're going, and never send money to someone online.

And go easy on yourself. Your marriage ending doesn't mean you can't love well. A lot of men find a healthier relationship on the other side, because they learned.
""")
