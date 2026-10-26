#!/usr/bin/env python3
"""Extract selected images from Samsung tar.md5 firmware archives (auto-lz4 decompress).
Usage: extract_firmware.py <tar.md5>... --out DIR [--names n1,n2]  (names = member prefixes)"""
import io, os, sys, tarfile
import lz4.frame

args = sys.argv[1:]
tars, out, names = [], '.', []
i = 0
while i < len(args):
    if args[i] == '--out': out = args[i+1]; i += 2
    elif args[i] == '--names': names = args[i+1].split(','); i += 2
    else: tars.append(args[i]); i += 1
os.makedirs(out, exist_ok=True)
for t in tars:
    print(f'== {os.path.basename(t)}')
    with tarfile.open(t, 'r') as tf:
        for m in tf.getmembers():
            base = os.path.basename(m.name).removesuffix('.lz4')
            if names and not any(base.startswith(n) for n in names):
                continue
            data = tf.extractfile(m).read()
            if m.name.endswith('.lz4'):
                data = lz4.frame.decompress(data)
            dest = os.path.join(out, base)
            with open(dest, 'wb') as f:
                f.write(data)
            print(f'  {base}: {len(data):,} bytes -> {dest}')
