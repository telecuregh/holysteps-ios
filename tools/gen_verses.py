# Records the home screen's daily verses with Kokoro (Grace, af_heart) into Resources/verses.
# Needs: pip install kokoro-onnx soundfile; kokoro-v1.0.onnx and voices-v1.0.bin in /tmp; ffmpeg. Run from the repo root.
import re, subprocess, json, sys, soundfile as sf
from kokoro_onnx import Kokoro
src = open('Sources/Core/Content.swift', encoding='utf-8').read()
verses = re.findall(r'Verse\(id: (\d+), ref: "([^"]+)", text: "([^"]+)", es: "([^"]+)"\)', src)
es_tab = json.loads(subprocess.run("zcat Resources/es.json.gz", shell=True, capture_output=True).stdout)
def spoken_ref(ref, lang):
    book, cv = ref.rsplit(' ', 1)
    ch, vs = cv.split(':')
    if lang == 'es':
        book = "Salmo" if book == "Psalm" else es_tab.get(book, book)
        if '-' in vs: a, b = vs.split('-'); return f"{book} {ch}, versículos {a} y {b}"
        return f"{book} {ch}, versículo {vs}"
    if '-' in vs: a, b = vs.split('-'); return f"{book} {ch}, verses {a} and {b}"
    return f"{book} {ch}, verse {vs}"
def clean(t):
    t = t.replace('LORD', 'Lord').replace('GOD', 'God')
    return re.sub(r'\bá\b', 'a', t)  # RV1909 accent on "á" reads oddly
k = Kokoro('/tmp/kokoro.onnx', '/tmp/voices.bin')
for vid, ref, en, es in verses:
    for lang, text, code in (('en', en, 'en-us'), ('es', es, 'es')):
        line = f"{clean(text)} ... {spoken_ref(ref, lang)}."
        audio, sr = k.create(line, voice='af_heart', speed=1.0, lang=code)
        wav = f'/tmp/v_{vid}_{lang}.wav'; sf.write(wav, audio, sr)
        out = f'Resources/verses/verse_{vid}_{lang}.mp3'
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-ac', '1', '-ar', '24000', '-b:a', '48k', out], check=True)
        print(vid, lang, round(len(audio) / sr, 1), 's |', line)
