#!/usr/bin/env python3
"""Mix the trailer soundtrack to match the demo timeline in main.qml (record mode):
ambience fades in, a pentatonic tick per move (tile index -> move_<i>.wav), the select
chime, the ambience dipping while the 'app' is open, then returning."""
import os, sys, wave
import numpy as np
T = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.join(T, "..", "home", "tld.my.home")
SR = 48000
DUR = 16.7

def load(path):
    with wave.open(path) as w:
        sr, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
        x = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float64) / 32768
    x = x.reshape(-1, ch)
    if ch == 1: x = np.repeat(x, 2, axis=1)
    t_src = np.arange(len(x)) / sr
    t_dst = np.arange(int(len(x) * SR / sr)) / SR
    return np.stack([np.interp(t_dst, t_src, x[:, c]) for c in range(2)], 1)

N = int(DUR * SR)
t = np.arange(N) / SR
amb = load(os.path.join(HOME, "ambient.wav"))[:N]
# ambience level: fade in 0-0.9 s, fade out after selecting YouTube at 15.2 s (main.qml bgmLevel, 900 ms)
lvl = np.clip(t / 0.9, 0, 1)
lvl = np.where(t > 15.2, np.clip(1 - (t - 15.2) / 0.9, 0, 1), lvl)
mix = amb * (0.55 * lvl)[:, None]

def place(name, at, vol):
    s = load(os.path.join(HOME, "sfx", name)) * vol
    i = int(at * SR); j = min(N, i + len(s))
    mix[i:j] += s[: j - i]

sel = 1
for at, d in [(4.0, 1), (5.3, 1), (6.6, 1), (8.3, -1), (9.2, -1), (10.1, -1), (11.0, -1), (13.0, 1)]:
    sel += d
    place("move_%d.wav" % sel, at, 0.55)
place("select.wav", 15.2, 0.65)
# gentle tail fade
mix *= np.clip((DUR - t) / 1.0, 0, 1)[:, None]
peak = np.max(np.abs(mix))
if peak > 0.98: mix *= 0.98 / peak
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(T, "build", "audio.wav")
with wave.open(out, "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((mix * 32767).astype(np.int16).tobytes())
print("wrote", out)
