#!/usr/bin/env python3
"""Genera gli asset ambientali di HoopCity v1.9: traffico cittadino e un
loop musicale lofi chill. Audio procedurale, nessuna licenza.
Uso:  python3 tools/gen_ambient.py   (dalla root del workspace)
"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "hoopcity", "assets", "sfx")


def save(name, x, normalize=True):
    if normalize:
        pk = max(1e-9, max(abs(v) for v in x))
        x = [v / pk * 0.55 for v in x]
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))
    print("wrote", name, len(x) / SR, "s")


def t(dur):
    return [i / SR for i in range(int(dur * SR))]


def noise(n, seed=0):
    r = random.Random(seed)
    return [r.uniform(-1, 1) for _ in range(n)]


def lp(x, cut):
    a = math.exp(-2 * math.pi * cut / SR)
    y, prev = [], 0.0
    for v in x:
        prev = a * prev + (1 - a) * v
        y.append(prev)
    return y


def hp(x, cut):
    l = lp(x, cut)
    return [x[i] - l[i] for i in range(len(x))]


def sine(freq, tt, vib=0.0, vib_rate=5.0):
    ph = 0.0
    out = []
    for i, s in enumerate(tt):
        f = freq * (1.0 + vib * math.sin(2 * math.pi * vib_rate * s))
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph))
    return out


def rhodes(freq, dur, amp=1.0, det=0.0015):
    tt = t(dur)
    a, b = sine(freq * (1 + det), tt), sine(freq * (1 - det), tt)
    h2 = sine(freq * 2.0, tt)
    env = [min(1.0, i / (SR * 0.02)) * math.exp(-2.2 * i / (SR * dur)) for i in range(len(tt))]
    return [amp * env[i] * (0.62 * a[i] + 0.62 * b[i] + 0.16 * h2[i]) for i in range(len(tt))]


def add_at(buf, sig, start_s, gain=1.0):
    s = int(start_s * SR)
    for i, v in enumerate(sig):
        j = s + i
        if 0 <= j < len(buf):
            buf[j] += v * gain


# ------------------------------------------------------------------ traffic
def traffic_loop():
    dur = 10.0
    n = int(dur * SR)
    bed = lp(noise(n, 11), 320.0)
    # slow breathing of the whole street
    bed = [bed[i] * (0.55 + 0.20 * math.sin(2 * math.pi * 0.09 * i / SR)
                     + 0.12 * math.sin(2 * math.pi * 0.031 * i / SR + 1.3)) for i in range(n)]
    buf = [v * 0.8 for v in bed]
    r = random.Random(4)
    # passing cars: band-passed noise swells
    for k in range(7):
        L = int(r.uniform(1.2, 2.8) * SR)
        sw = noise(L, 20 + k)
        sw = lp(sw, 1400.0)
        sw = [sw[i] - lp(sw, 260.0)[i] for i in range(L)]
        env = [math.sin(math.pi * i / L) ** 2 for i in range(L)]
        sw = [sw[i] * env[i] for i in range(L)]
        pk = max(1e-9, max(abs(v) for v in sw))
        sw = [v / pk for v in sw]
        add_at(buf, sw, r.uniform(0.0, dur - 2.9), r.uniform(0.25, 0.5))
    # two far-away horns
    for k, f in enumerate([311.0, 370.0]):
        h = sine(f, t(0.9), vib=0.01, vib_rate=4.0)
        h = [h[i] * min(1.0, i / (SR * 0.05)) * min(1.0, (len(h) - i) / (SR * 0.2)) for i in range(len(h))]
        add_at(buf, h, 3.1 + k * 0.06, 0.06)
    # loop crossfade
    cf = int(0.4 * SR)
    for i in range(cf):
        f = i / cf
        buf[i] = buf[i] * f + buf[n - cf + i] * (1 - f)
    save("traffic_loop.wav", buf)


# ------------------------------------------------------------------- lofi
def music_lofi():
    bpm = 70.0
    beat = 60.0 / bpm
    bars = 4
    dur = beat * 4 * bars
    n = int(dur * SR)
    buf = [0.0] * n
    chords = [
        [130.81, 164.81, 196.00, 246.94],   # Cmaj7
        [110.00, 130.81, 164.81, 196.00],   # Am7
        [87.31, 110.00, 130.81, 164.81],    # Fmaj7
        [98.00, 123.47, 146.83, 174.61],    # G7
    ]
    for bar in range(bars):
        t0 = bar * beat * 4
        ch = chords[bar % 4]
        # rhodes stab on 1, 2.5 and 4
        for off, amp in [(0.0, 0.5), (1.5 * beat, 0.38), (3.0 * beat, 0.42)]:
            for f in ch:
                add_at(buf, rhodes(f, beat * 2.2, 0.16), t0 + off, amp)
        # bass: root on 1, fifth on 3.5
        add_at(buf, sine(ch[0] / 2, t(beat * 1.6), vib=0.004), t0, 0.30)
        add_at(buf, sine(ch[0] / 2 * 1.5, t(beat * 0.9)), t0 + 2.5 * beat, 0.22)
        # drums: kick 1 & 3, soft snare 2 & 4, swung hats
        for kb in [0.0, 2.0]:
            kk = sine(52.0, t(0.16))
            kk = [kk[i] * math.exp(-18 * i / SR) for i in range(len(kk))]
            add_at(buf, kk, t0 + kb * beat, 0.5)
        for sb in [1.0, 3.0]:
            sn = noise(int(0.12 * SR), 90 + bar)
            sn = lp(sn, 3200.0)
            sn = [sn[i] * math.exp(-26 * i / SR) for i in range(len(sn))]
            add_at(buf, sn, t0 + sb * beat, 0.16)
        for hb in range(8):
            off = hb * 0.5 * beat + (0.06 * beat if hb % 2 else 0.0)
            ht = hp(noise(int(0.05 * SR), 200 + hb + bar * 8), 6000.0)
            ht = [ht[i] * math.exp(-60 * i / SR) for i in range(len(ht))]
            add_at(buf, ht, t0 + off, 0.05 if hb % 2 else 0.08)
    # vinyl crackle
    r = random.Random(7)
    for _ in range(int(dur * 9)):
        i = r.randrange(n)
        buf[i] += r.uniform(-0.05, 0.05)
    # gentle tape wobble + soft clip
    buf = [math.tanh(v * 1.25) * 0.9 for v in buf]
    cf = int(0.6 * SR)
    for i in range(cf):
        f = i / cf
        buf[i] = buf[i] * f + buf[n - cf + i] * (1 - f)
    save("music_lofi.wav", buf, normalize=False)


if __name__ == "__main__":
    traffic_loop()
    music_lofi()


# ------------------------------------------------------------------- jazz
def music_jazz():
    """Smoky trio loop: ride swing, walking bass, rhodes comping, brushes."""
    bpm = 132.0
    beat = 60.0 / bpm
    bars = 8
    dur = beat * 4 * bars
    n = int(dur * SR)
    buf = [0.0] * n
    # ii-V-I-vi in F: Gm7 | C7 | Fmaj7 | Dm7 | Gm7 | C7 | Fmaj7 | Am7-D7
    prog = [
        [196.00, 233.08, 293.66, 349.23],
        [261.63, 349.23, 440.00, 587.33],
        [349.23, 440.00, 523.25, 659.25],
        [293.66, 349.23, 440.00, 523.25],
        [196.00, 233.08, 293.66, 349.23],
        [261.63, 349.23, 440.00, 587.33],
        [349.23, 440.00, 523.25, 659.25],
        [220.00, 261.63, 329.63, 293.66],
    ]
    walk = [98.0, 130.81, 146.83, 174.61, 130.81, 98.0, 87.31, 116.54,
            87.31, 110.0, 130.81, 146.83, 98.0, 130.81, 164.81, 174.61,
            174.61, 164.81, 146.83, 130.81, 98.0, 110.0, 123.47, 130.81,
            87.31, 104.65, 130.81, 146.83, 110.0, 130.81, 146.83, 164.81]
    for bar in range(bars):
        t0 = bar * beat * 4
        ch = prog[bar]
        # ride cymbal: swing 8ths (1, 2.66, 3, 4.66)
        for off in [0.0, 1.66, 2.0, 3.66]:
            L = int(0.09 * SR)
            tick = hp(noise(L, 500 + bar * 4 + int(off * 4)), 7000.0)
            tick = [tick[i] * math.exp(-45 * i / SR) for i in range(L)]
            add_at(buf, tick, t0 + off * beat, 0.10 if off % 2 == 0 else 0.13)
        # brushes on 2 & 4
        for sb in [1.0, 3.0]:
            L = int(0.16 * SR)
            sn = lp(noise(L, 700 + bar), 5200.0)
            sn = [sn[i] * math.exp(-20 * i / SR) for i in range(L)]
            add_at(buf, sn, t0 + sb * beat, 0.10)
        # walking bass: quarter notes, soft triangle-ish
        for q in range(4):
            f = walk[(bar * 4 + q) % len(walk)]
            b = sine(f, t(beat * 0.92))
            b = [b[i] + 0.25 * sine(f * 2, t(beat * 0.92))[i] for i in range(len(b))]
            env = [min(1.0, i / (SR * 0.015)) * math.exp(-2.6 * i / (SR * beat)) for i in range(len(b))]
            b = [b[i] * env[i] for i in range(len(b))]
            add_at(buf, b, t0 + q * beat, 0.30)
        # rhodes comping on the off-beats
        for off, amp in [(0.66, 0.30), (2.0, 0.24), (3.33, 0.28)]:
            for f in ch[0:3]:
                add_at(buf, rhodes(f * 2, beat * 1.4, 0.10), t0 + off * beat, amp)
    r = random.Random(21)
    for _ in range(int(dur * 6)):
        i = r.randrange(n)
        buf[i] += r.uniform(-0.03, 0.03)
    buf = [math.tanh(v * 1.2) * 0.9 for v in buf]
    cf = int(0.5 * SR)
    for i in range(cf):
        f = i / cf
        buf[i] = buf[i] * f + buf[n - cf + i] * (1 - f)
    save("music_jazz.wav", buf, normalize=False)


# ----------------------------------------------------------------- squeak
def squeak():
    """Sneaker stop on parquet: short sticky slip, 2 micro bursts."""
    dur = 0.28
    n = int(dur * SR)
    out = [0.0] * n
    r = random.Random(5)
    f0 = r.uniform(1500, 2300)
    ph = 0.0
    for i in range(n):
        tt = i / SR
        f = f0 * (1.0 + 0.35 * math.sin(2 * math.pi * 23 * tt)) * (1.0 - 0.25 * tt / dur)
        ph += 2 * math.pi * f / SR
        stick = math.sin(ph) * 0.6 + r.uniform(-1, 1) * 0.4
        env = math.sin(math.pi * min(1.0, tt / dur)) ** 1.5
        out[i] = stick * env
    out = lp(out, 4200.0)
    # second shorter slip
    n2 = int(0.10 * SR)
    ph = 0.0
    f1 = f0 * 1.25
    for i in range(n2):
        tt = i / SR
        ph += 2 * math.pi * f1 / SR
        out[int(0.13 * SR) + i] += (math.sin(ph) * 0.5 + r.uniform(-1, 1) * 0.5) \
            * math.sin(math.pi * tt / (n2 / SR)) ** 1.5 * 0.7
    save("squeak.wav", out)


if __name__ == "__main__":
    pass
