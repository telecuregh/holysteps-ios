#!/usr/bin/env python3
# Extracts Android's cycle phase plans (data/AppState.kt phasePool) to JSON.
# Usage: ANDROID_DATA=<android>/app/src/main/kotlin/com/holysteps/app/data/ python3 tools/cycleplans2json.py out.json
import re, json, sys, os
base = os.environ.get('ANDROID_DATA', 'app/src/main/kotlin/com/holysteps/app/data/')
src = open(base + 'AppState.kt').read()
body = src[src.index('private fun phasePool('):src.index('fun phasePlan(')]
STR = r'"((?:[^"\\]|\\.)*)"'
out = {}
parts = re.split(r'CyclePhase\.(\w+) -> PhasePool\(', body)[1:]
for name, block in zip(parts[0::2], parts[1::2]):
    plan = {}
    for m in re.finditer(r'(\w+) = (listOf\((.*?)\n\s*\)|' + STR + r'|([0-9.]+))', block, re.S):
        key = m.group(1)
        if m.group(3) is not None: plan[key] = [s.replace('\\"', '"') for s in re.findall(STR, m.group(3))]
        elif m.group(4) is not None: plan[key] = m.group(4).replace('\\"', '"')
        else: plan[key] = float(m.group(5))
    out[name.lower()] = plan
assert set(out) == {'menstrual', 'follicular', 'ovulation', 'luteal'}, out.keys()
for k, v in out.items(): assert len(v) == 11, (k, sorted(v))
json.dump(out, open(sys.argv[1], 'w'), ensure_ascii=False, indent=1)
print({k: len(v['moveIdeasPool']) for k, v in out.items()})
