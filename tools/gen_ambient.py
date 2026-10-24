#!/usr/bin/env python3
"""Generate the Home screen's seamless ambient loop (original, no samples).

  dreamy Y2K pad chords + soft glass bells + ocean waves + tropical birds/gulls

Everything is built circularly over LOOP seconds (FFT filtering/convolution and
wrapped envelopes), so the file loops with no seam.

  uv run --with numpy python gen_ambient.py out.wav
"""
import sys, wave
import numpy as np

SR = 32000
LOOP = 120.0
N = int(SR * LOOP)
rng = np.random.default_rng(23)
t = np.arange(N) / SR


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def circ_add(buf, start, sig):
    """add sig into buf starting at sample `start`, wrapping around the loop"""
    idx = (start + np.arange(len(sig))) % N
    np.add.at(buf, idx, sig)


def fft_filter(x, shape):
    """circular filter: shape(freqs) -> gain"""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X * shape(f), len(x))


def reverb(x, seconds=2.6, wet=0.35):
    """circular convolution with a decaying-noise impulse response"""
    L = int(SR * seconds)
    ir = rng.standard_normal(L) * np.exp(-np.arange(L) / (SR * seconds / 6.5))
    ir = fft_filter(np.pad(ir, (0, N - L)), lambda f: 1 / (1 + (f / 5000) ** 2))
    ir /= np.sqrt(np.sum(ir ** 2))
    y = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir), N)
    return (1 - wet) * x + wet * y


def rms_to(x, db):
    return x * (10 ** (db / 20) / (np.sqrt(np.mean(x ** 2)) + 1e-12))


# ---------------------------------------------------------------- pad
chords = [
    [53, 57, 60, 64, 67],   # Fmaj9
    [52, 55, 59, 62, 66],   # Em9
    [50, 53, 57, 60, 64],   # Dm9
    [48, 52, 55, 59, 62],   # Cmaj9
    [53, 57, 60, 64, 69],   # Fmaj7(13)
    [55, 59, 62, 64, 69],   # G6/9
    [52, 55, 59, 62, 67],   # Em7(add11)
    [45, 52, 55, 59, 60],   # Am9-ish
]
seg = LOOP / len(chords)
xfade = 4.0
padL = np.zeros(N); padR = np.zeros(N)
for ci, notes in enumerate(chords):
    start = ci * seg - xfade / 2
    length = seg + xfade
    n = int(length * SR)
    tt = np.arange(n) / SR
    env = np.ones(n)
    a = int(xfade * SR)
    env[:a] = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a))
    env[-a:] = 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, a))
    for vi, m in enumerate(notes + [notes[0] - 12]):
        f = midi(m)
        amp = 0.9 if vi < len(notes) else 0.6
        for det, pan in ((-0.0018, 0.25), (0.0018, 0.75)):
            ph = rng.uniform(0, 2 * np.pi)
            ff = f * (1 + det)
            s = (np.sin(2 * np.pi * ff * tt + ph)
                 + 0.30 * np.sin(2 * np.pi * 2 * ff * tt + ph * 1.3)
                 + 0.10 * np.sin(2 * np.pi * 3 * ff * tt + ph * 0.7))
            s *= amp * env * (0.85 + 0.15 * np.sin(2 * np.pi * 0.11 * tt + vi))
            circ_add(padL, int(start * SR), s * (1 - pan))
            circ_add(padR, int(start * SR), s * pan)
soft = lambda f: 1 / (1 + (f / 1400) ** 4)          # warm low-pass
padL, padR = fft_filter(padL, soft), fft_filter(padR, soft)

# glass bells (pentatonic, high register)
penta = [72, 74, 76, 79, 81, 84, 86, 88]
bellL = np.zeros(N); bellR = np.zeros(N)
pos = 1.5
while pos < LOOP:
    m = penta[rng.integers(len(penta))]
    f = midi(m)
    d = 3.0
    tt = np.arange(int(d * SR)) / SR
    s = (np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(2 * np.pi * f * 2.76 * tt) * np.exp(-tt * 3)
         ) * np.exp(-tt * 1.6) * (1 - np.exp(-tt * 200))
    pan = rng.uniform(0.2, 0.8)
    circ_add(bellL, int(pos * SR), s * (1 - pan) * 0.5)
    circ_add(bellR, int(pos * SR), s * pan * 0.5)
    pos += rng.uniform(3.5, 8.5)

musicL = rms_to(reverb(padL + 0.6 * bellL, 4.8, 0.62), -23)
musicR = rms_to(reverb(padR + 0.6 * bellR, 4.8, 0.62), -23)

# ---------------------------------------------------------------- waves
def band(lo, hi, tilt):
    w = rng.standard_normal(N)
    return fft_filter(w, lambda f: (1 / np.maximum(f, 20) ** tilt)
                      * (1 / (1 + (f / hi) ** 4)) * (1 - 1 / (1 + (f / lo) ** 2)))

rumbleL, rumbleR = band(60, 500, 0.5), band(60, 500, 0.5)
hissL, hissR = band(500, 6000, 0.3), band(500, 6000, 0.3)
rumbleL /= np.std(rumbleL); rumbleR /= np.std(rumbleR); hissL /= np.std(hissL); hissR /= np.std(hissR)

crash = np.zeros(N); wash = np.zeros(N); panw = np.full(N, 0.5)
pos = 0.0
while pos < LOOP:
    period = rng.uniform(7.5, 11.5)
    n = int(period * SR)
    tt = np.arange(n) / SR
    c = (1 - np.exp(-tt / 0.35)) * np.exp(-tt / 1.4)             # break
    w = (1 - np.exp(-tt / 0.9)) * np.exp(-tt / 3.2)              # wash up / drain
    strength = rng.uniform(0.6, 1.0)
    circ_add(crash, int(pos * SR), c * strength)
    circ_add(wash, int(pos * SR), w * strength)
    pos += period
base = 0.18                                                       # constant distant surf
wavesL = (base + wash) * rumbleL * 0.9 + (0.05 + crash * 1.3 + wash * 0.35) * hissL
wavesR = (base + wash) * rumbleR * 0.9 + (0.05 + crash * 1.3 + wash * 0.35) * hissR
wavesL, wavesR = rms_to(wavesL, -23), rms_to(wavesR, -23)

# ---------------------------------------------------------------- birds
birdsL = np.zeros(N); birdsR = np.zeros(N)

def chirp(f0, f1, d, vib=0.0):
    tt = np.arange(int(d * SR)) / SR
    f = f0 + (f1 - f0) * tt / d + vib * np.sin(2 * np.pi * 38 * tt)
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.sin(np.pi * tt / d) ** 2
    return (np.sin(ph) + 0.2 * np.sin(2 * ph)) * env

def gull():
    d = 0.42
    tt = np.arange(int(d * SR)) / SR
    f = 1450 - 520 * (tt / d) ** 0.7
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = sum(a * np.sin(k * ph) for k, a in ((1, 1.0), (2, 0.7), (3, 0.5), (4, 0.25), (5, 0.12)))
    env = np.sin(np.pi * tt / d) ** 1.5
    return s * env * 0.35

pos = 3.0
while pos < LOOP:
    pan = rng.uniform(0.1, 0.9)
    call = []
    if rng.random() < 0.10:                     # a distant gull, 2-3 calls
        for _ in range(rng.integers(2, 4)):
            call.append(gull()); call.append(np.zeros(int(SR * rng.uniform(0.12, 0.25))))
        gain = 0.35
    else:                                       # small tropical bird
        f0 = rng.uniform(2600, 3800)
        for _ in range(rng.integers(3, 7)):
            call.append(chirp(f0, f0 * rng.uniform(1.15, 1.45), rng.uniform(0.05, 0.10), rng.uniform(0, 120)))
            call.append(np.zeros(int(SR * rng.uniform(0.04, 0.09))))
        gain = 0.30
    s = np.concatenate(call) * gain
    circ_add(birdsL, int(pos * SR), s * (1 - pan))
    circ_add(birdsR, int(pos * SR), s * pan)
    pos += rng.uniform(12.0, 26.0)
far = lambda f: 1 / (1 + (f / 6500) ** 2)
birdsL = reverb(fft_filter(birdsL, far), 1.8, 0.4)
birdsR = reverb(fft_filter(birdsR, far), 1.8, 0.4)

# ---------------------------------------------------------------- mix
L = musicL + wavesL + birdsL * 0.30
R = musicR + wavesR + birdsR * 0.30
peak = max(np.max(np.abs(L)), np.max(np.abs(R)))
g = 10 ** (-3 / 20) / peak
pcm = (np.stack([L, R], 1) * g * 32767).astype(np.int16)
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print("wrote", sys.argv[1], f"{LOOP:.0f}s @ {SR} Hz")
