#!/usr/bin/env python3
"""Procedural SFX complement for BaskinArena: every name in Sfx.SFX_NAMES that
the v21/v212/lounge generators do not produce. Mono 22050 Hz WAVs, no assets.
Usage: python3 tools/gen_rest_audio.py  (from the project root)
"""
import math, wave, os
import numpy as np

SR = 22050
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "sfx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(20260919)

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
    return rng.standard_normal(n)

def env_ar(n, a_s, tau):
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / max(a_s, 1e-4))
    return a * np.exp(-t / tau)

def tone(freq, dur, shape="sine", slide=0.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = freq + slide * t
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "sine":
        return np.sin(ph)
    if shape == "tri":
        return 2 * np.abs(2 * (ph / (2 * np.pi) % 1.0) - 1.0) - 1.0
    if shape == "square":
        return np.sign(np.sin(ph)) * 0.8 + np.sin(ph) * 0.2
    if shape == "saw":
        return 2 * (ph / (2 * np.pi) % 1.0) - 1.0
    return np.sin(ph)

def onepole(x, cut):
    a = math.exp(-2 * math.pi * cut / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y

def seamless(x, xf_s=0.35):
    n = len(x)
    k = int(xf_s * SR)
    w = np.linspace(0, 1, k)
    x = x.copy()
    x[:k] = x[:k] * w + x[-k:] * (1 - w)
    return x[:-k]

def whistle_gen(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 2350 + 120 * np.sin(2 * np.pi * 28 * t) + 40 * np.sin(2 * np.pi * 7.3 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.18 * noise(n)
    e = np.minimum(1.0, t / 0.03) * np.minimum(1.0, (dur - t) / 0.06).clip(0, 1)
    return x * e

def squeak_gen(f0):
    dur = 0.13
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (1 + 0.25 * np.sin(2 * np.pi * 55 * t)) * (1 - 0.3 * t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    am = 0.6 + 0.4 * np.sin(2 * np.pi * 48 * t)
    return np.sin(ph) * am * env_ar(n, 0.004, 0.045)

# ---- one-shots -------------------------------------------------------
save("backboard.wav", tone(180, 0.18, "sine", -60) * env_ar(int(0.18 * SR), 0.002, 0.05)
     + 0.5 * noise(int(0.18 * SR)) * env_ar(int(0.18 * SR), 0.001, 0.012), 0.55)
save("beep.wav", tone(990, 0.11) * env_ar(int(0.11 * SR), 0.004, 0.06)
     + 0.3 * tone(1980, 0.11) * env_ar(int(0.11 * SR), 0.004, 0.04), 0.5)
save("block.wav", noise(int(0.25 * SR)) * env_ar(int(0.25 * SR), 0.001, 0.03)
     + tone(140, 0.25, "sine", -50) * env_ar(int(0.25 * SR), 0.002, 0.07), 0.6)
save("body.wav", tone(95, 0.20, "sine", -25) * env_ar(int(0.20 * SR), 0.003, 0.07)
     + 0.4 * onepole(noise(int(0.20 * SR)), 900) * env_ar(int(0.20 * SR), 0.002, 0.04), 0.55)
n = int(1.2 * SR)
t = np.arange(n) / SR
save("buzzer.wav", (tone(175, 1.2, "square") + 0.4 * tone(351, 1.2, "saw"))
     * np.minimum(1.0, t / 0.02) * np.minimum(1.0, (1.2 - t) / 0.08).clip(0, 1), 0.5)
n = int(0.22 * SR)
sw = noise(n) * env_ar(n, 0.01, 0.07)
save("crossover.wav", onepole(sw, 2600) + 0.4 * tone(300, 0.22, "sine", -120) * env_ar(n, 0.002, 0.03), 0.5)
save("defeat.wav", np.concatenate([tone(220, 0.4, "tri") * env_ar(int(0.4 * SR), 0.01, 0.25),
     tone(174.6, 0.4, "tri") * env_ar(int(0.4 * SR), 0.01, 0.25),
     tone(146.8, 0.7, "tri") * env_ar(int(0.7 * SR), 0.01, 0.4)]), 0.5)
n = int(0.5 * SR)
rim = sum(a * np.sin(2 * np.pi * f * np.arange(n) / SR + p)
          for f, a, p in [(620, 0.5, 0.0), (940, 0.35, 1.1), (1450, 0.22, 2.0)])
save("dunk.wav", rim * env_ar(n, 0.001, 0.09)
     + tone(70, 0.5, "sine", -20) * env_ar(n, 0.002, 0.18), 0.6)
save("go.wav", np.concatenate([tone(660, 0.09) * env_ar(int(0.09 * SR), 0.005, 0.05),
     tone(880, 0.14) * env_ar(int(0.14 * SR), 0.005, 0.08)]), 0.5)
n = int(0.6 * SR)
rim2 = sum(a * np.sin(2 * np.pi * f * np.arange(n) / SR + p)
           for f, a, p in [(523, 0.5, 0.0), (881, 0.32, 0.7), (1320, 0.2, 1.9), (2093, 0.12, 2.6)])
save("rim.wav", rim2 * env_ar(n, 0.001, 0.16), 0.5)
save("shot_release.wav", (noise(int(0.08 * SR)) * 0.6 + tone(420, 0.08, "sine", 80))
     * env_ar(int(0.08 * SR), 0.001, 0.02), 0.45)
save("squeak1.wav", squeak_gen(1800), 0.5)
save("squeak2.wav", squeak_gen(2200), 0.5)
save("squeak3.wav", squeak_gen(2600), 0.5)
n = int(0.15 * SR)
save("steal.wav", onepole(noise(n), 4200) * env_ar(n, 0.005, 0.045), 0.55)
save("ui_tap.wav", (tone(1050, 0.05) + 0.5 * noise(int(0.05 * SR)))
     * env_ar(int(0.05 * SR), 0.001, 0.012), 0.4)
save("victory.wav", np.concatenate([tone(261.6, 0.22, "tri"), tone(329.6, 0.22, "tri"),
     tone(392.0, 0.22, "tri"), tone(523.3, 0.55, "tri")])
     * env_ar(int(1.21 * SR), 0.008, 0.5), 0.5)
save("whistle.wav", whistle_gen(0.70), 0.5)
save("whistle_short.wav", whistle_gen(0.28), 0.5)

# ---- loops (seamless) ------------------------------------------------
def crowd_wash(dur, seed, brightness=1800):
    g = np.random.default_rng(seed)
    n = int(dur * SR)
    x = onepole(g.standard_normal(n), brightness)
    t = np.arange(n) / SR
    swell = 0.75 + 0.25 * np.sin(2 * np.pi * 0.13 * t + seed) * np.sin(2 * np.pi * 0.071 * t)
    return seamless(x * swell)

save("crowd_amb.wav", crowd_wash(5.0, 7), 0.42)
n = int(4.5 * SR)
save("court_amb.wav", seamless(0.6 * onepole(noise(n), 700)
     + 0.06 * tone(120, 4.5) + 0.03 * tone(240, 4.5)), 0.30)

def drums(dur, bpm, swing=0.0, kick_gain=0.9, snare_gain=0.7, hat_gain=0.35):
    n = int(dur * SR)
    out = np.zeros(n)
    beat = 60.0 / bpm
    step = beat / 2
    k = 0
    while True:
        ts = k * step + (swing * step if k % 2 else 0.0)
        if ts >= dur:
            break
        i = int(ts * SR)
        bar_pos = (k % 8)
        if bar_pos in (0, 3, 4, 6):
            m = min(len(out) - i, int(0.22 * SR))
            out[i:i + m] += kick_gain * tone(120, 0.22, "sine", -70)[:m] * env_ar(m, 0.001, 0.06)
        if bar_pos in (2, 6):
            m = min(len(out) - i, int(0.18 * SR))
            out[i:i + m] += snare_gain * (noise(m) * 0.7 + tone(190, 0.18)[:m]) * env_ar(m, 0.001, 0.045)
        m = min(len(out) - i, int(0.05 * SR))
        out[i:i + m] += hat_gain * noise(m) * env_ar(m, 0.001, 0.012)
        k += 1
    return out

def bass_line(dur, bpm, root_midi, pattern):
    n = int(dur * SR)
    out = np.zeros(n)
    beat = 60.0 / bpm
    for k, st in enumerate(pattern):
        if st is None:
            continue
        ts = k * beat / 2
        if ts >= dur:
            break
        f = 440.0 * 2 ** ((root_midi + st - 69) / 12.0)
        m = min(len(out) - int(ts * SR), int(0.42 * SR))
        seg = (np.sin(2 * np.pi * f * np.arange(m) / SR)
               + 0.3 * np.sin(4 * np.pi * f * np.arange(m) / SR)) * env_ar(m, 0.004, 0.16)
        out[int(ts * SR):int(ts * SR) + m] += 0.5 * seg
    return out

def pad(dur, freqs, gain=0.12):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = sum(np.sin(2 * np.pi * f * t + i) + 0.4 * np.sin(4 * np.pi * f * t)
            for i, f in enumerate(freqs))
    return gain * x / len(freqs)

save("music_rhythm.wav", seamless(drums(4.0, 96)), 0.5)
_ml = drums(8.0, 88) + bass_line(8.0, 88, 33, [0, None, 7, None, 5, None, 3, 2] * 4) \
    + pad(8.0, [110.0, 164.8, 220.0, 277.2])
save("music_loop.wav", seamless(_ml), 0.42)
_mj = drums(8.0, 132, swing=0.28, hat_gain=0.5) \
    + bass_line(8.0, 132, 36, [0, 4, 7, 9, 7, 4, 2, 0] * 4) \
    + pad(8.0, [130.8, 196.0, 261.6, 329.6])
save("music_jazz.wav", seamless(_mj), 0.40)
_mj2 = drums(8.0, 120, swing=0.22, hat_gain=0.45) \
    + bass_line(8.0, 120, 34, [0, None, 5, 7, None, 9, 7, 5] * 4) \
    + pad(8.0, [116.5, 174.6, 233.1, 293.7])
save("music_jazz2.wav", seamless(_mj2), 0.40)
print("done")
