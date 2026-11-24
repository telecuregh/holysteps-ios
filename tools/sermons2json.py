#!/usr/bin/env python3
# Extracts the sermon library from the Android app (Sermons.kt, FacingSermons.kt, BibleSermons.kt) to JSON.
# Usage: ANDROID_DATA=<android>/app/src/main/kotlin/com/holysteps/app/data/ python3 tools/sermons2json.py out.json
# then: drop the "preacher" field and gzip -9 into Resources/sermons.json.gz
import re, json, sys, textwrap
import os
base=os.environ.get('ANDROID_DATA', 'app/src/main/kotlin/com/holysteps/app/data/')  # Android repo's data folder
pat=re.compile(r'\b(recordedSermon|sermon|rec)\(\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)",\s*SceneKind\.(\w+),(.*?)"""(.*?)"""\s*\)', re.S)
def kstr(s): return s.replace('\\"','"').replace('\\$','$').replace("\\'", "'").replace('\\n','\n')
def raw(s):
    s=s.replace("${'$'}", "$")
    assert '${' not in s, s[:200]
    return textwrap.dedent(s).strip('\n')
out=[]
for fname, group, prefix in [('Sermons.kt','weekly','sermon_'),('FacingSermons.kt','facing','sermon_facing_'),('BibleSermons.kt',None,'sermon_')]:
    src=open(base+fname).read()
    seasons_at = src.find('val SEASONS') if fname=='BibleSermons.kt' else -1
    for m in pat.finditer(src):
        kind,ident,title,sub,scene,mid,script=m.groups()
        if kind=='sermon' and 'fun sermon' in src[max(0,m.start()-20):m.start()+5]: continue
        urls=re.findall(r'"(https://[^"]+)"', mid)
        g = group or ('seasons' if m.start()>seasons_at else 'books')
        out.append(dict(id=prefix+ident, group=g, title=kstr(title), subtitle=kstr(sub), scene=scene,
                        recorded=urls, preacher=(kind=='sermon'), script=raw(script)))
ids=[o['id'] for o in out]; assert len(ids)==len(set(ids)), [i for i in ids if ids.count(i)>1]
from collections import Counter
print(Counter(o['group'] for o in out), 'preacher', sum(o['preacher'] for o in out))
json.dump(out, open(sys.argv[1],'w'), ensure_ascii=False)
