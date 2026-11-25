#!/usr/bin/env python3
"""Records the whole Bible in Grace's Kokoro voice as HolySteps voice packs (the format VoicePacks.swift and
Android's VoicePacks.kt read): one pack per chapter, each verse its own MP3 (24 kHz mono 48 kbps) joined into
<pack>.<sha12>.pack, plus <pack>.<sha12>.json {"clips": {key: [offset, length, ms]}} where key is the first 16 hex
digits of SHA-1 of the spoken verse.

Resumable: a chapter whose pack is already in the output folder (or in the live holysteps.org index) is skipped, so it
can be stopped and started again any time. When done (or any time), copy OUT/<voice>/ into the server's voice folder
and merge OUT/<voice>/index-part.json into the server's voice/index.json (tools/merge_voice_index.py).

  python3 gen_bible_packs.py --translation KJV  --voice af_heart --lang en-us   # English, Grace
  python3 gen_bible_packs.py --translation RVES --voice es_heart --lang es      # Spanish, Grace

Needs: pip install kokoro-onnx soundfile; ffmpeg; kokoro-v1.0.onnx + voices-v1.0.bin (downloaded on first run).
"""
import argparse, gzip, hashlib, json, os, re, subprocess, sys, tempfile, time, urllib.request

BIBLE = "https://holysteps.org/bible/"
VOICE = "https://holysteps.org/voice/"
MODEL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/"
PREFIX = {"KJV": "bkjv", "RVES": "brves"}            # must match VoicePacks.biblePackId
KOKORO_VOICE = {"af_heart": "af_heart", "es_heart": "af_heart", "am_michael": "am_michael"}  # es_heart = Grace speaking Spanish

def spoken_verse(s):                                   # Spoken.verse (BibleExtras.swift)
    t = s.replace("[", "").replace("]", "")
    t = re.sub(r"(?<=[^\W\d_])[–‐](?=[^\W\d_])", "-", t)
    t = re.sub(r"\bLORD\b", "Lord", t); t = re.sub(r"\bGOD\b", "God", t)
    return t.replace("…", "...")

def narration(c):                                      # Narration.spoken (Sermon.swift)
    c = c.replace("LORD", "Lord").replace("GOD", "God").replace(" — ", ", ").replace("—", ", ").replace("…", "...").replace(" · ", ", ")
    c = re.sub(r"(\d+)\s*/\s*(\d+)", r"\1 of \2", c).replace("°", " degrees")
    return re.sub(r"\s+", " ", c).strip()

def key(text): return hashlib.sha1(narration(text).encode()).hexdigest()[:16]

def slug(book): return re.sub(r"[^a-z0-9]+", "_", book.lower()).strip("_")

def fetch(url, dest=None):
    req = urllib.request.Request(url, headers={"User-Agent": "HolySteps-packs"})
    data = urllib.request.urlopen(req, timeout=300).read()
    if dest: open(dest, "wb").write(data)
    return data

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--translation", default="KJV", choices=sorted(PREFIX))
    ap.add_argument("--voice", default="af_heart")
    ap.add_argument("--lang", default="en-us")
    ap.add_argument("--speed", type=float, default=1.0)
    ap.add_argument("--out", default=os.path.expanduser("~/HolyStepsVoice"))
    ap.add_argument("--models", default=os.path.expanduser("~/HolyStepsVoice/models"))
    ap.add_argument("--only", help="one book, e.g. Psalms (for testing)")
    ap.add_argument("--limit", type=int, default=0, help="stop after this many chapters (0 = all)")
    a = ap.parse_args()

    os.makedirs(a.models, exist_ok=True)
    for f in ("kokoro-v1.0.onnx", "voices-v1.0.bin"):
        p = os.path.join(a.models, f)
        if not os.path.exists(p):
            print("Downloading", f, "..."); fetch(MODEL + f, p)
    from kokoro_onnx import Kokoro
    import soundfile as sf
    k = Kokoro(os.path.join(a.models, "kokoro-v1.0.onnx"), os.path.join(a.models, "voices-v1.0.bin"))

    idx = json.loads(fetch(BIBLE + "index.json"))
    t = next(x for x in idx["translations"] if x["id"] == a.translation)
    bible = json.loads(gzip.decompress(fetch(BIBLE + t["file"])))
    try: live = set(json.loads(fetch(VOICE + "index.json"))["voices"].get(a.voice, {}).get("packs", {}))
    except Exception: live = set()

    out = os.path.join(a.out, a.voice); os.makedirs(out, exist_ok=True)
    part_path = os.path.join(out, "index-part.json")
    part = json.load(open(part_path)) if os.path.exists(part_path) else {}
    chapters = [(b["n"], i + 1, c) for b in bible["books"] for i, c in enumerate(b["c"]) if not a.only or a.only in (b["n"], b.get("d"))]
    todo = [x for x in chapters if f"{PREFIX[a.translation]}_{slug(x[0])}_{x[1]}" not in live | set(part)]
    print(f"{a.translation} / {a.voice}: {len(chapters)} chapters, {len(chapters) - len(todo)} already done, {len(todo)} to record")
    start, done = time.time(), 0
    for book, ch, verses in todo:
        pid = f"{PREFIX[a.translation]}_{slug(book)}_{ch}"
        blob, clips = bytearray(), {}
        with tempfile.TemporaryDirectory() as tmp:
            for v in verses:
                text = spoken_verse(v)
                if not text.strip(): continue
                kk = key(text)
                if kk in clips: continue
                audio, sr = k.create(narration(text), voice=KOKORO_VOICE.get(a.voice, a.voice), speed=a.speed, lang=a.lang)
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
        per = (time.time() - start) / done
        print(f"[{done}/{len(todo)}] {book} {ch} ({len(clips)} verses) · about {per * (len(todo) - done) / 3600:.1f} h left", flush=True)
        if a.limit and done >= a.limit: break
    print("Done. Upload", out, "to the server's voice folder and merge index-part.json.")

if __name__ == "__main__":
    sys.exit(main())
