#!/usr/bin/env python3
"""Merges a gen_bible_packs.py index-part.json into the server's voice/index.json (run on the server, after copying
the .pack/.json files into voice/<voice>/).  python3 merge_voice_index.py /path/to/voice/index.json es_heart part.json"""
import json, sys, datetime, os
index_path, voice, part_path = sys.argv[1:4]
idx = json.load(open(index_path))
idx.setdefault("voices", {}).setdefault(voice, {}).setdefault("packs", {}).update(json.load(open(part_path)))
idx["generated"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
json.dump(idx, open(index_path + ".tmp", "w")); os.replace(index_path + ".tmp", index_path)
print("merged", voice, len(json.load(open(part_path))), "packs")
