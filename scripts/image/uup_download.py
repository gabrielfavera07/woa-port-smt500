#!/usr/bin/env python3
"""Baixa os arquivos UUP (manifest.tsv: name\tsha1\tsize\turl) com verificação SHA1.
Uso: python uup_download.py <manifest.tsv> <outdir>"""
import hashlib
import os
import sys
import time
import urllib.request

manifest, outdir = sys.argv[1], sys.argv[2]
os.makedirs(outdir, exist_ok=True)
rows = [l.rstrip('\n').split('\t') for l in open(manifest) if l.strip()]
total, done = len(rows), 0
for name, sha1, size, url in rows:
    dest = os.path.join(outdir, name)
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        h = hashlib.sha1(open(dest, 'rb').read()).hexdigest()
        if h == sha1:
            done += 1
            continue
    for attempt in range(5):
        try:
            urllib.request.urlretrieve(url, dest + '.part')
            os.replace(dest + '.part', dest)
            h = hashlib.sha1(open(dest, 'rb').read()).hexdigest()
            if h != sha1:
                raise RuntimeError(f'sha1 mismatch {h} != {sha1}')
            done += 1
            print(f'[{done}/{total}] OK {name[:60]}', flush=True)
            break
        except Exception as e:
            print(f'  retry {attempt + 1} {name[:40]}: {e}', flush=True)
            time.sleep(3 * (attempt + 1))
    else:
        print(f'FALHOU: {name}', flush=True)
        sys.exit(1)
print('DOWNLOAD COMPLETO — todos os SHA1 válidos')
