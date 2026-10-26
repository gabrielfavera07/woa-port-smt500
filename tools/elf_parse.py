#!/usr/bin/env python3
"""Minimal ELF header/segment/section parser. Usage: elf_parse.py <file.elf>"""
import struct, sys
d = open(sys.argv[1], 'rb').read()
is64 = d[4] == 2
end = '<' if d[5] == 1 else '>'
machine = {0xB7: 'AArch64', 0x28: 'ARM', 0x3E: 'x86-64', 0x5064: 'QDSP6'}.get(struct.unpack_from(end+'H', d, 18)[0], hex(struct.unpack_from(end+'H', d, 18)[0]))
etype = {2: 'EXEC', 3: 'DYN', 4: 'CORE'}.get(struct.unpack_from(end+'H', d, 16)[0], '?')
if is64:
    entry, phoff, shoff = struct.unpack_from(end+'QQQ', d, 24)
    phentsize, phnum, shentsize, shnum, shstrndx = struct.unpack_from(end+'HHHHH', d, 54)
    phfmt = end + 'IIQQQQQQ'
else:
    entry, phoff, shoff = struct.unpack_from(end+'III', d, 24)
    phentsize, phnum, shentsize, shnum, shstrndx = struct.unpack_from(end+'HHHHH', d, 44)
    phfmt = end + 'IIIIIIII'
print(f'ELF{"64" if is64 else "32"} {etype} machine={machine} entry={entry:#x} phnum={phnum} shnum={shnum} size={len(d):,}')
types = {1:'LOAD',2:'DYNAMIC',3:'INTERP',4:'NOTE',6:'PHDR',7:'TLS',0x6474e550:'GNU_EH_FRAME',0x6474e551:'GNU_STACK',0x70000001:'ARM_EXIDX',0x70000003:'ARM_ATTRIBUTES'}
for i in range(phnum):
    p = struct.unpack_from(phfmt, d, phoff + i*phentsize)
    if is64:
        p_type, flags, off, vaddr, paddr, filesz, memsz, align = p
    else:
        p_type, off, vaddr, paddr, filesz, memsz, flags, align = p
    t = types.get(p_type, hex(p_type))
    if p_type in (1, 2, 0x70000001, 0x70000003):
        print(f'  PH{i}: {t:14s} off={off:#010x} vaddr={vaddr:#010x} paddr={paddr:#010x} filesz={filesz:#x} flags={flags:#x}')
# section names
if shnum:
    sh = struct.unpack_from(end + ('IIQQQQIIQQ' if is64 else 'IIIIIIIIII'), d, shoff + shstrndx*shentsize)
    strtab_off = sh[4] if is64 else sh[4]
    for i in range(min(shnum, 40)):
        s = struct.unpack_from(end + ('IIQQQQIIQQ' if is64 else 'IIIIIIIIII'), d, shoff + i*shentsize)
        nameoff = s[0]
        nend = d.index(b'\x00', strtab_off + nameoff)
        nm = d[strtab_off+nameoff:nend].decode('ascii','replace')
        if nm and not nm.startswith('.debug'):
            print(f'  SH{i}: {nm:22s} type={s[1]:#x} off={s[4]:#x} size={s[5]:#x}')
