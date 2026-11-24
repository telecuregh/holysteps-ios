#!/usr/bin/env python3
# Extracts the devotional plans from the Android app's ui/screens/DevotionalScreen.kt to JSON.
# Usage: python3 tools/devotionals2json.py <DevotionalScreen.kt> Resources/devotionals.json
import re, json, sys
src = open(sys.argv[1]).read()
S = r'"((?:[^"\\]|\\.)*)"'
def k(s): return s.replace('\\"', '"').replace('\\$', '$').replace('\\n', '\n')
plans = []
for m in re.finditer(r'val (\w+)_PLAN = DevotionalPlan\(\s*id = ' + S + r',\s*title = ' + S + r',\s*subtitle = ' + S +
                     r',\s*emoji = ' + S + r',\s*colorHex = ' + S + r',\s*forGender = ([\w.]+),\s*days = listOf\((.*?)\n\s*\)\s*\n\)', src, re.S):
    _, pid, title, sub, emoji, color, gender, body = m.groups()
    days = [dict(day=int(d[0]), title=k(d[1]), scripture=k(d[2]), reference=k(d[3]), body=k(d[4]), prayer=k(d[5]), challenge=k(d[6]))
            for d in re.findall(r'DevotionalDay\(\s*(\d+),\s*' + r',\s*'.join([S] * 6) + r'\s*\)', body)]
    g = {'UserGender.FEMALE': 'female', 'UserGender.MALE': 'male'}.get(gender)
    plans.append(dict(id=pid, title=k(title), subtitle=k(sub), emoji=k(emoji), color=color, gender=g, days=days))
for p in plans:
    assert [d['day'] for d in p['days']] == list(range(1, len(p['days']) + 1)), p['id']
print([(p['id'], len(p['days'])) for p in plans])
json.dump(plans, open(sys.argv[2], 'w'), ensure_ascii=False, indent=0)
