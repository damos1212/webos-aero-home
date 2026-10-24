#!/bin/sh
# make-audio.sh : generate the ambient loop (home/tld.my.home/ambient.wav) and, optionally,
# regenerate the menu sounds. Everything is synthesised by our own scripts, no samples.
# Needs uv (https://docs.astral.sh/uv/) or Python 3 with numpy.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="uv run --quiet --no-project --with numpy python"
command -v uv >/dev/null 2>&1 || RUN=python3
$RUN "$ROOT/tools/gen_ambient.py" "$ROOT/home/tld.my.home/ambient.wav"
[ "$1" = "--sfx" ] && $RUN "$ROOT/tools/gen_sfx.py" "$ROOT/home/tld.my.home/sfx"
echo "audio ready"
