#!/usr/bin/env python3
"""Builds Resources/mind_talks.json from mind_talks_men.py and mind_talks_women.py: everyday (non-faith) mental
health talks for the two hubs, read by Grace, each with the sources it cites. python3 tools/mind_talks.py"""
import json, os, importlib.util
here = os.path.dirname(os.path.abspath(__file__))
def load(n):
    spec = importlib.util.spec_from_file_location(n, os.path.join(here, n + ".py")); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m.T
talks = load("mind_talks_men") + load("mind_talks_women")
ids = [t["id"] for t in talks]; assert len(ids) == len(set(ids))
for t in talks:
    assert t["sources"], t["id"]
    low = t["script"].lower()
    for w in (" god", "jesus", "scripture", "bible", "pray", "lord", "church"): assert w not in low, (t["id"], w)
out = os.path.join(os.path.dirname(here), "Resources", "mind_talks.json")
json.dump(talks, open(out, "w"), ensure_ascii=False, indent=1)
for t in talks: print(f'{t["hub"]:6} {t["category"]:11} {len(t["script"].split()):4}w  {t["title"]}')
print(len(talks), "talks ->", out)
