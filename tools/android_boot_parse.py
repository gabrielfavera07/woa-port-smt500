#!/usr/bin/env python3
"""Android boot image header parser (v0-v4). Usage: android_boot_parse.py <boot.img>"""
import struct, sys
d = open(sys.argv[1], 'rb').read()
magic = d[0:8]
if magic == b'ANDROID!':
    kernel_size, kernel_addr, ramdisk_size, ramdisk_addr, second_size, second_addr, \
    tags_addr, page_size, dt_size, unused, name, cmdline, img_id = struct.unpack_from(
        '<10I24s512s32s', d, 8)
    print(f'boot img v0/v1/v2: page={page_size}')
    print(f'  kernel: {kernel_size:,}B @ {kernel_addr:#x}')
    print(f'  ramdisk: {ramdisk_size:,}B @ {ramdisk_addr:#x}')
    print(f'  second:  {second_size:,}B @ {second_addr:#x}')
    print(f'  dtb:     {dt_size:,}B, tags {tags_addr:#x}')
    print(f'  name: {name.rstrip(b chr(0).encode()).decode() if False else name.rstrip(bytes(1)).decode("ascii","replace")}')
    print(f'  cmdline: {cmdline.rstrip(bytes(1)).decode("ascii","replace")}')
    off = page_size
    print(f'  kernel starts @{off:#x}, first bytes: {d[off:off+16].hex()}')
elif magic == b'VNDRBOOT':
    print('vendor boot v3/v4')
else:
    print('magic:', magic, d[:32].hex())
