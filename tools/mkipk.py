#!/usr/bin/env python3
"""Build a webOS .ipk from an app folder: mkipk.py <appdir> <out.ipk>"""
import sys, os, io, json, tarfile, time
appdir, out = sys.argv[1], sys.argv[2]
info = json.load(open(os.path.join(appdir, 'appinfo.json')))
aid, ver = info['id'], info['version']
now = int(time.time())
def tgz(add):
    b = io.BytesIO()
    with tarfile.open(fileobj=b, mode='w:gz', format=tarfile.GNU_FORMAT) as t:
        add(t)
    return b.getvalue()
def addbytes(t, name, data, mode=0o644):
    ti = tarfile.TarInfo(name); ti.size = len(data); ti.mtime = now; ti.mode = mode
    t.addfile(ti, io.BytesIO(data))
def adddir(t, name):
    ti = tarfile.TarInfo(name); ti.type = tarfile.DIRTYPE; ti.mtime = now; ti.mode = 0o755; t.addfile(ti)
def data(t):
    for d in ['./usr', './usr/palm', './usr/palm/applications', './usr/palm/packages',
              f'./usr/palm/applications/{aid}', f'./usr/palm/packages/{aid}']:
        adddir(t, d)
    for root, dirs, files in os.walk(appdir):
        rel = os.path.relpath(root, appdir)
        base = f'./usr/palm/applications/{aid}' + ('' if rel == '.' else '/' + rel)
        if rel != '.': adddir(t, base)
        for f in sorted(files):
            addbytes(t, base + '/' + f, open(os.path.join(root, f), 'rb').read())
    pkg = {"id": aid, "version": ver, "app": aid, "loc_name": info.get('title', aid)}
    addbytes(t, f'./usr/palm/packages/{aid}/packageinfo.json', json.dumps(pkg, indent=2).encode())
def control(t):
    c = (f"Package: {aid}\nVersion: {ver}\nSection: misc\nPriority: optional\nArchitecture: all\n"
         f"Installed-Size: 1\nMaintainer: local\nDescription: {info.get('title', aid)}\n")
    addbytes(t, './control', c.encode())
members = [('debian-binary', b'2.0\n'), ('control.tar.gz', tgz(control)), ('data.tar.gz', tgz(data))]
with open(out, 'wb') as o:
    o.write(b'!<arch>\n')
    for name, b in members:
        hdr = f'{name:<16}{now:<12}{0:<6}{0:<6}{"100644":<8}{len(b):<10}`\n'.encode()
        o.write(hdr); o.write(b)
        if len(b) % 2: o.write(b'\n')
print(out, os.path.getsize(out), 'bytes')
