#!/usr/bin/env python3
"""Original UI sounds for the Home screen, in a soft glassy PSP/PS2-era spirit.

  move_0..4.wav : crystalline tick, one pentatonic pitch per tile
  select.wav    : bright two-note chime with shimmer
  uv run --with numpy python gen_sfx.py <outdir>
"""
import sys, os, wave
import numpy as np

SR = 44100
out = sys.argv[1]
os.makedirs(out, exist_ok=True)


def write(name, x, peak_db=-6.0):
    x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20)
    pcm = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(out, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())


def tone(f, d, decay, partials=((1, 1.0),), attack=0.002, glide=0.0):
    t = np.arange(int(d * SR)) / SR
    ff = f * (1 + glide * np.exp(-t * 60))          # tiny pitch drop at the start
    ph = 2 * np.pi * np.cumsum(ff) / SR
    s = sum(a * np.sin(k * ph) * np.exp(-t * decay * (1 + 0.6 * (k - 1))) for k, a in partials)
    env = np.minimum(1, t / attack)
    return s * env


def room(x, d=0.35, wet=0.25):
    n = int(d * SR)
    ir = np.random.default_rng(5).standard_normal(n) * np.exp(-np.arange(n) / (SR * d / 5))
    y = np.convolve(x, ir)[: len(x) + n]
    y = np.pad(y, (0, len(x) + n - len(y)))
    y /= np.max(np.abs(y)) + 1e-9
    xx = np.pad(x, (0, n)) / (np.max(np.abs(x)) + 1e-9)
    return (1 - wet) * xx + wet * y


# move: glassy tick (soft click transient + bell body), pentatonic per tile
penta = [76, 79, 81, 84, 86]                       # E5 G5 A5 C6 D6
for i, m in enumerate(penta):
    f = 440 * 2 ** ((m - 69) / 12)
    body = tone(f, 0.16, 38, ((1, 1.0), (2.01, 0.25), (3.98, 0.08)), glide=0.03)
    click = np.random.default_rng(i).standard_normal(int(0.004 * SR)) * np.linspace(1, 0, int(0.004 * SR)) * 0.25
    x = body.copy(); x[: len(click)] += click
    write(f"move_{i}.wav", room(x, 0.25, 0.18), -9)

# select: two rising notes + airy shimmer
f1, f2 = 440 * 2 ** ((81 - 69) / 12), 440 * 2 ** ((88 - 69) / 12)   # A5 -> E6
a = tone(f1, 0.45, 9, ((1, 1.0), (2, 0.3), (3, 0.1)))
b = tone(f2, 0.60, 7, ((1, 1.0), (2, 0.25), (4.01, 0.06)))
x = np.zeros(int(0.75 * SR)); x[: len(a)] += a; off = int(0.07 * SR); x[off: off + len(b)] += b * 0.9
t = np.arange(len(x)) / SR
shimmer = sum(np.sin(2 * np.pi * f * t + p) for f, p in ((2637, 0.3), (3136, 1.1), (3520, 2.0))) * np.exp(-t * 6) * 0.08
write("select.wav", room(x + shimmer, 0.5, 0.3), -6)
print("wrote sfx to", out)
