#!/usr/bin/env python3
"""Build trailer/build/app from ../home/tld.my.home for desktop rendering:
point icon/record/frame paths at the trailer folder and make the GLES shaders
desktop-GL friendly (precision statements only under GL_ES)."""
import os, re, shutil
T = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(T, "..", "home", "tld.my.home")
OUT = os.path.join(T, "build", "app")
shutil.rmtree(os.path.join(T, "build"), ignore_errors=True)
os.makedirs(OUT); os.makedirs(os.path.join(T, "build", "rec"))
open(os.path.join(T, "build", "home-record"), "w").write("1\n")
for fn in os.listdir(SRC):
    if not fn.endswith(".qml"):
        continue
    s = open(os.path.join(SRC, fn)).read()
    s = s.replace("file:///media/developer/apps/usr/palm/applications/", "file://" + os.path.join(T, "apps") + "/")
    s = s.replace("file:///tmp/home-record", "file://" + os.path.join(T, "build", "home-record"))
    s = s.replace('"/tmp/rec/f"', '"' + os.path.join(T, "build", "rec", "f") + '"')
    s = s.replace("""            #ifdef GL_FRAGMENT_PRECISION_HIGH
            precision highp float;
            #else
            precision mediump float;
            #endif""", """            #ifdef GL_ES
            precision highp float;
            #endif""")
    s = re.sub(r'(\n\s*)precision mediump float;', r'\1#ifdef GL_ES\1precision mediump float;\1#endif', s)
    open(os.path.join(OUT, fn), "w").write(s)
print("prepared", OUT)
