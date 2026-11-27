#!/usr/bin/env python3
"""Records Resources/mind_stories.json in Grace's Kokoro voice (af_heart) as HolySteps voice packs, one pack per story
(pack id "j_<story id>", the id Sermon.packId asks for). Each spoken paragraph is one MP3 clip, keyed exactly like
Narration.key in Sermon.swift, so SermonPlayer finds every line. Resumable: finished stories are skipped.

  python3 tools/gen_story_packs.py --models ~/HolyStepsVoice/models --out ~/HolyStepsVoice

Then copy OUT/af_heart/*.pack and *.json into the server's voice/af_heart/ and merge the index:
  python3 tools/merge_voice_index.py /path/to/voice/index.json af_heart OUT/af_heart/index-part.json
Needs: pip install kokoro-onnx soundfile; ffmpeg.
"""
import argparse, hashlib, json, os, re, subprocess, sys, tempfile, time

def narration(c):                                      # Narration.spoken (Sermon.swift)
    c = c.replace("LORD", "Lord").replace("GOD", "God").replace(" — ", ", ").replace("—", ", ").replace("…", "...").replace(" · ", ", ")
    c = re.sub(r"(\d+)\s*/\s*(\d+)", r"\1 of \2", c).replace("°", " degrees")
    return re.sub(r"\s+", " ", c).strip()

def key(text): return hashlib.sha1(narration(text).encode()).hexdigest()[:16]

def speech_segments(script):                           # Sermon.parse: paragraphs; bracketed lines are not spoken
    out, para = [], []
    def flush():
        t = re.sub(r"\s+", " ", " ".join(para)).strip()
        if t: out.append(t)
        para.clear()
    for raw in script.split("\n"):
        line = raw.strip()
        if not line: flush()
        elif line.startswith("[") and line.endswith("]"): flush()
        else: para.append(line)
    flush()
    return out

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser()
    ap.add_argument("--stories", nargs="+", default=[os.path.join(root, "Resources", "mind_stories.json")],
                    help="one or more JSON lists of {id, title, script} (stories, and sessions from export_mind_sessions.py)")
    ap.add_argument("--voice", default="af_heart")
    ap.add_argument("--speed", type=float, default=1.05)   # a touch brisk, like Joel
    ap.add_argument("--out", default=os.path.expanduser("~/HolyStepsVoice"))
    ap.add_argument("--models", default=os.path.expanduser("~/HolyStepsVoice/models"))
    ap.add_argument("--limit", type=int, default=0)
    a = ap.parse_args()

    from kokoro_onnx import Kokoro
    import soundfile as sf
    k = Kokoro(os.path.join(a.models, "kokoro-v1.0.onnx"), os.path.join(a.models, "voices-v1.0.bin"))
    stories = [x for f in a.stories for x in json.load(open(f))]
    out = os.path.join(a.out, a.voice); os.makedirs(out, exist_ok=True)
    part_path = os.path.join(out, "index-part.json")
    part = json.load(open(part_path)) if os.path.exists(part_path) else {}
    todo = [s for s in stories if f"j_{s['id']}" not in part]
    print(f"{len(stories)} stories, {len(stories) - len(todo)} done, {len(todo)} to record", flush=True)
    done = 0
    for s in todo:
        pid, t0 = f"j_{s['id']}", time.time()
        blob, clips = bytearray(), {}
        with tempfile.TemporaryDirectory() as tmp:
            for text in speech_segments(s["script"]):
                kk = key(text)
                if kk in clips: continue
                audio, sr = k.create(narration(text), voice=a.voice, speed=a.speed, lang="en-us")
                wav, mp3 = os.path.join(tmp, "v.wav"), os.path.join(tmp, "v.mp3")
                sf.write(wav, audio, sr)
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-ac", "1", "-ar", "24000", "-b:a", "48k", mp3], check=True)
                m = open(mp3, "rb").read()
                clips[kk] = [len(blob), len(m), int(round(len(audio) / sr * 1000))]
                blob += m
        sha = hashlib.sha256(blob).hexdigest()
        name = f"{pid}.{sha[:12]}"
        open(os.path.join(out, name + ".pack"), "wb").write(blob)
        json.dump({"clips": clips}, open(os.path.join(out, name + ".json"), "w"))
        part[pid] = {"file": name + ".pack", "json": name + ".json", "bytes": len(blob), "sha256": sha}
        json.dump(part, open(part_path + ".tmp", "w")); os.replace(part_path + ".tmp", part_path)
        done += 1
        secs = sum(c[2] for c in clips.values()) / 1000
        print(f"[{done}/{len(todo)}] {s['title']}: {len(clips)} clips, {secs/60:.1f} min audio, {len(blob)/1e6:.1f} MB, took {time.time()-t0:.0f}s", flush=True)
        if a.limit and done >= a.limit: break
    print("Done:", out)

if __name__ == "__main__":
    sys.exit(main())
