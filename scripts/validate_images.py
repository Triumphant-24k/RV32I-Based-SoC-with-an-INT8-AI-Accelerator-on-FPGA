#!/usr/bin/env python3
"""Validate the fixed-size, 32-bit little-endian $readmemh image contract."""
import argparse
import pathlib
import re

def validate_image(path, program=False):
    words=pathlib.Path(path).read_text(encoding='ascii').splitlines()
    if len(words)!=4096 or any(not re.fullmatch('[0-9a-fA-F]{8}',w) for w in words):
        raise ValueError(f'{path}: expected exactly 4096 lines of eight hexadecimal digits')
    if program and (all(int(w,16) in (0,0x13) for w in words) or (int(words[0],16)&3)!=3):
        raise ValueError(f'{path}: missing executable RV32I entry at reset address zero')
    return words

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('images',nargs='+');parser.add_argument('--program',action='store_true')
    args=parser.parse_args()
    for path in args.images: validate_image(path,args.program)
    print(f'PASS: {len(args.images)} memory images validated')
