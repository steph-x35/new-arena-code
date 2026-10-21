#!/usr/bin/env python3
"""Audio v2.1.2: palleggio realistico (ricerca: slap di cuoio + tonfo + legno),
voci di campo afro-inglesi (F0 bassa, vocali pure, sillabe marcate), traffico
cittadino costante, squeak piu' caldo. Tutto procedurale, nessuna licenza.
Uso:  python3 tools/gen_v212_audio.py   (dalla root del progetto hoopcity)
"""
import math, wave, os
import numpy as np

SR = 22050
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "sfx")
rng = np.random.default_rng(20260916)

def save(name, x, peak=0.5):
    pk = max(1e-9, float(np.max(np.abs(x))))
    x = x / pk * peak
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print("wrote", name, round(len(x) / SR, 2), "s")

def noise(n):
    return rng.uniform(-1.0, 1.0, n)

def onepole(x, cut, hp=False):
    a = math.exp(-2 * math.pi * cut / SR)
    y = np.empty_like(x); acc = 0.0; c = 1 - a
    for i, v in enumerate(x):
        acc = a * acc + c * v; y[i] = acc
    return x - y if hp else y

def band(x, lo, hi):
    return onepole(x, hi) - onepole(x, lo)

def env_ar(n, a_s, tau):
    t = np.arange(n) / SR
    return np.minimum(t / max(a_s, 1e-4), 1.0) * np.exp(-t / tau)

# ------------------------------------------------------------------ palleggio
def dribble(seed, hard=1.0):
    """Palleggio vero su parquet, in tre strati (descrizioni acustiche
    standard del rimbalzo del basket):
      1. SLAP di cuoio: transient broadband 0.7-2.8 kHz, attacco 2 ms,
         decadimento 18 ms  -> il 'pak' che si sente da lontano
      2. CORPO della palla: risonanza a compressione ~150 Hz che scende
         (la pelle si schiaccia), 60 ms
      3. PARQUET: colpo sordo basso sotto 200 Hz + riflesso della stanza.
    Tre prese con seed diversi, come le vere palleggiate: mai identiche."""
    dur = 0.16
    n = int(dur * SR)
    tt = np.arange(n) / SR
    slap = band(noise(n), 700, 2800) * env_ar(n, 0.002, 0.018) * hard
    f_body = 155 * np.exp(-tt * 20) + 78
    ph = 2 * math.pi * np.cumsum(f_body) / SR
    body = np.sin(ph) * env_ar(n, 0.001, 0.030) * 0.9
    wood = onepole(noise(n), 210) * env_ar(n, 0.001, 0.020) * 0.7
    room = onepole(noise(n), 130) * env_ar(n, 0.002, 0.045) * 0.35
    out = slap * 0.95 + body + wood + room * 0.5
    return out

def bounces():
    save("bounce1.wav", dribble(101, 1.00), 0.62)
    save("bounce2.wav", dribble(202, 0.94), 0.62)
    save("bounce3.wav", dribble(303, 1.05), 0.62)

# ------------------------------------------------------------------ squeak
def squeak():
    dur = 0.17
    n = int(dur * SR)
    tt = np.arange(n) / SR
    f = np.where(tt < 0.06,
                 2100 + (3400 - 2100) * (tt / 0.06),
                 3400 - (3400 - 2800) * ((tt - 0.06) / 0.11))
    ph = 2 * math.pi * np.cumsum(f) / SR
    am = 0.55 + 0.45 * np.sin(2 * math.pi * 71 * tt + rng.uniform(0, 6))
    x = np.sin(ph) * am
    x += band(noise(n), 2400, 6200) * 0.45
    x *= 1.0 - 0.25 * np.sin(2 * math.pi * 9.3 * tt + 1.0)
    save("squeak.wav", x * env_ar(n, 0.004, 0.055), 0.74)

# ------------------------------------------------------------------ traffico
def traffic_loop():
    """Strada sempre viva ma costante: lavaggio basso stabile (niente buchi),
    ondulazione leggera (max +-15%) e passaggi lontani ogni tanto. Seamless."""
    dur, xf = 10.0, 0.4
    n = int(dur * SR)
    nf = n + int(xf * SR)
    tt = np.arange(nf) / SR
    bed = onepole(noise(nf), 300)
    wob = 1.0 + 0.15 * np.sin(2 * math.pi * 0.07 * tt + 0.8)
    x = bed * wob * 0.9
    # passaggi lontani: whoosh band con inviluppo dolce
    for t0, durp, f_c in [(1.7, 1.5, 480), (5.1, 1.9, 380), (8.1, 1.4, 520)]:
        nn = int(durp * SR)
        s0 = int(t0 * SR)
        w = band(noise(nn), f_c * 0.5, f_c * 2.2)
        e = np.sin(np.linspace(0, math.pi, nn)) ** 1.5
        x[s0:s0 + nn] += w * e * 0.55
    k = int(xf * SR)
    fade = np.linspace(0, 1, k)
    head = x[n:n + k] * fade + x[:k] * (1 - fade)
    out = np.concatenate([head, x[k:n]])
    save("traffic_loop.wav", out, 0.34)

# ------------------------------------------------------------------ voci
# Vocali PURE (inglese africano / ouest-africano: monottonghi chiari,
# sillabe scandite). [F1, F2] con F3 fisso nel filtro.
VOWELS = {
    "e":  (480, 1900),   # de-FENSE: 'e' pura, non inglese 'ɪ'
    "ɛ":  (600, 1150),   # FENS aperta
    "a":  (760, 1200),   # 'a' aperta centrale (PASS, NICE-ah)
    "ɑ":  (720, 990),    # BALL africano: 'o' aperta, non dittongo
    "ɔ":  (560, 880),    # o chiusa pura (ALL/DO-AH)
    "o":  (430, 750),    # GO/NO pura
    "u":  (320, 800),    # SHOOT: u lunga pura
    "i":  (300, 2150),   # RE-BOUND: i netta
    "I":  (380, 2000),   # NICE: 'i' con scivolata su a
    "ai": (700, 1100),   # itaino dittongo gestito a mano (due tap)
}

def resonator(x, F, BW):
    Fv = np.full(len(x), float(F)) if np.isscalar(F) else F
    y = np.empty_like(x); y0 = y1 = 0.0
    for i in range(len(x)):
        r = math.exp(-math.pi * BW / SR)
        b = 2 * r * math.cos(2 * math.pi * Fv[i] / SR)
        c = -r * r
        a = 1 - b - c
        y0, y1 = a * x[i] + b * y0 + c * y1, y0
        y[i] = y0
    return y

def shout(sylls, f0_c, seed, total):
    """Voce afro-inglese: F0 bassa con caduta marcata, vocali pure scandite
    (ritmo sillabico), consonanti secche e chiare, respiro prima del grido."""
    n = int(total * SR)
    tt = np.arange(n) / SR
    jr = np.random.default_rng(seed)
    f0 = np.interp(tt, [c[0] for c in f0_c], [c[1] for c in f0_c])
    f0 *= 1.0 + 0.02 * np.sin(2 * math.pi * 1.4 * tt + jr.uniform(0, 6))
    f0 *= (1.0 + jr.uniform(-0.04, 0.04))
    vib = 1.0 + 0.018 * np.sin(2 * math.pi * 5.0 * tt) * np.minimum(tt / 0.14, 1.0)
    ph = 2 * math.pi * np.cumsum(f0 * vib) / SR
    src = np.zeros(n)
    for k in range(1, 26):
        src += math.sin(k * 0.7) * np.sin(k * ph) / (k ** 1.2)
    env = np.zeros(n)
    for vowel, t0, d in sylls:
        i0, i1 = int(t0 * SR), int(min((t0 + d) * SR, n))
        if i1 <= i0:
            continue
        seg = np.arange(i1 - i0) / SR
        e = np.minimum(seg / 0.028, 1.0) * np.exp(-np.maximum(seg - d * 0.55, 0) / (d * 0.45))
        if vowel == "stop":
            env[i0:i1] *= 0.08
        else:
            env[i0:i1] = np.maximum(env[i0:i1], e)
    src *= env
    first = next((sv for sv, _, _ in sylls if sv != "stop"), "e")
    f1 = np.full(n, VOWELS[first][0], float)
    f2 = np.full(n, VOWELS[first][1], float)
    for vowel, t0, d in sylls:
        if vowel in ("stop", "ai"):
            continue
        i0, i1 = int(t0 * SR), int(min((t0 + d) * SR, n))
        if i1 <= i0:
            continue
        g = np.linspace(0, 1, i1 - i0)
        f1[i0:i1] = f1[i0:i1] * (1 - g) + VOWELS[vowel][0] * g
        f2[i0:i1] = f2[i0:i1] * (1 - g) + VOWELS[vowel][1] * g
    r1 = resonator(src, f1, 80)
    r2 = resonator(src, f2, 90)
    r3 = resonator(src, 2400, 150)
    out = 0.72 * r1 + 0.45 * r2 + 0.10 * r3
    # consonanti secche e chiare (intelligibilita')
    for vowel, t0, d in sylls:
        if vowel == "stop":
            i0 = int(t0 * SR)
            k = int(0.024 * SR)
            burst = band(noise(k), 1500, 3800) * env_ar(k, 0.001, 0.008)
            out[i0:i0 + k] += burst * 1.0
    b0 = int(max(0, sylls[0][1] - 0.09) * SR)
    kb = int(0.06 * SR)
    if b0 + kb < n:
        out[b0:b0 + kb] += band(noise(kb), 600, 2200) * np.hanning(kb) * 0.14
    dbl = np.roll(out, int(0.010 * SR)) * 0.26
    out = out + dbl
    out = onepole(out, 3200)      # voce piu' scura, da petto
    return out

def voices():
    v = {
        # "DE-FENSE!" scandito: sillabe pari, e pure + ɛ aperta, caduta forte
        "voice_defense": shout(
            [("stop", 0.09, 0.025), ("e", 0.12, 0.17), ("stop", 0.31, 0.025), ("ɛ", 0.35, 0.26)],
            [(0.0, 150), (0.12, 185), (0.35, 200), (0.62, 140)], 11, 0.68),
        # "BALL!" aperta africana
        "voice_ball": shout(
            [("stop", 0.07, 0.025), ("ɑ", 0.10, 0.30)],
            [(0.0, 150), (0.10, 180), (0.26, 205), (0.46, 135)], 22, 0.52),
        # "SHOOT!" u lunga pura
        "voice_shoot": shout(
            [("stop", 0.06, 0.03), ("u", 0.10, 0.34)],
            [(0.0, 145), (0.10, 175), (0.28, 200), (0.50, 138)], 33, 0.54),
        # "PASS!" a aperta
        "voice_pass": shout(
            [("stop", 0.06, 0.025), ("a", 0.09, 0.28)],
            [(0.0, 155), (0.09, 185), (0.24, 205), (0.42, 140)], 44, 0.48),
        # "RE-BOUND!" i netta + ɑu scanditi
        "voice_rebound": shout(
            [("stop", 0.08, 0.02), ("i", 0.11, 0.15), ("stop", 0.28, 0.025), ("ɑ", 0.31, 0.30)],
            [(0.0, 145), (0.11, 175), (0.31, 195), (0.60, 132)], 55, 0.62),
        # "NICE ONE!" -> "nais wan" con vocali pure
        "voice_nice": shout(
            [("I", 0.06, 0.16), ("stop", 0.24, 0.02), ("ɔ", 0.27, 0.20)],
            [(0.0, 150), (0.06, 180), (0.27, 195), (0.50, 135)], 66, 0.56),
    }
    for name, x in v.items():
        save(name + ".wav", x, 0.46)

if __name__ == "__main__":
    bounces()
    squeak()
    traffic_loop()
    voices()
