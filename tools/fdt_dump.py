#!/usr/bin/env python3
"""Flattened Device Tree (DTB) dumper — prints the node tree with properties.

Usage: fdt_dump.py <file.dtb> <out.txt>
Strings are decoded when they look like NUL-terminated printable text; values whose
length is a multiple of 4 are shown as big-endian cell lists; anything else as hex.
"""
import struct
import sys

FDT_BEGIN = 1
FDT_END_NODE = 2
FDT_PROP = 3
FDT_NOP = 4


def be32(buf, off):
    return struct.unpack_from('>I', buf, off)[0]


def printable_string(val):
    if not val or val[-1] != 0:
        return None
    body = val[:-1]
    if not body:
        return ''
    if all(32 <= c < 127 for c in body):
        return body.decode('ascii')
    # list of NUL-separated printable strings
    parts = body.split(b'\x00')
    if parts and all(p == b'' or all(32 <= c < 127 for c in p) for p in parts):
        return body.decode('ascii').replace('\x00', '\\0')
    return None


def dump(path, out):
    d = open(path, 'rb').read()
    (magic, totalsize, off_struct, off_strings, _off_rsv, _ver, _last,
     _cpuid, size_strings, size_struct) = struct.unpack_from('>10I', d, 0)
    assert magic == 0xD00DFEED, f'bad FDT magic {magic:#x}'
    strtab = d[off_strings:off_strings + size_strings]
    f = out
    pos = off_struct
    depth = 0
    while pos < off_struct + size_struct:
        tok = be32(d, pos)
        pos += 4
        if tok == FDT_BEGIN:
            end = d.index(b'\x00', pos)
            name = d[pos:end].decode('ascii', 'replace')
            f.write('  ' * depth + name + ' {\n')
            depth += 1
            pos = (end + 1 + 3) & ~3
        elif tok == FDT_END_NODE:
            depth -= 1
            f.write('  ' * depth + '};\n')
        elif tok == FDT_PROP:
            plen, noff = struct.unpack_from('>II', d, pos)
            pos += 8
            nend = strtab.index(b'\x00', noff)
            pname = strtab[noff:nend].decode('ascii', 'replace')
            val = d[pos:pos + plen]
            pos += (plen + 3) & ~3
            s = printable_string(val)
            if s is not None:
                shown = f'"{s}"'
            elif len(val) % 4 == 0 and len(val) <= 64:
                shown = '<' + ' '.join(f'{x:#x}' for x in struct.unpack(f'>{len(val)//4}I', val)) + '>'
            elif len(val) <= 96:
                shown = '[' + val.hex() + f'] ({len(val)}B)'
            else:
                shown = f'[{len(val)} bytes]'
            f.write('  ' * depth + f'{pname} = {shown};\n')
        elif tok == FDT_NOP:
            continue
        elif tok == 0x9:  # FDT_END
            break
        else:
            f.write(f'?? token {tok:#x} at {pos - 4:#x}\n')
            break


if __name__ == '__main__':
    with open(sys.argv[2], 'w', encoding='utf-8') as o:
        dump(sys.argv[1], o)
    print('wrote', sys.argv[2])
