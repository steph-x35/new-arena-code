#!/usr/bin/env python3
"""Lounge-bar jazz chill per la vita nel gioco (città + edifici), v2.1.0.
Loop di 16 battute a 70 bpm con swing: basso walking, Rhodes (7a/9a), brushes,
vibes e piccola stanza (murmur + clink). Audio procedurale, nessuna licenza.
Uso:  python3 tools/gen_lounge.py   (dalla root del progetto hoopcity)
"""
import math, wave, os
import numpy as np

SR = 22050
BPM = 70.0
BEAT = 60.0 / BPM            # 0.857 s
BAR = 4.0 * BEAT             # 3.429 s
BARS = 16
N = int(round(BARS * BAR * SR))
rng = np.random.default_rng(20260914)

def mfreq(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)

def place(buf, sig, t_s, gain=1.0):
    """Somma con wrap-around: il loop resta seamless anche con le code."""
    s = int(round(t_s * SR)) % N
    L = len(sig)
    if s + L <= N:
        buf[s:s + L] += sig * gain
    else:
        k = N - s
        buf[s:] += sig[:k] * gain
        buf[:L - k] += sig[k:] * gain

def env_pluck(n, a_s, tau):
    t = np.arange(n) / SR
    e = np.minimum(t / max(a_s, 1e-4), 1.0) * np.exp(-t / tau)
    return e

def lp(x, cut):
    a = math.exp(-2 * math.pi * cut / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = a * acc + (1 - a) * v
        y[i] = acc
    return y

def lpx(x, cut):
    # one-pole con lru-lite: sufficiente per texture
    a = math.exp(-2 * math.pi * cut / SR)
    y = np.empty_like(x)
    acc = 0.0
    c = 1 - a
    for i in range(len(x)):
        acc = a * acc + c * x[i]
        y[i] = acc
    return y

# ---------------------------------------------------------------- strumenti
def bass_note(m, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = mfreq(m)
    x = np.sin(2 * np.pi * f * t) + 0.38 * np.sin(2 * np.pi * 2 * f * t) \
        + 0.10 * np.sin(2 * np.pi * 3 * f * t)
    x = np.tanh(1.6 * x) * env_pluck(n, 0.005, 0.30)
    return lp(x, 900.0)

def rhodes(m, dur, bright=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = mfreq(m)
    x = 0.60 * np.sin(2 * np.pi * f * 1.0015 * t) \
        + 0.60 * np.sin(2 * np.pi * f * 0.9985 * t) \
        + 0.16 * bright * np.sin(2 * np.pi * 2 * f * t) \
        + 0.05 * bright * np.sin(2 * np.pi * 4.01 * f * t)
    e = np.minimum(t / 0.012, 1.0) * np.exp(-t / (dur * 0.42))
    click = np.zeros(n)
    k = int(0.008 * SR)
    click[:k] = rng.uniform(-1, 1, k) * np.linspace(1, 0, k)
    return (x * e + 0.05 * click) * 0.9

def ride_tick(vel):
    n = int(0.09 * SR)
    x = rng.uniform(-1, 1, n)
    x = x - lp(x, 3500.0)                       # hp
    ring = np.sin(2 * np.pi * 5600 * np.arange(n) / SR) * np.exp(-np.arange(n) / (SR * 0.014))
    return (0.7 * x + 0.5 * ring) * env_pluck(n, 0.001, 0.02) * vel

def brush_swish(vel):
    n = int(0.30 * SR)
    x = rng.uniform(-1, 1, n)
    x = lp(x, 3800.0) - lp(x, 700.0)            # band
    e = np.minimum(np.arange(n) / (SR * 0.075), 1.0) * np.exp(-np.arange(n) / (SR * 0.11))
    return x * e * vel

def soft_kick():
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    f = 82 * np.exp(-t * 26) + 42
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t / 0.075)

def vibe_note(m, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = mfreq(m)
    vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(t / 0.25, 1.0)
    ph = 2 * np.pi * f * np.cumsum(vib) / SR
    x = np.sin(ph) + 0.30 * np.sin(2 * ph) + 0.10 * np.sin(3.003 * ph)
    e = np.minimum(t / 0.03, 1.0) * np.exp(-t / (dur * 0.65))
    return lp(x * e, 2400.0)

def clink():
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 2093 * t) + 0.6 * np.sin(2 * np.pi * 2734 * t)
    x *= np.exp(-t / 0.09) * env_pluck(n, 0.001, 0.05)
    return lp(x, 6000.0)

# ---------------------------------------------------------------- progressione
# (bass_root, [voicing], [scale per il lead])
PROG = [
    (38, [53, 57, 60, 64], [62, 65, 67, 69, 72]),   # Dm9
    (43, [59, 62, 64, 69], [62, 64, 67, 69, 71]),   # G13
    (36, [55, 59, 62, 64], [64, 67, 69, 71, 74]),   # Cmaj9
    (45, [55, 57, 60, 64], [60, 64, 67, 69, 72]),   # Am9
    (38, [53, 57, 60, 64], [62, 65, 67, 69, 72]),   # Dm9
    (43, [59, 62, 64, 69], [62, 64, 67, 69, 71]),   # G13
    (40, [52, 55, 59, 62], [62, 64, 67, 69, 71]),   # Em7
    (45, [61, 64, 66, 67], [61, 64, 66, 69, 73]),   # A13
    (41, [57, 60, 64, 67], [60, 64, 65, 69, 72]),   # Fmaj9
    (40, [52, 55, 59, 62], [62, 64, 67, 69, 71]),   # Em7
    (38, [53, 57, 60, 64], [62, 65, 67, 69, 72]),   # Dm9
    (43, [59, 62, 64, 69], [62, 64, 67, 69, 71]),   # G13
    (36, [55, 59, 62, 64], [64, 67, 69, 71, 74]),   # Cmaj9
    (36, [55, 59, 62, 64], [64, 67, 69, 71, 74]),   # Cmaj9 (variatio)
    (46, [58, 62, 65, 69], [65, 67, 70, 74, 77]),   # Bb13 (turnaround)
    (43, [59, 62, 64, 69], [62, 64, 67, 69, 71]),   # G13 (ritorno a Dm)
]

buf = np.zeros(N)

# ---------------------------------------------------------------- basso walking
for b in range(BARS):
    root, _, _ = PROG[b]
    nxt_root = PROG[(b + 1) % BARS][0]
    b2 = root + int(rng.choice([3, 4, 7]))
    b3 = root + 7
    appr = nxt_root + (1 if (nxt_root - (root + 7)) > 0 else -1)
    for beat, m in enumerate([root, b2, b3, appr]):
        g = 0.34 if beat == 0 else 0.28
        place(buf, bass_note(m, BEAT * 0.98), b * BAR + beat * BEAT, g)

# ---------------------------------------------------------------- rhodes
for b in range(BARS):
    _, voicing, _ = PROG[b]
    t0 = b * BAR
    # accordo lungo sul 1
    for m in voicing:
        place(buf, rhodes(m, 2.3, bright=1.0), t0 + rng.uniform(0.0, 0.012), 0.085)
    # spinta morbida: swing "and" di 2 oppure sul 3
    if rng.random() < 0.85:
        tpush = t0 + (2 + 0.62) * BEAT if rng.random() < 0.55 else t0 + 3 * BEAT
        up = [m + 12 for m in voicing[1:]]
        for m in up:
            place(buf, rhodes(m, 0.7, bright=1.2), tpush + rng.uniform(0.0, 0.01), 0.045)

# ---------------------------------------------------------------- drums
for b in range(BARS):
    t0 = b * BAR
    # ride swing 8th
    for k in range(4):
        place(buf, ride_tick(0.50 + 0.10 * rng.random()), t0 + k * BEAT, 0.16)
        place(buf, ride_tick(0.30 + 0.10 * rng.random()), t0 + (k + 0.62) * BEAT, 0.12)
    # brushes su 2 e 4
    for k in [1, 3]:
        place(buf, brush_swish(0.75 + 0.25 * rng.random()), t0 + k * BEAT, 0.30)
    # kick morbido sul 1, a volte sul 3
    place(buf, soft_kick(), t0, 0.42)
    if rng.random() < 0.35:
        place(buf, soft_kick(), t0 + 2 * BEAT, 0.30)

# ---------------------------------------------------------------- lead (vibes)
PHRASE_BARS = set(range(4, 8)) | set(range(10, 15))
for b in range(BARS):
    if b not in PHRASE_BARS or rng.random() < 0.35:
        continue
    _, _, scale = PROG[b]
    t0 = b * BAR + rng.choice([0.0, 0.62, 1.0, 1.62]) * BEAT
    notes = rng.integers(4, 7)
    tt = t0
    for i in range(notes):
        m = int(rng.choice(scale) + 12 * rng.choice([0, 0, 1]))
        d = float(rng.uniform(0.35, 0.95))
        place(buf, vibe_note(m, d), tt, 0.115)
        tt += d * float(rng.uniform(0.85, 1.25))
        if tt >= (b + 1) * BAR + 1 * BEAT:
            break

# ---------------------------------------------------------------- stanza
murk = lp(rng.uniform(-1, 1, N), 420.0)
wob = 0.55 + 0.45 * np.sin(2 * np.pi * 0.05 * np.arange(N) / SR + 1.2)
buf += murk * wob * 0.028
for ts in [7.3, 23.9, 41.2]:
    place(buf, clink(), ts + rng.uniform(0, 0.5), 0.10)

# ---------------------------------------------------------------- spazio
for d_s, g in [(0.089, 0.20), (0.131, 0.13)]:
    d = int(d_s * SR)
    echo = np.zeros(N)
    echo[d:] = buf[:-d] * g
    buf += echo

# ---------------------------------------------------------------- misure
pk = float(np.max(np.abs(buf)))
buf = buf / pk * 0.5
out = (np.clip(buf, -1, 1) * 32767).astype(np.int16)

here = os.path.dirname(os.path.abspath(__file__))
outp = os.path.join(here, "..", "assets", "sfx", "music_lounge.wav")
with wave.open(outp, "w") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(out.tobytes())
print("wrote", os.path.normpath(outp), len(out) / SR, "s")
