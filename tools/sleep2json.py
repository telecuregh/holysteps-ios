#!/usr/bin/env python3
# Extracts the faith sleep library (Bible sleep stories, kids' Bible stories, night prayers) from the Android app's
# SleepStories*.kt to JSON, with Android's storyPauses already applied (each pause about a third, 1 to 4 seconds).
# Usage: ANDROID_DATA=<android>/app/src/main/kotlin/com/holysteps/app/data/ python3 tools/sleep2json.py out.json
import re, json, sys, os, glob, textwrap
base = os.environ.get('ANDROID_DATA', 'app/src/main/kotlin/com/holysteps/app/data/')
FREE = {"story_david_stars", "story_calm_storm", "kids_noah_boat", "night_psalm4"}
LISTS = {'BIBLE_SLEEP_STORIES': 'story', 'BIBLE_KIDS_STORIES': 'kids', 'NIGHT_PRAYERS': 'night'}
call = re.compile(r'\b(\w+)\(\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)",(.*?)"""(.*?)"""', re.S)
def kstr(s): return s.replace('\\"', '"').replace('\\$', '$').replace("\\'", "'")
def pauses(s): return re.sub(r'\[PAUSE (\d+) SECONDS]', lambda m: f"[PAUSE {min(4, max(1, round(int(m.group(1)) * 0.35)))} SECONDS]", s)
out = []
for f in sorted(glob.glob(base + 'SleepStories*.kt')):
    src = open(f).read()
    heads = [(m.start(), m.group(1)) for m in re.finditer(r'internal val (\w+): List<SanctuaryJourney>', src)]
    for i, (start, name) in enumerate(heads):
        kind = next((k for key, k in LISTS.items() if name.endswith(key)), None)
        if not kind: continue
        body = src[start:heads[i + 1][0] if i + 1 < len(heads) else len(src)]
        for m in call.finditer(body):
            fn, ident, title, sub, _, script = m.groups()
            s = script.replace("${'$'}", "$"); assert '${' not in s, ident
            out.append(dict(id=ident, kind=kind, title=kstr(title), subtitle=kstr(sub), free=ident in FREE,
                            script=pauses(textwrap.dedent(s).strip('\n'))))
ids = [o['id'] for o in out]; assert len(ids) == len(set(ids))
from collections import Counter; print(Counter(o['kind'] for o in out), len(out))
json.dump(out, open(sys.argv[1], 'w'), ensure_ascii=False)
