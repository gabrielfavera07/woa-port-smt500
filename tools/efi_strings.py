#!/usr/bin/env python3
"""Scan an EFI/PE binary for ASCII and UTF-16LE strings matching a regex. Usage: efi_strings.py <file> [pattern]"""
import re, sys
path = sys.argv[1]; pat = re.compile(sys.argv[2] if len(sys.argv) > 2 else r'.', re.I)
data = open(path, 'rb').read()
seen = set()
def emit(s):
    if pat.search(s) and s not in seen and len(s) >= 6:
        seen.add(s); print(s)
for m in re.finditer(rb'[\x20-\x7e]{6,}', data):
    try: emit(m.group().decode('ascii'))
    except: pass
for m in re.finditer(rb'(?:[\x20-\x7e]\x00){6,}', data):
    try: emit(m.group().decode('utf-16-le'))
    except: pass
