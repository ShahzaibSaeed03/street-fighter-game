#!/usr/bin/env python3
"""Synthesizes every sound effect + the music loop for the game (no external assets, no licenses).
Run:  python tools/make_audio.py      (needs numpy + scipy)  -> writes assets/audio/*.wav
"""
import os
import wave
import numpy as np
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env_exp(n, decay):
    return np.exp(-np.arange(n) / SR * decay)


def fade(x, a=0.004, r=0.02):
    n = len(x)
    ia, ir = int(SR * a), int(SR * r)
    x = x.copy()
    if ia > 0:
        x[:ia] *= np.linspace(0, 1, ia)
    if ir > 0:
        x[-ir:] *= np.linspace(1, 0, ir)
    return x


def lowpass(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def save(name, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m * peak
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", name, f"{len(x) / SR:.2f}s")


def noise(n):
    return rng.standard_normal(n)


# ---------------- SFX ----------------
def swing():
    dur = 0.28
    n = int(SR * dur)
    x = noise(n)
    # whoosh: noise whose band sweeps upward then dies
    out = np.zeros(n)
    chunks = 8
    cs = n // chunks
    for i in range(chunks):
        lo = 400 + i * 350
        seg = bandpass(x[i * cs:(i + 1) * cs + 1], lo, lo * 2.2)[:cs]
        out[i * cs:(i + 1) * cs] = seg
    e = np.sin(np.linspace(0, np.pi, n)) ** 1.6
    save("swing", fade(out * e), 0.7)


def hit():
    dur = 0.28
    t = t_axis(dur)
    n = len(t)
    thump = np.sin(2 * np.pi * (150 * np.exp(-t * 14) + 45) * t) * env_exp(n, 18)
    click = highpass(noise(n), 1800) * env_exp(n, 90)
    ring = (np.sin(2 * np.pi * 820 * t) + 0.6 * np.sin(2 * np.pi * 1310 * t)) * env_exp(n, 28)
    flesh = lowpass(noise(n), 900) * env_exp(n, 30)
    save("hit", fade(thump * 1.0 + click * 0.5 + ring * 0.18 + flesh * 0.5), 0.9)


def hurt():
    dur = 0.38
    t = t_axis(dur)
    n = len(t)
    f = 220 * np.exp(-t * 3.5) + 70
    buzz = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 7)
    thump = np.sin(2 * np.pi * 60 * t) * env_exp(n, 14)
    grit = lowpass(noise(n), 1500) * env_exp(n, 22)
    save("hurt", fade(lowpass(buzz, 1800) * 0.7 + thump + grit * 0.5), 0.9)


def dodge():
    dur = 0.2
    n = int(SR * dur)
    x = highpass(noise(n), 2500)
    e = np.sin(np.linspace(0, np.pi, n)) ** 2
    save("dodge", fade(x * e), 0.55)


def coin():
    dur = 0.38
    t = t_axis(dur)
    n = len(t)
    a = np.where(t < 0.07, 1.0, 0.0)
    f1 = np.sin(2 * np.pi * 988 * t) + 0.35 * np.sin(2 * np.pi * 1976 * t)
    f2 = np.sin(2 * np.pi * 1319 * t) + 0.35 * np.sin(2 * np.pi * 2638 * t)
    first = f1 * env_exp(n, 30) * (t < 0.07)
    second = f2 * env_exp(n, 9) * (t >= 0.07)
    save("coin", fade(first + second), 0.6)


def enemy_death():
    dur = 0.5
    t = t_axis(dur)
    n = len(t)
    f = 180 * np.exp(-t * 5) + 40
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 7)
    splat = lowpass(noise(n), 1200) * env_exp(n, 12)
    zap = highpass(noise(n), 3000) * env_exp(n, 60)
    save("enemy_death", fade(body + splat * 0.8 + zap * 0.25), 0.9)


def player_death():
    dur = 1.6
    t = t_axis(dur)
    n = len(t)
    f = 160 * np.exp(-t * 1.6) + 38
    drone = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 2.2)
    sub = np.sin(2 * np.pi * 46 * t) * env_exp(n, 1.6)
    save("player_death", fade(lowpass(drone, 700) * 0.7 + sub, 0.01, 0.2), 0.9)


def click():
    dur = 0.07
    t = t_axis(dur)
    x = np.sin(2 * np.pi * 760 * t) * env_exp(len(t), 55)
    save("click", fade(x, 0.002, 0.01), 0.5)


def heal():
    notes = [659.25, 830.61, 987.77]
    total = np.zeros(int(SR * 0.7))
    for i, f in enumerate(notes):
        t = t_axis(0.45)
        tone = (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t)) * env_exp(len(t), 7)
        s = int(SR * 0.07 * i)
        total[s:s + len(tone)] += tone
    save("heal", fade(total, 0.004, 0.08), 0.55)


def wave_complete():
    notes = [523.25, 659.25, 783.99, 1046.5]
    total = np.zeros(int(SR * 1.2))
    for i, f in enumerate(notes):
        t = t_axis(0.7)
        tone = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t)) * env_exp(len(t), 4.5)
        s = int(SR * 0.11 * i)
        total[s:s + len(tone)] += tone
    save("wave_complete", fade(total, 0.004, 0.1), 0.7)


# ---------------- Music loop (dark ambient, A minor, 4 chords x 6 s = 24 s) ----------------
def music():
    chord_len = 6.0
    chords = [
        (55.0, [220.0, 261.63, 329.63]),    # Am
        (43.65, [174.61, 220.0, 261.63]),   # F
        (49.0, [196.0, 246.94, 293.66]),    # G
        (41.2, [164.81, 207.65, 246.94]),   # E
    ]
    total_len = int(SR * chord_len * len(chords))
    mix = np.zeros(total_len)

    def add_wrap(buf, seg, start):
        end = start + len(seg)
        if end <= len(buf):
            buf[start:end] += seg
        else:
            k = len(buf) - start
            buf[start:] += seg[:k]
            buf[:end - len(buf)] += seg[k:]

    for ci, (bass, notes) in enumerate(chords):
        seg_dur = chord_len + 2.0               # overlap into the next chord so loop is seamless
        t = t_axis(seg_dur)
        n = len(t)
        env = np.minimum(1.0, t / 1.4) * np.minimum(1.0, (seg_dur - t) / 1.4)
        pad = np.zeros(n)
        for f in notes:
            for det in (-0.004, 0.0, 0.004):
                pad += np.sin(2 * np.pi * f * (1 + det) * t + rng.uniform(0, 6.28))
        pad = lowpass(pad, 1400) * env * (0.5 + 0.2 * np.sin(2 * np.pi * 0.17 * t))
        sub = np.sin(2 * np.pi * bass * t) * env * 1.2
        sub += 0.4 * np.sin(2 * np.pi * bass * 2 * t) * env
        add_wrap(mix, (pad * 0.35 + sub * 0.5), int(SR * chord_len * ci))

        # soft arpeggio plucks (8th notes at 100 BPM)
        step = 60.0 / 100.0 / 2.0
        k = 0
        pos = 0.0
        while pos < chord_len:
            f = notes[k % len(notes)] * 2
            tt = t_axis(0.9)
            pl = np.sin(2 * np.pi * f * tt) * env_exp(len(tt), 5.5)
            pl += 0.3 * np.sin(2 * np.pi * f * 2 * tt) * env_exp(len(tt), 9)
            add_wrap(mix, pl * 0.10, int(SR * (chord_len * ci + pos)))
            pos += step
            k += 1

        # slow heartbeat drum on beats 1 and 3 of every bar
        beat = 60.0 / 100.0
        pos = 0.0
        b = 0
        while pos < chord_len:
            if b % 2 == 0:
                tt = t_axis(0.5)
                d = np.sin(2 * np.pi * (90 * np.exp(-tt * 18) + 38) * tt) * env_exp(len(tt), 9)
                add_wrap(mix, d * 0.55, int(SR * (chord_len * ci + pos)))
            pos += beat
            b += 1

    mix = lowpass(mix, 9000)
    save("music", mix, 0.55)


if __name__ == "__main__":
    swing(); hit(); hurt(); dodge(); coin(); enemy_death(); player_death(); click(); heal(); wave_complete(); music()
