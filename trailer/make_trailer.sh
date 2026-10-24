#!/bin/sh
# Render the Home trailer on this machine (headless) and encode it for X/Twitter.
#   trailer/make_trailer.sh  ->  trailer/out/home-trailer.mp4
set -e
cd "$(dirname "$0")"
python3 prepare.py
export LD_LIBRARY_PATH="$PWD/.deps/root/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
[ -f .deps/root/usr/lib/x86_64-linux-gnu/libxcb-xinerama.so.0 ] || { mkdir -p .deps && cd .deps && apt download libxcb-xinerama0 && dpkg-deb -x libxcb-xinerama0_*.deb root && cd ..; }
xvfb-run -a -s "-screen 0 1920x1080x24" uv run --quiet --no-project --python 3.10 --with pyside2 python render.py 2>&1 | grep -E "recording finished|failed" || true
uv run --quiet --no-project --with numpy python mix_audio.py build/audio.wav
# build an exact 30 fps sequence: for each 1/30 s slot take the frame with the nearest animation time
python3 - <<'PY'
import os, bisect
d = "build/rec"; out = "build/seq"
os.makedirs(out, exist_ok=True)
for f in os.listdir(out): os.remove(os.path.join(out, f))
fs = sorted(f for f in os.listdir(d) if f.startswith("f"))
ts = [int(f[1:8]) for f in fs]
n = int(ts[-1] / 1000 * 30) + 1
for k in range(n):
    t = k * 1000 / 30
    i = bisect.bisect_left(ts, t)
    j = min((c for c in (i - 1, i) if 0 <= c < len(ts)), key=lambda c: abs(ts[c] - t))
    os.symlink(os.path.abspath(os.path.join(d, fs[j])), os.path.join(out, "s%05d.jpg" % k))
print("captured", len(fs), "steps ->", n, "frames at 30 fps")
PY
mkdir -p out
ffmpeg -loglevel error -y -framerate 30 -i build/seq/s%05d.jpg -i build/audio.wav \
  -vf "fade=t=in:st=0:d=0.5,fade=t=out:st=15.6:d=1.1,format=yuv420p" \
  -c:v libx264 -preset slow -crf 17 -profile:v high -r 30 -c:a aac -b:a 192k -shortest -movflags +faststart out/home-trailer.mp4
ls -la out/home-trailer.mp4
