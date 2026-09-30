#!/usr/bin/env python3
"""Audio v2.1.1 per HoopCity: swish di rete di cotone (ricerca-guidato:
transient + flutter + coda ariosa, no ferro), squeak da suola udibile,
fischi dalla folla, pioggia delicata in citta' e voci di partita con
sintesi formantica (meno robotiche, piu' basse). Tutto procedurale.
Uso:  python3 tools/gen_v21_audio.py   (dalla root del progetto hoopcity)
"""
import math, wave, os
import numpy as np

SR = 22050
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "sfx")
rng = np.random.default_rng(20260915)

def save(name, x, peak=0.5):
    pk = max(1e-9, float(np.max(np.abs(x))))
    x = x / pk * peak
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print("wrote", name, round(len(x) / SR, 2), "s")

def noise(n):
    return rng.uniform(-1.0, 1.0, n)

def onepole(x, cut, hp=False):
    a = math.exp(-2 * math.pi * cut / SR)
    y = np.empty_like(x)
    acc = 0.0
    c = 1 - a
    for i, v in enumerate(x):
        acc = a * acc + c * v
        y[i] = acc
    return x - y if hp else y

def band(x, lo, hi):
    return onepole(x, hi) - onepole(x, lo)

def env_ar(n, a_s, tau):
    t = np.arange(n) / SR
    return np.minimum(t / max(a_s, 1e-4), 1.0) * np.exp(-t / tau)

# ------------------------------------------------------------------ swish
def swish():
    """Rete di cotone: snap breve degli anelli, 'shhh' arioso con flutter
    dei fili, corpo morbido sotto. Niente ferro (ricerca: transient +
    net texture + airy tail). ~0.42 s."""
    dur = 0.42
    n = int(dur * SR)
    tt = np.arange(n) / SR
    # snap degli anelli della rete: click secco brevissimo band 1.4-4.5k
    snap = band(noise(n), 1400, 4500) * env_ar(n, 0.002, 0.012) * 0.9
    # 'shhh' principale: banda che scende 3.2k -> 1.1k (la palla apre la rete)
    raw = noise(n)
    sh = np.empty(n)
    acc = 0.0
    a_hi = math.exp(-2 * math.pi * 3300 / SR)
    a_lo = math.exp(-2 * math.pi * 1050 / SR)
    l1 = l2 = 0.0
    for i in range(n):
        cut = 3300.0 + (1050.0 - 3300.0) * min(tt[i] / 0.30, 1.0)
        a = math.exp(-2 * math.pi * cut / SR)
        acc = a * acc + (1 - a) * raw[i]      # low-pass che si chiude
        l2 = a_lo * l2 + (1 - a_lo) * acc     # floor band
        sh[i] = acc - l2
    e = np.minimum(tt / 0.03, 1.0) * np.exp(-np.maximum(tt - 0.055, 0) / 0.085)
    flutter = 1.0 + 0.35 * np.sin(2 * np.pi * 33 * tt) * np.exp(-tt / 0.16)
    sh *= e * flutter
    # corpo cotone: fruscio basso morbido
    body = onepole(noise(n), 850) * env_ar(n, 0.004, 0.055) * 0.55
    out = snap * 0.8 + sh * 1.0 + body * 0.5
    save("swish.wav", out, 0.46)

# ------------------------------------------------------------------ squeak
def squeak():
    """Suola su parquet: stick-slip. Grido 2.1k->3.4k->2.8k con AM di
    scivolamento (~70 Hz) + soffio gommato. Udibile ma corto."""
    dur = 0.17
    n = int(dur * SR)
    tt = np.arange(n) / SR
    f = np.where(tt < 0.06,
                 2100 + (3400 - 2100) * (tt / 0.06),
                 3400 - (3400 - 2800) * ((tt - 0.06) / 0.11))
    ph = 2 * np.pi * np.cumsum(f) / SR
    am = 0.55 + 0.45 * np.sin(2 * np.pi * 71 * tt + rng.uniform(0, 6))
    x = np.sin(ph) * am
    x += band(noise(n), 2400, 6200) * 0.45
    # micro irregolarita' dello slip: wobble lento dell'ampiezza
    x *= 1.0 - 0.25 * np.sin(2 * np.pi * 9.3 * tt + 1.0)
    out = x * env_ar(n, 0.004, 0.055)
    save("squeak.wav", out, 0.62)

# ------------------------------------------------------------------ fischio folla
def crowd_whistle():
    """Fischi umani dalla tifoseria: tre fischi con vibrato/warble sfalsati
    sopra un lavaggio di folla sottile."""
    dur = 1.25
    n = int(dur * SR)
    out = np.zeros(n)
    for k, (t0, f_base, d) in enumerate([(0.02, 2450, 0.55), (0.24, 2830, 0.42), (0.52, 2210, 0.60)]):
        nn = int(d * SR)
        ttt = np.arange(nn) / SR
        # gesto del fischio: sale, si torsiona, scende
        gest = np.where(ttt < d * 0.45, 1.0 + 0.06 * (ttt / (d * 0.45)),
                        1.06 - 0.10 * ((ttt - d * 0.45) / (d * 0.55)))
        warb = 1.0 + 0.018 * np.sin(2 * np.pi * 11.5 * ttt + k)
        ph = 2 * np.pi * f_base * np.cumsum(gest * warb) / SR
        w = np.sin(ph) + 0.25 * np.sin(2.02 * ph)
        w *= np.minimum(ttt / 0.04, 1.0) * np.exp(-np.maximum(ttt - d * 0.55, 0) / (d * 0.16))
        breath = band(noise(nn), 1800, 3800) * 0.18 * np.hanning(nn)
        s = int(t0 * SR)
        out[s:s + nn] += (w * 0.8 + breath) * 0.9
    wash = onepole(noise(n), 900) * 0.10 * (1.0 + 0.2 * np.sin(2 * np.pi * 0.7 * np.arange(n) / SR))
    save("crowd_whistle.wav", out + wash, 0.42)

# ------------------------------------------------------------------ pioggia
def rain_loop():
    """Pioggia delicata: fruscio morbido continuo, gocce rare lontane.
    Loop seamless: crossfade della coda sulla testa."""
    dur, xf = 9.0, 0.25
    n = int(dur * SR)
    nf = n + int(xf * SR)
    raw = noise(nf)
    hiss = band(raw, 500, 5200) * (1.0 + 0.18 * np.sin(2 * np.pi * 2.0 * np.arange(nf) / SR + 0.7)
                                       + 0.12 * np.sin(2 * np.pi * 0.35 * np.arange(nf) / SR))
    body = onepole(raw, 420) * 0.5
    x = hiss * 0.7 + body * 0.35
    # gocce leggere sporadiche
    x[int(1.9 * SR):int(1.9 * SR) + 240] += band(noise(240), 1500, 5000) * env_ar(240, 0.001, 0.006) * 0.25
    x[int(5.6 * SR):int(5.6 * SR) + 240] += band(noise(240), 1500, 5000) * env_ar(240, 0.001, 0.006) * 0.20
    # crossfade per il loop
    k = int(xf * SR)
    fade = np.linspace(0, 1, k)
    head = x[n:n + k] * fade + x[:k] * (1 - fade)
    out = np.concatenate([head, x[k:n]])
    save("rain_loop.wav", out, 0.30)

# ------------------------------------------------------------------ voci
# Formanti vocali (maschio adulto, Hz): [F1, F2, F3]
VOWELS = {
    "a":  (730, 1090, 2440), "ae": (660, 1720, 2410), "e":  (530, 1840, 2480),
    "o":  (570, 840, 2410),  "u":  (300, 870, 2240),  "U":  (440, 1020, 2260),
    "I":  (390, 1990, 2550), "ar": (490, 1150, 1350),
}

def resonator(x, F, BW):
    """Risonatore 2-poli (Klatt) con F per-campione (traiettoria formantica)."""
    Fv = np.full(len(x), float(F)) if np.isscalar(F) else F
    y = np.empty_like(x)
    y0 = y1 = 0.0
    for i in range(len(x)):
        r = math.exp(-math.pi * BW / SR)
        b = 2 * r * math.cos(2 * math.pi * Fv[i] / SR)
        c = -r * r
        a = 1 - b - c
        y0, y1 = a * x[i] + b * y0 + c * y1, y0
        y[i] = y0
    return y

def shout(sylls, f0_c, jitter_seed, total=0.62):
    """Una voce: sorgente glottidale con vibrato+jitter, filtrata per
    formanti con traiettorie tra sillabe, attacchi consonantici, fiato.
    sylls: [(vocale|'stop', t0, dur), ...]; f0_c: [(t, Hz), ...]curve."""
    n = int(total * SR)
    tt = np.arange(n) / SR
    jr = np.random.default_rng(jitter_seed)
    # curva f0 con jitter naturale (deriva +-3%)
    f0 = np.interp(tt, [c[0] for c in f0_c], [c[1] for c in f0_c])
    f0 *= 1.0 + 0.03 * np.sin(2 * np.pi * 1.7 * tt + jr.uniform(0, 6))
    f0 *= (1.0 + jr.uniform(-0.05, 0.05))
    vib = 1.0 + 0.022 * np.sin(2 * np.pi * 5.3 * tt) * np.minimum(tt / 0.12, 1.0)
    ph = 2 * math.pi * np.cumsum(f0 * vib) / SR
    # sorgente: armoniche con rolloff glottidale
    src = np.zeros(n)
    for k in range(1, 26):
        src += math.sin(k * 0.7) * np.sin(k * ph) / (k ** 1.25)
    # env per sillaba (attacco dolce, caduta urlata); le stop chiudono
    env = np.zeros(n)
    for vowel, t0, d in sylls:
        i0, i1 = int(t0 * SR), int(min((t0 + d) * SR, n))
        if i1 <= i0:
            continue
        seg = np.arange(i1 - i0) / SR
        e = np.minimum(seg / 0.035, 1.0) * np.exp(-np.maximum(seg - d * 0.45, 0) / (d * 0.38))
        if vowel == "stop":
            env[i0:i1] *= 0.10          # chiusura consonantica: quasi silenzio
        else:
            env[i0:i1] = np.maximum(env[i0:i1], e)
    src *= env
    # formanti con traiettorie tra le vocali delle sillabe
    first = next((sv for sv, _, _ in sylls if sv != "stop"), "e")
    f1 = np.full(n, VOWELS[first][0], float)
    f2 = np.full(n, VOWELS[first][1], float)
    for vowel, t0, d in sylls:
        if vowel == "stop":
            continue
        i0, i1 = int(t0 * SR), int(min((t0 + d) * SR, n))
        if i1 <= i0:
            continue
        g = np.linspace(0, 1, i1 - i0)
        tgt = np.array(VOWELS[vowel])
        f1[i0:i1] = (f1[i0:i1] * (1 - g) + tgt[0] * g).ravel()
        f2[i0:i1] = (f2[i0:i1] * (1 - g) + tgt[1] * g).ravel()
    # formanti: 3 risonatori (F1/F2 con traiettorie, F3 fisso chiaro)
    r1 = resonator(src, f1, 85)
    r2 = resonator(src, f2, 95)
    r3 = resonator(src, 2500, 160)
    out = 0.70 * r1 + 0.42 * r2 + 0.10 * r3
    # consonanti: burst di rumore agli attacchi fermi/fricativi
    for vowel, t0, d in sylls:
        if vowel == "stop":
            i0 = int(t0 * SR)
            k = int(0.028 * SR)
            burst = band(noise(k), 1800, 4200) * env_ar(k, 0.001, 0.009)
            out[i0:i0 + k] += burst * 0.8
    # fiato prima della chiamata
    b0 = int(max(0, sylls[0][1] - 0.10) * SR)
    kb = int(0.07 * SR)
    if b0 + kb < n:
        out[b0:b0 + kb] += band(noise(kb), 700, 2400) * np.hanning(kb) * 0.16
    # doppione leggermente detuned: spessore da grida di campo
    dbl = np.roll(out, int(0.011 * SR)) * 0.30
    out = out + dbl
    # corpo meno "radio": CHIUDO un po' gli acuti -> voce piu' bassa e calda
    out = onepole(out, 3400)
    return out

def voices():
    v = {
        "voice_defense": shout(
            [("stop", 0.10, 0.02), ("e", 0.13, 0.16), ("stop", 0.30, 0.02), ("e", 0.33, 0.24)],
            [(0.0, 170), (0.13, 225), (0.33, 240), (0.60, 175)], 11, 0.66),
        "voice_ball": shout(
            [("stop", 0.08, 0.02), ("o", 0.10, 0.34)],
            [(0.0, 175), (0.10, 205), (0.28, 255), (0.48, 165)], 22, 0.54),
        "voice_shoot": shout(
            [("stop", 0.06, 0.03), ("u", 0.09, 0.36)],
            [(0.0, 170), (0.10, 210), (0.30, 250), (0.50, 168)], 33, 0.56),
        "voice_pass": shout(
            [("stop", 0.07, 0.025), ("ae", 0.10, 0.30)],
            [(0.0, 180), (0.10, 215), (0.26, 250), (0.44, 172)], 44, 0.50),
        "voice_rebound": shout(
            [("stop", 0.08, 0.02), ("ar", 0.10, 0.36)],
            [(0.0, 165), (0.10, 200), (0.30, 240), (0.52, 160)], 55, 0.58),
        "voice_nice": shout(
            [("a", 0.06, 0.17), ("I", 0.24, 0.22)],
            [(0.0, 185), (0.06, 215), (0.24, 255), (0.48, 170)], 66, 0.54),
    }
    for name, x in v.items():
        save(name + ".wav", x, 0.40)   # "piu' basse": livelli cotti al minimo

if __name__ == "__main__":
    swish()
    squeak()
    crowd_whistle()
    rain_loop()
    voices()
