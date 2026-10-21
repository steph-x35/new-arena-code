#!/usr/bin/env python3
"""Genera tutti gli SFX procedurali di Hoop City Life come WAV 16-bit mono.
Nessun asset esterno: riga di comando  python3 gen_sfx.py <cartella_output>
"""
import os
import sys
import numpy as np

SR = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)


def save(name, x, sr=SR, normalize=True):
    x = np.asarray(x, dtype=np.float64)
    # rimuovi DC
    x -= x.mean()
    if normalize:
        peak = np.abs(x).max()
        if peak > 1e-9:
            x = x / peak * 0.9
    else:
        x = np.clip(x, -1.0, 1.0)
    # breve fade-in/out anti-click
    n = max(1, int(sr * 0.004))
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    data = (x * 32767).astype("<i2")
    with open(os.path.join(OUT, name + ".wav"), "wb") as f:
        import wave
        w = wave.open(f, "wb")
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())
        w.close()


def t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def env_exp(n, decay=6.0):
    return np.exp(-np.linspace(0, decay, n))


def noise(n, seed=0, color="white"):
    rng = np.random.default_rng(seed)
    w = rng.standard_normal(n)
    if color == "pink":
        # filtro semplice primo ordine
        y = np.zeros(n)
        b0 = 0.0
        for i in range(n):
            b0 = 0.97 * b0 + 0.03 * w[i]
            y[i] = b0
        w = y * 3.2
    return w


def lp(x, cut, sr=SR):
    # media mobile come filtro passa-basso economico, cut in Hz
    k = max(2, int(sr / max(cut, 20) / 2.2))
    kernel = np.ones(k) / k
    return np.convolve(x, kernel, mode="same")


def hp(x, cut, sr=SR):
    return x - lp(x, cut, sr)


def sine(freq, tt, vib=0.0, vib_rate=6.0):
    f = freq * (1.0 + vib * np.sin(2 * np.pi * vib_rate * tt)) if vib else np.full_like(tt, freq)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase)


def bounce(seed, body=150.0):
    tt = t(0.14)
    # tonfo cavo: pitch che scende, come la palla che comprime
    f = body * np.exp(-tt * 28) + 58.0
    ph = 2 * np.pi * np.cumsum(f) / SR
    thump = np.sin(ph) * np.exp(-tt * 26)
    click = noise(len(tt), seed, "white") * np.exp(-tt * 120) * 0.5
    return thump * 0.9 + click * 0.35


def swish():
    tt = t(0.5)
    n = noise(len(tt), 10, "white")
    sh = hp(n, 2600)
    e = np.exp(-((tt - 0.16) ** 2) / (2 * 0.09 ** 2))  # campana centrata
    # un leggero tonfo di rete alla fine
    net = sine(420, tt) * np.exp(-np.maximum(tt - 0.22, 0) * 22) * (tt > 0.22)
    return sh * e * 0.7 + net * 0.18


def rim():
    tt = t(0.9)
    out = np.zeros_like(tt)
    for f, amp in [(1760, 1.0), (2680, 0.55), (4150, 0.32), (5480, 0.18)]:
        out += sine(f, tt) * amp
    out *= env_exp(len(tt), 4.2)
    # shimmer di attacco
    atk = noise(len(tt), 21, "white") * np.exp(-tt * 90) * 0.25
    return out * 0.8 + atk


def backboard():
    tt = t(0.3)
    f = 96.0 * np.exp(-tt * 20) + 46
    ph = 2 * np.pi * np.cumsum(f) / SR
    thud = np.sin(ph) * np.exp(-tt * 18)
    crack = lp(noise(len(tt), 31, "white"), 1800) * np.exp(-tt * 70)
    return thud * 1.0 + crack * 0.5


def whistle(dur=0.5, short=False):
    tt = t(dur)
    base = 2050.0
    vib = 0.012
    w = sine(base, tt, vib, 7.0)
    w += 0.25 * sine(base * 1.5, tt, vib, 7.0)
    # il fischio dell'arbitro ha una piccola caduta finale
    e = np.ones_like(tt)
    a = int(SR * 0.03)
    e[:a] = np.linspace(0, 1, a)
    r = int(SR * (0.06 if short else 0.12))
    e[-r:] *= np.linspace(1, 0.0, r)
    return w * e * 0.55


def crowd_loop():
    dur = 6.0
    n = noise(int(SR * dur), 42, "pink")
    n = lp(n, 900)
    # mormorio lento della folla
    tt = t(dur)
    mur = 0.55 + 0.45 * (0.5 * np.sin(2 * np.pi * 0.31 * tt)
                         + 0.3 * np.sin(2 * np.pi * 0.73 * tt + 1.7)
                         + 0.2 * np.sin(2 * np.pi * 1.27 * tt + 0.4))
    x = n * mur
    # equalizzazione dei bordi per il loop continuo
    fade = int(SR * 0.25)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * 0.5


def cheer(dur=2.6, seed=7, ooh=False):
    n0 = noise(int(SR * dur), seed, "pink")
    n0 = lp(n0, 1400)
    tt = t(dur)
    if ooh:
        e = np.exp(-((tt - dur * 0.35) ** 2) / (2 * (dur * 0.28) ** 2))
    else:
        # attacca veloce, plateau, decade
        e = 1 - np.exp(-tt * 5)
        e *= np.clip(1.0 - np.maximum(tt - dur * 0.72, 0) / (dur * 0.28), 0, 1)
    # picchi individuali di voci
    rng = np.random.default_rng(seed + 100)
    for _ in range(26):
        st = rng.uniform(0, dur * 0.7)
        ln = rng.uniform(0.15, 0.5)
        i0 = int(st * SR)
        i1 = min(len(n0), int((st + ln) * SR))
        seg_t = np.linspace(0, ln, i1 - i0, endpoint=False)
        vf = rng.uniform(280, 620)
        voice = sine(vf, seg_t, 0.02, 5) * np.hanning(i1 - i0) * rng.uniform(0.02, 0.07)
        n0[i0:i1] += voice
    return n0 * e


def buzzer():
    tt = t(1.0)
    a = np.sign(np.sin(2 * np.pi * 392 * tt)) * 0.28
    a += np.sin(2 * np.pi * 392 * tt) * 0.5
    b = np.sign(np.sin(2 * np.pi * 311 * tt)) * 0.28
    b += np.sin(2 * np.pi * 311 * tt) * 0.5
    w = np.where((tt % 0.5) < 0.25, a, b)
    e = np.ones_like(tt)
    e[:int(SR * 0.02)] = np.linspace(0, 1, int(SR * 0.02))
    e[-int(SR * 0.05):] *= np.linspace(1, 0, int(SR * 0.05))
    return w * e * 0.5


def block_sfx():
    tt = t(0.32)
    # schiocco secco
    snap = lp(noise(len(tt), 51, "white"), 3200) * np.exp(-tt * 45)
    # whoosh discendente
    wh_len = int(SR * 0.22)
    wh_tt = np.linspace(0, 0.22, wh_len)
    wh = hp(noise(wh_len, 52, "white"), 1200)
    sweep = np.sin(2 * np.pi * (900 - 2000 * wh_tt / 0.22) * wh_tt) * 0.15
    wh = (wh * 0.4 + sweep) * np.exp(-wh_tt * 12)
    out = snap * 0.9
    out[:wh_len] += wh
    return out


def steal_sfx():
    dur = 0.22
    n_len = int(SR * dur)
    tt = np.linspace(0, dur, n_len)
    sw = hp(noise(n_len, 61, "white"), 900)
    # sweep ascendente
    sweep = np.sin(2 * np.pi * (300 + 1800 * tt / dur) * tt) * 0.18
    e = np.exp(-tt * 10)
    tap = np.zeros(n_len)
    t0 = int(SR * 0.05)
    tap[t0:t0 + int(SR * 0.07)] += bounce(61, 190)[:int(SR * 0.07)]
    return (sw * 0.35 + sweep) * e + tap * 0.6


def dunk_sfx():
    tt = t(0.8)
    # impatto massiccio di sub
    f = 70 * np.exp(-tt * 16) + 38
    ph = 2 * np.pi * np.cumsum(f) / SR
    sub = np.sin(ph) * np.exp(-tt * 9)
    # clang del ferro (piu' lungo e presente del rim normale)
    clang = np.zeros_like(tt)
    for fq, amp in [(1500, 1.0), (2350, 0.6), (3900, 0.35)]:
        clang += sine(fq, tt) * amp
    clang *= env_exp(len(tt), 3.4)
    smash = lp(noise(len(tt), 71, "white"), 1200) * np.exp(-tt * 30)
    return sub * 1.1 + clang * 0.45 + smash * 0.5


def ui_tap():
    tt = t(0.07)
    return sine(660, tt) * np.exp(-tt * 40) * 0.5


def crossover_sfx():
    tt = t(0.22)
    # schiocco secco di palla + rapido whoosh
    b = np.zeros_like(tt)
    b[:int(SR * 0.1)] = bounce(81, 170)[:int(SR * 0.1)]
    wh_len = int(SR * 0.18)
    wh = hp(noise(wh_len, 82, "white"), 1500) * np.exp(-np.linspace(0, 14, wh_len))
    b[int(SR * 0.04):int(SR * 0.04) + wh_len] += wh * 0.35
    return b


def release_sfx():
    dur = 0.2
    n_len = int(SR * dur)
    tt = np.linspace(0, dur, n_len)
    wh = hp(noise(n_len, 91, "white"), 1700) * np.exp(-tt * 16)
    return wh * 0.5


def beep(freq=880, dur=0.12):
    tt = t(dur)
    w = sine(freq, tt)
    e = np.ones_like(tt)
    e[:int(SR * 0.01)] = np.linspace(0, 1, int(SR * 0.01))
    e[-int(SR * 0.03):] *= np.linspace(1, 0, int(SR * 0.03))
    return w * e * 0.4


def body_thud():
    tt = t(0.22)
    f = 110 * np.exp(-tt * 30) + 45
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) * np.exp(-tt * 20) * 0.9
            + lp(noise(len(tt), 99, "white"), 700) * np.exp(-tt * 45) * 0.4)


def jingle(win=True):
    # 4 note, maggiore per la vittoria, minore discendente per la sconfitta
    bpm = 120
    step = 60.0 / bpm
    notes = [523.25, 659.25, 783.99, 1046.5] if win else [440, 392, 349.23, 293.66]
    chunks = []
    for i, fq in enumerate(notes):
        tt = t(step * 1.4)
        tone = (np.sin(2 * np.pi * fq * tt) * 0.6
                + np.sin(2 * np.pi * fq * 2 * tt) * 0.15)
        tone *= np.exp(-tt * 4)
        chunks.append(tone)
    return np.concatenate(chunks) * 0.6


def music_loop():
    # loop lo-fi minimale: kick, snare, hat, basso. 8 battute a 84 BPM.
    bpm = 84.0
    beat = 60.0 / bpm
    bars = 2
    total = beat * 4 * bars
    n = int(SR * total)
    x = np.zeros(n)

    def add(at, sig):
        i = int(at * SR)
        x[i:i + len(sig)] += sig[:max(0, min(len(sig), n - i))]

    def kick():
        tt = t(0.22)
        f = 120 * np.exp(-tt * 30) + 42
        ph = 2 * np.pi * np.cumsum(f) / SR
        return np.sin(ph) * np.exp(-tt * 16) * 1.1

    def snare():
        tt = t(0.18)
        return (lp(noise(len(tt), 3, "white"), 2400) * np.exp(-tt * 28) * 0.7
                + sine(190, tt) * np.exp(-tt * 30) * 0.3)

    def hat():
        tt = t(0.05)
        return hp(noise(len(tt), 4, "white"), 6000) * np.exp(-tt * 90) * 0.28

    # basso: due note per barra (La1 / Do2)
    bass_pattern = [55.0, 55.0, 65.41, 65.41]
    for bar in range(bars):
        for b in range(4):
            bt = (bar * 4 + b) * beat
            add(bt, kick() if b in (0, 2) else np.zeros(1))
            add(bt + beat / 2, hat())
            add(bt, hat())
            if b in (1, 3):
                add(bt, snare())
            # basso sull'8vo
            bf = bass_pattern[(bar * 2) % len(bass_pattern)] if b < 2 else bass_pattern[(bar * 2 + 1) % len(bass_pattern)]
            bl = int(beat * 0.9 * SR)
            btt = np.linspace(0, beat * 0.9, bl)
            wave_ = (np.sin(2 * np.pi * bf * btt) * 0.5
                     + np.sin(2 * np.pi * bf * 2 * btt) * 0.12) * np.exp(-btt * 2.2)
            add(bt, wave_)
    # pad morbido di accordo (Fmaj7)
    pad = np.zeros(n)
    tt = np.linspace(0, total, n)
    for fq in [174.61, 220.0, 261.63, 329.63]:
        pad += np.sin(2 * np.pi * fq * tt) * 0.05
    x += pad
    fade = int(SR * 0.15)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * 0.8


def main():
    save("bounce1", bounce(1, 150))
    save("bounce2", bounce(2, 142))
    save("bounce3", bounce(3, 158))
    save("swish", swish())
    save("rim", rim())
    save("backboard", backboard())
    save("whistle", whistle(0.55))
    save("whistle_short", whistle(0.2, short=True))
    save("crowd_amb", crowd_loop())
    save("crowd_cheer", cheer(2.6, 7))
    save("crowd_cheer2", cheer(3.0, 17))
    save("crowd_ooh", cheer(1.3, 23, ooh=True))
    save("buzzer", buzzer())
    save("block", block_sfx())
    save("steal", steal_sfx())
    save("dunk", dunk_sfx())
    save("ui_tap", ui_tap())
    save("crossover", crossover_sfx())
    save("shot_release", release_sfx())
    save("beep", beep(880, 0.12))
    save("go", beep(1175, 0.3))
    save("body", body_thud())
    save("victory", jingle(True))
    save("defeat", jingle(False))
    save("music_loop", music_loop())
    print("SFX generati in", OUT)


if __name__ == "__main__":
    main()
