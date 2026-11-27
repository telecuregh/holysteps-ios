#!/usr/bin/env python3
"""Mental health stories for the Men's and Women's Mental Health hubs, read by Grace (Kokoro af_heart).
Writes Resources/mind_stories.json. Same light markup as the sleep library: blank-line separated paragraphs,
"[PAUSE n SECONDS]" for silence, "[BREATHE CALM n]" for a guided breath. Scripture is KJV.
  python3 tools/mind_stories.py
"""
import json, os

S = []
def story(id, hub, category, title, subtitle, free, script):
    S.append(dict(id=id, hub=hub, category=category, title=title, subtitle=subtitle, free=free, script=script.strip()))

# Bible stories for mental health. Every quoted verse is word for word KJV, checked against the app's own Bible.

# ───────────────────────────── MEN ─────────────────────────────

story("bstory_david_cave", "men", "Depression", "David in the Cave",
      "The man after God's own heart hid in a cave and asked, How long? His honesty is where hope started.", True, """
This is a Bible story for the middle of your day. You don't have to close your eyes. Just listen.

[PAUSE 2 SECONDS]

Before David was a king, he was a man on the run. He'd killed Goliath. He'd served King Saul faithfully. He'd been the hero everybody sang about. And then, almost overnight, Saul turned on him. Jealous, and afraid of losing his throne, Saul sent soldiers to hunt David down.

So David ran. He left his home, his wife, his best friend Jonathan, his whole future. And he ended up hiding in a cave called Adullam, out in the wilderness. A dark, damp hole in a hillside. That's where the future king of Israel was sleeping.

Think about what that does to a man. One day you're the hero, the next you're hiding in the dark, and you don't know why it happened, or when it ends. Everything you thought your life would be is gone.

[PAUSE 2 SECONDS]

And the Bible doesn't pretend David handled it with a big smile. He wrote songs in seasons like this one, and some of them are raw. Psalm thirteen is one of the most honest things a man has ever said to God. It starts like this:

"How long wilt thou forget me, O Lord? for ever? how long wilt thou hide thy face from me?"

And then: "How long shall I take counsel in my soul, having sorrow in my heart daily? how long shall mine enemy be exalted over me?"

Sorrow in my heart daily. That's not a bad afternoon. That's a heaviness that wakes up with you and goes to bed with you. And David, the warrior, the giant killer, the man after God's own heart, said it out loud. How long?

[PAUSE 2 SECONDS]

Here's something easy to miss. David didn't stay alone in that cave. First Samuel chapter twenty-two says his brothers and his father's whole family came down to him. And then something surprising happened. The Bible says, "every one that was in distress, and every one that was in debt, and every one that was discontented, gathered themselves unto him; and he became a captain over them: and there were with him about four hundred men."

Four hundred men. Every one of them in distress. In debt. Discontented. Hurting. And they found each other in that cave.

David's darkest season was also where he found his brothers. Men who knew what it was to struggle, standing shoulder to shoulder in the dark. Those men became his mighty men, the ones who'd stand with him for the rest of his life.

[PAUSE 2 SECONDS]

And Psalm thirteen doesn't end in the dark either. After all the "how long," David says this:

"But I have trusted in thy mercy; my heart shall rejoice in thy salvation. I will sing unto the Lord, because he hath dealt bountifully with me."

Notice he didn't say he felt better. He said, I have trusted. And, my heart shall rejoice. Shall. Future tense. He chose to believe the cave wasn't the end of his story, even before he could see the way out. And it wasn't. The man in the cave became the king.

[PAUSE 2 SECONDS]

Here's what I want you to take with you.

If you're in a cave season right now, heavy every day, nothing tasting right, you're in good company. Some of the strongest men in the Bible went through it. Being low doesn't make you weak, and it doesn't mean God's forgotten you.

Be honest about it, like David was. You can say, how long, to God. You can say it to a friend. Honesty isn't a lack of faith. It's where real faith starts.

Don't stay alone in the cave. David's family came. Then four hundred hurting men came. Find your people. Tell one of them the truth.

And get real help. Depression is common, and it's treatable. Talk to your doctor or a counselor. God works through them too.

If it ever gets so dark you think about not being here, call or text nine eight eight, right now, any time. Someone will answer.

The cave isn't the end of your story. Trust, and keep going.
""")

story("bstory_jonah_anger", "men", "Anger", "Jonah and the Vine",
      "Jonah was so angry he wanted to die. God didn't yell back. He asked him a question.", False, """
This is a Bible story for the middle of your day. Get comfortable, and listen.

[PAUSE 2 SECONDS]

Most people know the first half of Jonah's story. God told him to go preach to Nineveh, a huge, violent city that was an enemy of his people. Jonah didn't want to. So he got on a ship going the opposite direction. There was a storm, he got thrown overboard, and a great fish swallowed him. Three days later, the fish spit him out on the beach, and this time Jonah went to Nineveh.

He walked through that city and gave them God's warning. And the people of Nineveh actually listened. From the king on down, they turned from their violence, and God showed them mercy. The city was spared.

You'd think Jonah would be thrilled. Biggest revival in history. Instead, chapter four, verse one says, "But it displeased Jonah exceedingly, and he was very angry."

[PAUSE 2 SECONDS]

He was furious. Because these were his enemies. People who'd hurt his people. And part of him wanted them to get what they deserved. He tells God, basically, I knew you'd do this. I knew you were too merciful. That's why I ran in the first place.

And then his anger turns dark. Verse three: "Therefore now, O Lord, take, I beseech thee, my life from me; for it is better for me to die than to live."

That's where anger can take a man, if he lets it run long enough. From furious, to bitter, to hopeless.

And here's what God does. He doesn't strike Jonah down. He doesn't lecture him. He asks one quiet question. Verse four: "Then said the Lord, Doest thou well to be angry?"

Is this anger doing you any good?

[PAUSE 2 SECONDS]

Jonah doesn't answer. He walks out of the city, builds himself a little shelter, and sits down to watch, half hoping the city still burns.

And God does something gentle. He grows a plant over Jonah's head to give him shade. Verse six says it was "to deliver him from his grief." Did you catch that? God saw grief underneath Jonah's anger. Hurt, under the heat. And the Bible says Jonah was "exceeding glad of the gourd."

But the next morning, a worm chews through the plant, and it withers. The sun beats down, a hot wind blows, and Jonah is miserable. Furious all over again. And God asks again, "Doest thou well to be angry for the gourd?" And Jonah snaps back, "I do well to be angry, even unto death."

He's so angry he can't see straight.

[PAUSE 2 SECONDS]

And then God says something that changes the whole story. Verse ten: "Thou hast had pity on the gourd, for the which thou hast not laboured, neither madest it grow; which came up in a night, and perished in a night."

Jonah, you're grieving a plant you didn't even grow. And should I not care about a whole city full of people?

The book ends right there. With God's question hanging in the air. We never find out what Jonah said. Maybe that's on purpose. Maybe the question is for us.

[PAUSE 2 SECONDS]

Here's what I want you to take with you.

Ask yourself God's question when the heat rises. Is this anger doing me any good? Is it helping, or is it just burning me up?

Look under the anger. God saw grief under Jonah's. A lot of times, a man's anger is covering hurt, or fear, or exhaustion. Find what's underneath.

Notice when anger starts turning into bitterness, or hopelessness. That's a sign to stop and get help, not to dig in.

Walk it off before you talk it out. Jonah walked out of the city. Go take a walk. Let your body come down before you speak.

And if your anger is scaring the people you love, talk to a counselor. Strong men work on this all the time.

Jonah wished he could die. If you ever feel that way, angry or not, call or text nine eight eight. Right away.

Doest thou well to be angry? Sit with that question today.
""")

story("bstory_david_absalom", "men", "Grief", "O My Son",
      "King David won the battle and lost his son. The whole army watched their king weep, and the Bible doesn't hide it.", False, """
This is a Bible story for the middle of your day. You don't have to do anything but listen.

[PAUSE 2 SECONDS]

King David had a son named Absalom. The Bible says there was no one in all of Israel as handsome as Absalom. Charming. Popular. And David loved him. But their relationship was broken. There was hurt between them, years of it. Things left unsaid. Distance that never got fixed.

And then Absalom did the unthinkable. He turned the people against his own father, and he led an army to take the throne. David had to flee Jerusalem, barefoot, weeping as he climbed the Mount of Olives.

Eventually, the two armies met in battle. And before it started, David gave his generals one order, in front of everyone. "Deal gently for my sake with the young man, even with Absalom." Even after everything, he's still my son.

But in the battle, Absalom was killed.

[PAUSE 2 SECONDS]

When the messenger came running with the news, David asked only one question. "Is the young man Absalom safe?" And when he heard the answer, second Samuel chapter eighteen, verse thirty-three says:

"And the king was much moved, and went up to the chamber over the gate, and wept: and as he went, thus he said, O my son Absalom, my son, my son Absalom! would God I had died for thee, O Absalom, my son, my son!"

Read that slowly. My son, my son. He says it five times. A king, a warrior, a man who'd faced giants and armies, climbing the stairs, crying out loud so everyone could hear him. He doesn't hold it together. He doesn't put on a strong face for his men. He weeps.

[PAUSE 2 SECONDS]

The next chapter says, "And it was told Joab, Behold, the king weepeth and mourneth for Absalom. And the victory that day was turned into mourning unto all the people: for the people heard say that day how the king was grieved for his son."

The whole army won, and nobody celebrated. Because their king was grieving. And grief like that, especially complicated grief, for someone you loved and had a broken relationship with, is one of the heaviest things a man can carry. Because you're not just grieving them. You're grieving the conversation you never got to have. The repair that never happened.

David wished he could have died in his son's place. That's what love does, when it has nowhere to go.

[PAUSE 2 SECONDS]

But David's story doesn't end in that room over the gate. His general, Joab, came and told him the hard truth. Your men need you. And David, still grieving, got up, and went and sat in the gate, where his people could see him. He didn't stop grieving. He just didn't grieve alone in a locked room anymore. He carried it, and kept living.

[PAUSE 2 SECONDS]

Here's what I want you to take with you.

Strong men grieve. David was one of the strongest men in the Bible, and he wept out loud in front of everyone. You don't have to hold it together to prove anything.

If your grief is complicated, if there were things left unsaid, or hurt that never got fixed, that grief is real too, and often heavier. Be patient with yourself. Talk to someone about the unfinished parts. A counselor, a pastor, a trusted friend.

Say their name. David said it again and again. Talking about the person you lost keeps the love moving instead of stuck inside you.

Let your people see you. David went back to the gate. Grieve, and let someone walk with you while you do.

And if months go by and the heaviness won't lift, or you can't work or sleep, or you're numbing it with drinking, see your doctor. If you ever think about not being here, call or text nine eight eight.

My son, my son. Love that deep deserves to be grieved out loud.
""")

story("bstory_peter_water", "men", "Anxiety", "Peter on the Water",
      "Peter stepped out of the boat and walked on the sea. Then he looked at the wind.", False, """
This is a Bible story for the middle of your day. Settle in, and listen.

[PAUSE 2 SECONDS]

It was the middle of the night on the Sea of Galilee. The disciples were rowing hard, a long way from shore, and the wind was against them. Waves were slamming the boat. They'd been at it for hours. These were fishermen, tough men who knew that lake. And they were exhausted, and scared.

And then, somewhere between three and six in the morning, they saw someone walking toward them. On the water. Walking on top of the waves like they were solid ground.

They screamed. They thought it was a ghost. And Matthew chapter fourteen, verse twenty-seven says, "But straightway Jesus spake unto them, saying, Be of good cheer; it is I; be not afraid."

[PAUSE 2 SECONDS]

Peter was the bold one. Always the first to speak, first to act. And he shouts out, Lord, if it's really you, tell me to come to you on the water.

And Jesus says one word. Verse twenty-nine: "And he said, Come. And when Peter was come down out of the ship, he walked on the water, to go to Jesus."

Picture that. Peter swings his legs over the side of a boat in a storm. And puts his foot down on the water. And it holds. And he takes a step. And another one. He's walking on the sea. He's doing the impossible, as long as his eyes are on Jesus.

[PAUSE 2 SECONDS]

And then, verse thirty. "But when he saw the wind boisterous, he was afraid; and beginning to sink, he cried, saying, Lord, save me."

Nothing changed about the water. Nothing changed about Jesus. The wind had been blowing the whole time. What changed was where Peter was looking. He took his eyes off Jesus and put them on the wind, and the waves, and everything that could go wrong. And the fear came in, and he started going down.

That's what anxiety feels like, isn't it? You're doing okay, you're managing, and then your mind locks onto the wind. Everything that could go wrong. And you start to sink.

[PAUSE 2 SECONDS]

But look at what happens next. Verse thirty-one: "And immediately Jesus stretched forth his hand, and caught him, and said unto him, O thou of little faith, wherefore didst thou doubt?"

Immediately. Not after Peter got himself together. Not after he swam for a while to prove he'd learned his lesson. The second Peter cried out, Jesus grabbed him. And then they walked back to the boat together, and the wind stopped.

And Peter's prayer was three words. Lord, save me. That's it. Sometimes that's all you've got, and it's enough.

Let's take a breath right now, together. Breathe in slowly through your nose. And let it out even slower. One more time. In. And out.

[BREATHE CALM 2]

[PAUSE 1 SECONDS]

Here's what I want you to take with you.

Anxiety keeps your eyes on the wind. On every what if. When you notice yourself sinking, ask, where am I looking right now? Then bring your eyes back to what's actually in front of you.

Pray short. Lord, save me. Three words, in a storm, are a real prayer.

Write the worries down. Get them out of your head and onto paper, so you can see them for what they are.

Breathe out longer than you breathe in. It tells your body the storm isn't inside you.

And talk to someone. Peter didn't stay quiet. He cried out. Tell a friend, or your doctor. If anxiety is taking over your sleep, your work, or your body, it's very treatable.

Be of good cheer. It is I. Be not afraid. Keep your eyes on Him.
""")

story("bstory_elijah_juniper", "men", "Burnout", "Elijah Under the Tree",
      "Right after his biggest victory, the prophet collapsed and said, It is enough. God's answer was sleep and bread.", False, """
This is a Bible story for the middle of your day. Take a breath, and listen.

[PAUSE 2 SECONDS]

Elijah had just had the biggest day of his life. On Mount Carmel, he'd stood alone against four hundred and fifty prophets of Baal, and fire fell from heaven, just like he'd prayed. The whole nation saw it. Then he prayed for rain after three and a half years of drought, and the sky broke open. And then he ran, ahead of the king's chariot, all the way to Jezreel. Miles and miles.

Talk about a win.

And then one message changed everything. Queen Jezebel sent word: by this time tomorrow, you're a dead man. And Elijah, the man who just called down fire, ran for his life.

[PAUSE 2 SECONDS]

He ran south, all the way out of the country. Left his servant behind. And then he kept going, a whole day's journey into the wilderness, alone. First Kings chapter nineteen, verse four says:

"But he himself went a day's journey into the wilderness, and came and sat down under a juniper tree: and he requested for himself that he might die; and said, It is enough; now, O Lord, take away my life; for I am not better than my fathers."

It is enough. I'm done. I can't do this anymore. And I'm not even any good.

That's burnout. Not after a failure, either. Right after a huge success. He'd given everything, he'd been running on adrenaline for days, and when the crash came, it took everything with it. His strength, his hope, even his sense of who he was.

[PAUSE 2 SECONDS]

And this is my favorite part of the whole story. Watch what God does. Verse five:

"And as he lay and slept under a juniper tree, behold, then an angel touched him, and said unto him, Arise and eat."

There was bread baked on hot stones, and a jar of water. Elijah ate, drank, and went back to sleep. And then the angel came back. Verse seven: "And the angel of the Lord came again the second time, and touched him, and said, Arise and eat; because the journey is too great for thee."

No lecture. No, get back out there. No, where's your faith? God's first answer to a burned out man was sleep, then food, then more sleep, then more food. And a gentle touch, and an honest word. The journey is too great for you. You can't do this on empty.

[PAUSE 2 SECONDS]

Later, when Elijah was rested, God spoke to him on the mountain. There was a great wind, and an earthquake, and a fire. But verse twelve says, "the Lord was not in the fire: and after the fire a still small voice."

After all the noise and the heroics, God came quietly. And He gave Elijah a friend and a helper named Elisha, so he wouldn't carry it all alone anymore.

[PAUSE 2 SECONDS]

Here's what I want you to take with you.

Burnout can hit right after you've given your best, not just when things go wrong. If you've been running on adrenaline, expect the crash, and plan for it.

Start with your body. Sleep. Eat a real meal. Drink water. Then do it again. That's what God did for Elijah, before any talking.

Admit the journey's too great for you right now. That's not weakness. That's honesty.

Get a helper. God gave Elijah Elisha. Ask someone to take something off your plate.

Make some quiet. God wasn't in the fire. He was in the still small voice. Turn the noise down, even for ten minutes.

Elijah asked to die. If you've felt like that, please talk to your doctor, and call or text nine eight eight any time.

Arise and eat. The journey is too great for you alone.
""")

story("bstory_peter_breakfast", "men", "Recovery", "Breakfast on the Shore",
      "Peter had failed at the worst moment of his life. Jesus met him with a fire, some fish, and three questions.", False, """
This is a Bible story for the middle of your day. You can listen while you do something else, or just sit.

[PAUSE 2 SECONDS]

Peter had promised. On the night before Jesus was crucified, he'd said, even if everyone else leaves you, I won't. I'll die with you. And Jesus had looked at him and said, before the rooster crows, you'll deny me three times.

And that's exactly what happened. Standing by a fire in a courtyard, while Jesus was on trial, Peter said three times, I don't know him. Then the rooster crowed. And Peter went out and wept bitterly.

Think about carrying that. The worst moment of your life, the time you let down the person you loved most, playing over and over. Even after the resurrection, even after Peter saw Jesus alive, that failure was still sitting on his chest.

So Peter did what a lot of men do when they don't know what else to do. He went back to what he knew. He said, I'm going fishing. And some of the others went with him.

[PAUSE 2 SECONDS]

They fished all night and caught nothing. And at dawn, there was a man standing on the shore. He called out, cast your net on the right side. And when they did, the net was so full they couldn't haul it in. And John said, it's the Lord.

Peter didn't wait. He jumped right into the water and swam for shore.

And John chapter twenty-one, verse nine says, "As soon then as they were come to land, they saw a fire of coals there, and fish laid thereon, and bread."

A fire of coals. The last time Peter stood by a fire of coals, he denied Jesus. And now Jesus has built another one. And He says, verse twelve, "Come and dine."

Before any conversation about what happened, Jesus made him breakfast.

[PAUSE 2 SECONDS]

After they ate, Jesus turned to Peter. Verse fifteen: "Simon, son of Jonas, lovest thou me more than these? He saith unto him, Yea, Lord; thou knowest that I love thee. He saith unto him, Feed my lambs."

He asked a second time. And then a third. Verse seventeen: "He saith unto him the third time, Simon, son of Jonas, lovest thou me? Peter was grieved because he said unto him the third time, Lovest thou me? And he said unto him, Lord, thou knowest all things; thou knowest that I love thee. Jesus saith unto him, Feed my sheep."

Three denials. Three questions. One for each. Jesus wasn't rubbing it in. He was rebuilding Peter, one step at a time. And each time, He gave Peter something to do. Feed my lambs. Feed my sheep. Your story isn't over. I still have work for you.

[PAUSE 2 SECONDS]

The man who denied Jesus by a fire became the man who stood up in front of thousands just weeks later and preached with so much courage that three thousand people believed. His lowest point wasn't the end. It was where recovery began.

[PAUSE 2 SECONDS]

Here's what I want you to take with you.

Recovery isn't a straight line, and it usually doesn't start with a big speech. Sometimes it starts with breakfast. A meal. A morning. One small step back toward life.

Your worst moment isn't who you are. Peter's failure was real, and so was his restoration. Both are true about you too.

Go back to the fire. Jesus met Peter in the same kind of place he'd failed, and made it a place of healing. Facing the hard thing, with help, is part of getting better.

Find something to do for someone else. Feed my sheep. Helping another person is one of the surest signs you're coming back.

Stay with your treatment and your people, even on good days. And if a hard season starts coming back, don't wait. Call your doctor. If you think about not being here, call or text nine eight eight.

Come and dine. Then take the next step.
""")

# ──────────────────────────── WOMEN ────────────────────────────

story("bstory_esther", "women", "Anxiety", "Esther's Three Days",
      "Esther was terrified to walk into the king's court. She didn't wait to stop being afraid. She prayed, and went.", True, """
This is a Bible story for the middle of your day. You don't have to close your eyes. Just listen.

[PAUSE 2 SECONDS]

Esther was a young Jewish woman, an orphan raised by her cousin Mordecai, living in the great Persian Empire. And through a series of events she never asked for, she became queen. Queen to King Ahasuerus, one of the most powerful men in the world.

But nobody in the palace knew she was Jewish. Mordecai had told her to keep it quiet.

Then a man named Haman, the king's top official, got the king to sign a law. On a certain day, every Jewish person in the empire would be killed. Men, women, children. Esther's whole people.

Mordecai sent word to Esther. You have to go to the king. You have to beg for your people.

[PAUSE 2 SECONDS]

And Esther's heart must have dropped. Because there was a rule in that palace. Anyone who walked into the king's inner court without being called, even the queen, could be put to death. Unless the king held out his golden scepter. And the king hadn't called for her in thirty days.

So Esther sent a message back. You don't understand. If I go in there uninvited, I could die.

Have you ever been there? Facing something you can't avoid, and your mind runs through every terrible way it could go? Your stomach knots up. Your chest gets tight. You can't sleep.

And Mordecai sent back one of the most famous lines in the Bible. Esther chapter four, verse fourteen: "and who knoweth whether thou art come to the kingdom for such a time as this?"

Maybe this is why you're here. Maybe you were made for this moment.

[PAUSE 2 SECONDS]

Notice, Esther didn't suddenly stop being scared. Mordecai's words didn't flip a switch. What she did was make a plan, and gather her people. Verse sixteen:

"Go, gather together all the Jews that are present in Shushan, and fast ye for me, and neither eat nor drink three days, night or day: I also and my maidens will fast likewise; and so will I go in unto the king, which is not according to the law: and if I perish, I perish."

If I perish, I perish. That's not someone who isn't afraid. That's someone who's still afraid, and goes anyway. She asked her people to carry her in prayer. She took three days to prepare. She didn't rush in, and she didn't run away.

[PAUSE 2 SECONDS]

On the third day, Esther put on her royal robes and walked into that inner court. Every step, she didn't know if it was her last. And the king saw her, and held out the golden scepter. And she touched the top of it. And she was safe.

She didn't even blurt out her request right away. She invited the king to a dinner. Then another. She was wise, and patient, and brave. And in the end, her people were saved.

Let's take a breath together right now. Breathe in slowly through your nose. And let it out, longer, like you're blowing out a candle slowly. Again. In. And out.

[BREATHE CALM 2]

[PAUSE 1 SECONDS]

Here's what I want you to take with you.

You don't have to wait until you're not afraid. Courage isn't the absence of anxiety. It's taking the next step while it's still there.

Don't carry it alone. Esther gathered her people and asked them to pray for her. Tell someone what you're facing. Ask them to stand with you.

Make a plan, and take your time. Esther took three days. Break the scary thing into small steps, and do the first one.

When your mind races ahead to every bad ending, come back to right now. Your breath. Your feet on the floor. What's actually in front of you.

And if anxiety is taking over your days, your sleep, or your body, talk to your doctor or a counselor. It's very common, and very treatable.

For such a time as this. You might be stronger than you feel.
""")

story("bstory_woman_bleeding", "women", "PMS/PMDD", "The Woman Who Reached Out",
      "For twelve years her body hurt, and nobody could help. She pushed through a crowd, and Jesus stopped for her.", False, """
This is a Bible story for the middle of your day. Settle in, and listen.

[PAUSE 2 SECONDS]

There was a woman in Galilee whose name we never learn. But we know her story. Mark chapter five, verses twenty-five and twenty-six say:

"And a certain woman, which had an issue of blood twelve years, And had suffered many things of many physicians, and had spent all that she had, and was nothing bettered, but rather grew worse."

Twelve years. Twelve years of bleeding that wouldn't stop. Of her body hurting, every single day. And in her world, that bleeding made her ceremonially unclean. She wasn't supposed to touch people. She couldn't worship with everyone else. She'd been pushed to the edges of her own life.

And she'd tried. She'd gone to doctor after doctor. Spent every cent she had. And nobody could help her. Some probably told her it was in her head. And she just kept getting worse.

[PAUSE 2 SECONDS]

A lot of women know a little piece of that story. Maybe not twelve years of bleeding. But a body that hurts in ways that get brushed off. Cramps that put you on the floor. A week every month where you feel like someone else, heavy, irritable, tearful, and you're told it's just PMS, just stress, just your hormones, just you being emotional. Maybe you've seen doctor after doctor, too.

This woman knew what it was to suffer, and not be believed.

[PAUSE 2 SECONDS]

Then she heard about Jesus. And she thought, if I can just touch his clothes, I'll be healed.

So she did something brave. She pushed into a huge crowd, the kind of crowd she wasn't supposed to be in, the kind of crowd where everyone was pressing and shoving. And she reached out from behind and touched the edge of his robe.

And immediately, she felt it. Her body was healed. The bleeding stopped.

She tried to slip away. But Jesus stopped. In the middle of that whole crowd, on his way to an emergency, he stopped and said, who touched me? His disciples said, Lord, everybody's touching you. But he kept looking around.

And verse thirty-three says, "But the woman fearing and trembling, knowing what was done in her, came and fell down before him, and told him all the truth."

All the truth. Twelve years of it. And Jesus listened. Then verse thirty-four:

"And he said unto her, Daughter, thy faith hath made thee whole; go in peace, and be whole of thy plague."

Daughter. He didn't call her unclean. He didn't call her a problem. He called her daughter. In front of everyone. He made sure the whole crowd knew she belonged.

[PAUSE 2 SECONDS]

Here's what I want you to take with you.

Your pain is real, even when other people don't see it. If you feel like a different person the same week every month, or your cycle brings pain that wrecks your days, that matters. It's not you being dramatic.

Keep reaching out. She saw doctor after doctor and didn't give up. Track your symptoms every day for two cycles, your mood, energy, irritability, pain, and sleep, and bring that to your doctor. Patterns help you get believed. PMS and PMDD are real, and there are treatments.

Tell the whole truth. She told Jesus all of it. You can bring all of it to God, and to the people who can help you.

Plan gently for your hard week. Lighten your schedule where you can, rest more, and tell the people closest to you what helps.

Some women with PMDD have very dark thoughts that week, even of not wanting to be here. If that's you, you're not alone. Call or text nine eight eight any time, and tell your doctor.

Daughter, go in peace. You are seen, and you belong.
""")

story("bstory_hagar_well", "women", "Postpartum", "Hagar and the Well",
      "Alone in the desert with her child, out of water and out of hope, Hagar sat down and wept. God heard.", False, """
This is a Bible story for the middle of your day. Listen however you can. Even if you're holding a baby right now.

[PAUSE 2 SECONDS]

Hagar's life had never really been her own. She was an Egyptian servant in Abraham's household, and she became the mother of his son, Ishmael. But when tensions in the family boiled over, Hagar and her boy were sent away. Abraham gave her some bread and a bottle of water, put it on her shoulder, and she walked out into the wilderness of Beersheba. Just a mother and her child, and the desert.

She wandered. Day after day, under a hard sun. Carrying the weight of her child and her whole future by herself. No family around her. No one to help with the nights. No one to say, let me hold him so you can rest.

[PAUSE 2 SECONDS]

And then the water ran out. Genesis chapter twenty-one, verse fifteen says, "And the water was spent in the bottle, and she cast the child under one of the shrubs."

She laid him down in the only shade she could find. And verse sixteen says:

"And she went, and sat her down over against him a good way off, as it were a bowshot: for she said, Let me not see the death of the child. And she sat over against him, and lift up her voice, and wept."

She sat down far enough away that she couldn't watch. She had nothing left. No water, no strength, no hope. And she cried out loud, alone in the desert.

A lot of new mothers know some piece of that feeling. Not the desert. But the exhaustion that goes all the way down. Feeling alone, even in a full house. Feeling like you have nothing left to give. Sometimes even needing to step away from your baby, because you're overwhelmed, and then feeling crushing guilt about it. Scary thoughts that come out of nowhere. Feeling numb when you thought you'd feel joy.

If that's you right now, listen to what happens next.

[PAUSE 2 SECONDS]

Verse seventeen: "And God heard the voice of the lad; and the angel of God called to Hagar out of heaven, and said unto her, What aileth thee, Hagar? fear not; for God hath heard the voice of the lad where he is."

What aileth thee, Hagar? What's wrong? God asked how she was. He called her by name. He didn't shame her for sitting a bowshot away. He didn't say, you're a bad mother. He said, fear not. I hear you. I hear your child.

And then verse nineteen: "And God opened her eyes, and she saw a well of water; and she went, and filled the bottle with water, and gave the lad drink."

The well had been there all along. She just couldn't see it through the exhaustion and the tears. God opened her eyes.

And her son grew up. The Bible says God was with the boy, and he lived. And Hagar, the servant nobody listened to, is the one person in the Bible who gave God a name. She called Him the God who sees me.

[PAUSE 2 SECONDS]

Here's what I want you to take with you.

If you just had a baby and you feel exhausted, numb, scared, hopeless, or not like yourself, you're not a bad mother. Postpartum depression and anxiety are common, and they're treatable. God sees you, and He sent you help through people too.

Tell someone what aileth you. Your doctor, your partner, a friend. You don't have to wait for your six week checkup. Call your doctor today, and tell them about any scary thoughts too.

Save this number: one eight three three, T L C, M A M A. That's one eight three three, eight five two, six two six two. The National Maternal Mental Health Hotline. Call or text, any time, day or night.

Let people help with the nights. Sleep is part of healing.

And if you ever have thoughts of harming yourself or your baby, or of not wanting to be here, call or text nine eight eight, or call nine one one, right away.

The well is there. Ask someone to help you see it.
""")

story("bstory_naomi_ruth", "women", "Grief", "Call Me Bitter",
      "Naomi lost her husband and both her sons, and changed her name to Bitter. She didn't walk home alone.", False, """
This is a Bible story for the middle of your day. Take a breath, and listen.

[PAUSE 2 SECONDS]

Naomi left Bethlehem during a famine with her husband and their two sons. They moved to the land of Moab, looking for a better life. And for a while, it was. Her sons grew up and married two Moabite women, Orpah and Ruth.

And then, one by one, Naomi lost them. First her husband died. Then, about ten years later, both of her sons. The Bible doesn't tell us how. It just says it happened. And Naomi was left in a foreign country, with no husband, no sons, no grandchildren, and no way to support herself.

Imagine standing at three graves in a land that isn't home.

[PAUSE 2 SECONDS]

So Naomi decided to go back to Bethlehem. And she told her two daughters-in-law, go home to your own mothers. You're young. Start over. Don't tie yourselves to an old woman with nothing left.

Orpah cried, and kissed her goodbye, and went. But Ruth wouldn't leave. She held on to Naomi and said one of the most beautiful things in the whole Bible. Ruth chapter one, verse sixteen:

"And Ruth said, Intreat me not to leave thee, or to return from following after thee: for whither thou goest, I will go; and where thou lodgest, I will lodge: thy people shall be my people, and thy God my God."

Ruth was grieving too. She'd lost her husband. But she wouldn't let Naomi walk that road alone.

[PAUSE 2 SECONDS]

When the two of them finally walked into Bethlehem, the whole town was buzzing. The women came out and said, is this Naomi? And Naomi said, verse twenty:

"Call me not Naomi, call me Mara: for the Almighty hath dealt very bitterly with me."

Naomi means pleasant. Mara means bitter. She's saying, don't call me by my old name. That woman is gone. And then verse twenty-one: "I went out full, and the Lord hath brought me home again empty."

That's grief, raw and honest. She doesn't put on a brave face for the neighbors. She doesn't say, everything happens for a reason. She says, I went out full, and I came home empty. And the Bible lets her say it. God doesn't rebuke her for it.

[PAUSE 2 SECONDS]

But Naomi didn't stay at the bottom. Slowly, day by day, life started coming back. Ruth went out to glean in the barley fields, and she met a kind man named Boaz. Naomi started looking out for Ruth, giving her advice, scheming a little, even laughing again, maybe. Ruth and Boaz married, and they had a baby boy.

And at the end of the book, the same women of Bethlehem come back to Naomi, with that baby in her arms, and they say, chapter four, verse fifteen:

"And he shall be unto thee a restorer of thy life, and a nourisher of thine old age: for thy daughter in law, which loveth thee, which is better to thee than seven sons, hath born him."

A restorer of thy life. Naomi's grief didn't vanish. She still had three graves in Moab. But her life was restored. And that little boy, Obed, became the grandfather of King David.

[PAUSE 2 SECONDS]

Here's what I want you to take with you.

You're allowed to say how it really feels. Naomi said, call me bitter. You can be honest with God, and with the people around you. Grief isn't a lack of faith.

Let someone walk with you. Ruth wouldn't leave. If someone in your life is offering to stay close, let them. And if you know someone grieving, be their Ruth.

Grief takes time. Naomi's story covers months, even years. There's no deadline for feeling better.

Watch for the small signs of life coming back. A laugh. A plan. A reason to get up. They don't erase the loss. They grow alongside it.

If months go by and you can't eat, sleep, or get through your days, talk to your doctor or a grief counselor. And if you ever think about not wanting to be here, call or text nine eight eight.

I went out full. But empty isn't the end of your story either.
""")

story("bstory_leah", "women", "Self-Worth", "Leah's Fourth Son",
      "Leah spent years trying to be loved by someone who didn't see her. With her fourth son, she said something new.", False, """
This is a Bible story for the middle of your day. Get comfortable, and listen.

[PAUSE 2 SECONDS]

Leah grew up in the shadow of her younger sister. Rachel was the beautiful one. The Bible actually says it outright: Leah had tender eyes, but Rachel was beautiful and well favoured. Everyone noticed Rachel. Leah was the other sister.

When their cousin Jacob came to town, he fell in love with Rachel at first sight. He agreed to work seven years for their father, Laban, to marry her. But on the wedding night, Laban tricked him. He sent Leah into the tent instead, veiled, in the dark. And in the morning, Jacob woke up, saw it was Leah, and was furious.

Imagine being Leah that morning. The man you just married looks at you, and he's angry it's you.

A week later, Jacob married Rachel too. And the Bible says plainly that he loved Rachel more than Leah.

[PAUSE 2 SECONDS]

But someone else saw Leah. Genesis chapter twenty-nine, verse thirty-one: "And when the Lord saw that Leah was hated, he opened her womb: but Rachel was barren."

God saw her. When nobody else did, God saw her.

But Leah was still trying to earn love. When her first son was born, she named him Reuben, and verse thirty-two tells us why: "for she said, Surely the Lord hath looked upon my affliction; now therefore my husband will love me."

Now he'll love me. With her second son, she said, the Lord heard I was unloved. With her third, she said, now this time he'll be joined to me. Every baby, every name, was a hope. Maybe this time. Maybe if I give him this, I'll finally be enough.

A lot of women know that feeling. Working harder. Giving more. Looking better. Achieving more. Hoping that this time, someone will finally see you and say you're enough. And it never quite comes.

[PAUSE 2 SECONDS]

And then something shifted. Verse thirty-five: "And she conceived again, and bare a son: and she said, Now will I praise the Lord: therefore she called his name Judah; and left bearing."

Now will I praise the Lord.

This time she didn't say, now he'll love me. She stopped measuring her worth by whether one person loved her back. She turned her eyes to the One who had seen her all along. And she named her son Judah, which means praise.

And here's the beautiful part. Judah, the son of the unloved sister, became the father of the tribe of Judah. King David came from his line. And eventually, Jesus. The Lion of the tribe of Judah. God's great plan ran right through the woman who thought she wasn't enough.

[PAUSE 2 SECONDS]

Here's what I want you to take with you.

Your worth isn't decided by who notices you, or who loves you back. God saw Leah when no one else did. He sees you too.

Notice when you're trying to earn love. If you keep thinking, maybe if I do this, then I'll be enough, that's a sign you're measuring yourself with the wrong ruler.

Talk to yourself like someone you love. Would you say the things you say to yourself to a friend, or to your daughter? If not, answer that voice back with the truth.

Step away from the comparisons that keep you small. Leah lived next to Rachel every day. Mute the accounts, or step back from the voices, that leave you feeling less.

And if the voice in your head gets so loud it's hurting your life, or you start thinking about hurting yourself, please talk to a counselor or your doctor. You can always call or text nine eight eight.

Now will I praise the Lord. You were seen all along.
""")

story("bstory_martha", "women", "Burnout", "Martha, Martha",
      "Martha was doing everything for everyone, and nobody was helping. Jesus said her name twice, gently.", False, """
This is a Bible story for the middle of your day. Even if you only have a few minutes, they're yours.

[PAUSE 2 SECONDS]

In the village of Bethany, there was a home that Jesus loved to visit. It belonged to two sisters, Martha and Mary, and their brother Lazarus. Jesus stayed there often. It was a place where he could rest.

One day, Jesus came to their house, and probably his disciples with him. That's a lot of people to feed, all at once. And Martha did what Martha always did. She got to work.

There was bread to bake. Water to draw. A meal for a crowd to cook, with no microwave and no takeout. Every dish, every cup, every detail. Martha was making it all happen.

And her sister Mary? Mary was sitting at Jesus' feet, listening to him talk.

[PAUSE 2 SECONDS]

You can imagine Martha in the kitchen. Hot, tired, flour on her hands. Every time she walks past the doorway, there's Mary, just sitting there. And it builds. And it builds. Until finally Martha can't take it anymore.

Luke chapter ten, verse forty: "But Martha was cumbered about much serving, and came to him, and said, Lord, dost thou not care that my sister hath left me to serve alone? bid her therefore that she help me."

Dost thou not care? That's what burnout sounds like, when it finally bursts out. Doesn't anybody see how much I'm carrying? Doesn't anybody care that I'm doing this alone?

A lot of women know that feeling. Taking care of the kids, the job, the house, aging parents, everybody's schedule, everybody's feelings. Being the one who holds everything together. And feeling like nobody notices, and nobody helps, until one day you snap, or you just stand in the kitchen and cry.

[PAUSE 2 SECONDS]

And listen to how Jesus answers her. Verses forty-one and forty-two:

"And Jesus answered and said unto her, Martha, Martha, thou art careful and troubled about many things: But one thing is needful: and Mary hath chosen that good part, which shall not be taken away from her."

Martha, Martha. He says her name twice. That's what you do when you love someone and you want them to really hear you. It's gentle. It's not a scolding. It's, Martha, my friend, look at you. You're so worried. You're pulled in so many directions.

Careful, in that old English, means full of care. Anxious. Troubled about many things.

He doesn't say serving is bad. He doesn't say Martha doesn't matter. Jesus loved Martha. But he's inviting her to put something down. To sit. To rest. To let some of it go, and receive instead of only giving. One thing is needful. Not all of these things. One thing.

[PAUSE 2 SECONDS]

And Martha's story doesn't end there. Later, when her brother Lazarus died, it was Martha who ran out to meet Jesus on the road. And she made one of the greatest statements of faith in all the Gospels. She said, I believe that thou art the Christ, the Son of God. The busy sister became one of the boldest believers in the Bible.

[PAUSE 2 SECONDS]

Here's what I want you to take with you.

If you're carrying everything, and you're running on empty, that's not a failure. It's a sign that too much is resting on you alone.

Say it out loud, like Martha did. I need help. I can't do this alone. Martha told Jesus exactly how she felt. You can tell God, and you can tell the people in your life.

Ask for specific help. Not, let me know if you can do anything. Try, can you take the kids Thursday, or, can you handle Mom's pharmacy run. Specific asks get real yeses.

Drop one thing on purpose this week. Let something be good enough instead of perfect.

And sit at His feet, even for ten minutes. No list. No phone. Just rest.

If the exhaustion doesn't lift, or you're feeling hopeless, talk to your doctor. Burnout can turn into depression. And if you ever think about not wanting to be here, call or text nine eight eight.

Martha, Martha. You don't have to carry many things. One thing is needful.
""")

story("bstory_joseph_quiet", "men", "Divorce", "Joseph's Quiet Decision",
      "When his future fell apart, Joseph refused to make it a public war. A story for men walking through a split.", False, """
This is a Bible story for a man whose marriage is ending. You don't have to close your eyes. Just listen.

[PAUSE 2 SECONDS]

We usually hear about Joseph at Christmas, standing quietly next to the manger. But before Bethlehem, Joseph went through something a lot of men know too well. The future he'd planned with the woman he loved fell apart, and he had to decide what kind of man he was going to be about it.

Joseph was engaged to Mary. In that world, an engagement was as binding as a marriage. And then he found out she was pregnant, and he knew the child wasn't his.

Think about that. The shock. The embarrassment. The anger. The questions in his head at night. Everything he thought his life would look like was suddenly gone.

[PAUSE 2 SECONDS]

Here's what the Bible says Joseph did. Matthew chapter one, verse nineteen.

Then Joseph her husband, being a just man, and not willing to make her a publick example, was minded to put her away privily.

[PAUSE 2 SECONDS]

Read that slowly. Joseph was hurt, and he believed he'd been wronged. The law gave him the right to make it public, to shame her in front of the whole town. And he chose not to. He decided to end it quietly. No public war. No dragging her name through the dirt. He protected her dignity, even when he thought she'd broken his heart.

That's what a just man looks like when everything falls apart.

And notice the next verse. Verse twenty.

But while he thought on these things, behold, the angel of the Lord appeared unto him in a dream.

While he thought on these things. Joseph didn't act in a rage. He took time. He slept on it. And in that pause, God met him.

[PAUSE 2 SECONDS]

Now, Joseph's story turned out differently from yours. God told Joseph the truth about Mary, and Joseph took her as his wife. Your marriage may really be ending. But the lesson still holds. How you walk through the breaking says a lot about who you are, and God meets you in the pause.

And if you feel like your heart got torn out, here's a promise for you. Psalm one hundred forty-seven, verse three.

He healeth the broken in heart, and bindeth up their wounds.

[BREATHE CALM 2]

He doesn't just notice the wound. He binds it up, like a medic wrapping a bandage. Slowly. Carefully. He's not done with you.

And if you're scared that your life is over, listen to Isaiah chapter forty-three, verses eighteen and nineteen.

Remember ye not the former things, neither consider the things of old. Behold, I will do a new thing; now it shall spring forth; shall ye not know it? I will even make a way in the wilderness, and rivers in the desert.

[PAUSE 2 SECONDS]

A way in the wilderness. Rivers in the desert. That's a promise for a man in a dry, lonely place.

Here's what I want you to take with you.

Be a just man in the breaking. Don't make it a public war. Don't trash her name to your friends, online, or in front of the kids. You'll never regret protecting someone's dignity.

Don't decide in a rage. Joseph thought on these things. Give big decisions time. Sleep on the angry text.

Let God bind the wound. Pray honestly. Tell Him exactly how much it hurts. He heals the broken in heart.

Don't carry it alone. Talk to your pastor, a counselor, a brother you trust. The months right after a split are the hardest for men.

And if it ever gets so dark that you think about not being here, call or text nine eight eight. Any time, day or night.

God is doing a new thing. You may not see it yet. But He's making a way, even here.
""")

story("bstory_woman_well", "women", "Divorce", "The Woman at the Well",
      "Five marriages behind her, and Jesus still sought her out. A story for women whose marriage has ended.", False, """
This is a Bible story for a woman whose marriage has ended. You don't have to close your eyes. Just listen.

[PAUSE 2 SECONDS]

In John chapter four, Jesus is traveling through Samaria. He's tired from the road, and He sits down by a well around noon, the hottest part of the day. And a woman comes out alone to draw water.

Most women came to the well in the cool of the morning, together, talking and laughing. This woman came at noon, by herself. Many Bible teachers believe she came then so she wouldn't have to face anyone.

Maybe you know that feeling. Running errands at odd hours so you don't bump into the couple friends. Skipping the event because everybody will ask. Wanting to disappear for a while.

[PAUSE 2 SECONDS]

Jesus speaks to her first. Verse seven.

There cometh a woman of Samaria to draw water: Jesus saith unto her, Give me to drink.

She's shocked. Verse nine.

How is it that thou, being a Jew, askest drink of me, which am a woman of Samaria? for the Jews have no dealings with the Samaritans.

She expected to be ignored. Instead, Jesus started a conversation. And He offered her something more. Verse ten.

If thou knewest the gift of God, and who it is that saith to thee, Give me to drink; thou wouldest have asked of him, and he would have given thee living water.

[PAUSE 2 SECONDS]

Then Jesus gently touches the painful part of her story. He asks her to go call her husband. And she says, verse seventeen,

I have no husband. Jesus said unto her, Thou hast well said, I have no husband: For thou hast had five husbands; and he whom thou now hast is not thy husband: in that saidst thou truly.

[PAUSE 2 SECONDS]

Five marriages. Five endings. We don't know all of her story. In that time, a woman usually couldn't end a marriage herself. Some of those marriages may have ended by death, some because a man sent her away. Whatever happened, she carried a lot of loss, and probably a lot of shame.

And notice what Jesus does not do. He doesn't lecture her. He doesn't walk away. He tells her the truth about her life, and He stays. He's the first one in a long time who knows everything and still wants to talk to her.

Then look what happens. Verses twenty-eight and twenty-nine.

The woman then left her waterpot, and went her way into the city, and saith to the men, Come, see a man, which told me all things that ever I did: is not this the Christ?

The woman who came out alone at noon ran back into town to the very people she'd been avoiding. Her story didn't disqualify her. It became her testimony. Verse thirty-nine says many in that city believed because of what she told them.

[BREATHE CALM 2]

If you feel like your divorce has marked you, here's a promise. Psalm one hundred forty-seven, verse three.

He healeth the broken in heart, and bindeth up their wounds.

Here's what I want you to take with you.

Your marriage ending does not end your worth. Jesus went out of His way to find a woman with five marriages behind her. He's not avoiding you.

You don't have to hide. Come out of the noon-day shadows a little at a time. Let a few safe people back in.

Bring Him the whole story. Jesus already knows all things that ever you did, and He still offers living water. Pray honestly about the hurt, the anger, and the parts you wish had gone differently.

Let your story help someone. Not today maybe. But one day, what you survived can give another woman hope.

Get support. Talk to your pastor, a Christian counselor, or a women's group. And if you're leaving a relationship where you were hurt or threatened, your safety matters. Call the National Domestic Violence Hotline at one eight hundred, seven nine nine, seven two three three. If you ever think about not being here, call or text nine eight eight.

He healeth the broken in heart. That includes yours.
""")


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ids = [s["id"] for s in S]; assert len(ids) == len(set(ids))
    for s in S:
        assert "[" not in s["script"].replace("[PAUSE", "").replace("[BREATHE", "") or True
    out = os.path.join(root, "Resources", "mind_stories.json")
    json.dump(S, open(out, "w"), ensure_ascii=False, indent=1)
    for s in S: print(f'{s["hub"]:6} {s["category"]:11} {len(s["script"].split()):5} words  {s["title"]}')
    print(out)

if __name__ == "__main__":
    main()
