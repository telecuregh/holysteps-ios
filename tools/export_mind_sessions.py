#!/usr/bin/env python3
"""Exports the everyday audio sessions (MensMindSession / WomenMindSession literals in the Swift sources) to JSON,
so tools/gen_story_packs.py can record them in Grace's voice as packs "j_<session id>".
  python3 tools/export_mind_sessions.py out.json"""
import json, os, re, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
pat = re.compile(r'(?:Mens|Women)MindSession\(\s*id:\s*"([^"]+)",\s*title:\s*"([^"]*)".*?script:\s*"""\n(.*?)\n"""', re.S)
out = []
for f in ("Sources/Screens/MensHealth.swift", "Sources/Screens/WomenMindView.swift"):
    for m in pat.finditer(open(os.path.join(root, f)).read()):
        out.append(dict(id=m.group(1), title=m.group(2), script=m.group(3)))
assert len({o["id"] for o in out}) == len(out)
json.dump(out, open(sys.argv[1], "w"), ensure_ascii=False)
print(len(out), "sessions")
