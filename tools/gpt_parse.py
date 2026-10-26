#!/usr/bin/env python3
"""Parse a raw GPT dump (primary or backup) and print a markdown partition table.

Usage: gpt_parse.py <gpt.bin> [sector_size=512]
Accepts a dump whose first 512 bytes are the protective MBR (header at LBA 1)
or one that starts directly with the 'EFI PART' header.
"""
import struct
import sys
import uuid

path = sys.argv[1]
ss = int(sys.argv[2]) if len(sys.argv) > 2 else 512
d = open(path, 'rb').read()
hdr = 0 if d[0:8] == b'EFI PART' else 512
if d[hdr:hdr + 8] != b'EFI PART':
    raise SystemExit('No EFI PART header found at offset 0 or 512')

rev, hdr_size = struct.unpack_from('<II', d, hdr + 8)
cur, bak, first_usable, last_usable = struct.unpack_from('<QQQQ', d, hdr + 24)
disk_guid = uuid.UUID(bytes_le=d[hdr + 56:hdr + 72])
pt_lba, num_parts, part_size, _crc = struct.unpack_from('<QIII', d, hdr + 72)

print(f'# GPT parse: {path}')
print(f'- Header at byte {hdr}: rev {rev:#x}, size {hdr_size}, '
      f'{num_parts} entries x {part_size}B at LBA {pt_lba}')
print(f'- Disk GUID: {disk_guid}')
print(f'- Usable LBAs {first_usable}..{last_usable}')
print()
print('| # | Name | Start LBA | End LBA | Size (MiB) | Code |')
print('|---|------|-----------|---------|------------|------|')

base = hdr + (pt_lba - 1) * ss  # entries usually follow the header in a raw dump
for i in range(num_parts):
    e = d[base + i * part_size: base + (i + 1) * part_size][:128]
    if len(e) < 128:
        break
    tguid = uuid.UUID(bytes_le=e[0:16])
    lba0, lba1 = struct.unpack_from('<QQ', e, 32)
    name = e[56:128].decode('utf-16-le').rstrip('\x00')
    if lba0 == 0 and lba1 == 0:
        continue
    size = (lba1 - lba0 + 1) * ss / 1048576
    # well-known short codes for the type GUIDs we care about
    known = {
        'c12a7328-f81f-11d2-ba4b-00a0c93ec93b': 'ESP',
        'e6d6d379-f507-44c2-a23c-238f2a3df928': 'LINUX-FS',
        '0657fd6d-a4ab-43c4-84e5-0933c84b4f4f': 'SWAP',
        'ebd0a0a2-b9e5-4433-87c0-68b6b72699c7': 'BASIC-DATA',
        'e3c9e316-0b5c-4db8-817d-f92df00215ae': 'MSR',
    }
    code = known.get(str(tguid), str(tguid)[:8])
    print(f'| {i + 1} | {name} | {lba0} | {lba1} | {size:.1f} | {code} |')
