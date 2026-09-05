#!/usr/bin/env python3
"""Build RV32I/ILP32 firmware, audit opcodes, and emit full little-endian ROM/RAM images."""
import pathlib
import re
import struct
import subprocess
from reference import main as generate
ROOT=pathlib.Path(__file__).resolve().parents[1]
PREFIX='riscv64-unknown-elf-'

def run(cmd):
    return subprocess.check_output(cmd,cwd=ROOT,text=True,stderr=subprocess.STDOUT)

def emit_images(elf, stem):
    data=elf.read_bytes()
    assert data[:7] == b'\x7fELF\x01\x01\x01', 'Expected little-endian ELF32'
    header=struct.unpack_from('<16sHHIIIIIHHHHHH',data)
    assert header[2] == 243 and header[4] == 0, 'Expected RISC-V entry at zero'
    rom=bytearray(b'\x13\x00\x00\x00'*4096)
    ram=bytearray(16384)
    # PT_LOAD physical addresses include the ROM copy of .data; startup copies
    # it to RAM and clears BSS. Runtime RAM initialization is deliberately zero.
    for i in range(header[10]):
        ph=struct.unpack_from('<IIIIIIII',data,header[5]+i*header[9])
        typ,off,vaddr,paddr,filesz,memsz,flags,align=ph
        if typ != 1 or filesz == 0: continue
        assert paddr+filesz <= len(rom), f'ROM segment overflow: {paddr:x}'
        assert vaddr+memsz <= 0x4000 or (0x10000<=vaddr and vaddr+memsz<=0x13000)
        rom[paddr:paddr+filesz]=data[off:off+filesz]
    dest=ROOT/'firmware'/'hex'; dest.mkdir(exist_ok=True)
    for kind,blob in [('rom',rom),('ram',ram)]:
        (dest/f'{stem}_{kind}.hex').write_text(''.join(f'{v[0]:08x}\n' for v in struct.iter_unpack('<I',blob)))

def audit(disassembly):
    allowed={0x03,0x23,0x13,0x33,0x37,0x17,0x63,0x67,0x6f,0x0f}
    seen=set(); count=0
    for line in disassembly.splitlines():
        match=re.match(r'^\s*[0-9a-f]+:\s+([0-9a-f]+)\s+([a-z0-9.]+)',line)
        if not match: continue
        raw,mnemonic=match.groups(); word=int(raw,16); op=word&127
        assert len(raw)==8 and op in allowed, f'Unsupported instruction: {line}'
        if op==0x33: assert word>>25 in (0,0x20), f'Non-RV32I ALU: {line}'
        if op==0x13 and (word>>12)&7 in (1,5): assert word>>25 in (0,0x20)
        seen.add(mnemonic); count+=1
    assert 'lb' in seen and 'lw' in seen and 'sw' in seen, seen
    assert count > 0
    return f'{count} static instructions, RV32I opcode audit PASS; mnemonics: '+', '.join(sorted(seen))

def main():
    generate()
    out=ROOT/'build'/'firmware'; out.mkdir(parents=True,exist_ok=True)
    for stem,defines in [('demo',[]),('cpu',['-DCPU_ONLY'])]:
        elf=out/f'{stem}.elf'
        flags=['-march=rv32i','-mabi=ilp32','-O2','-ffreestanding','-fno-builtin',
               '-fno-pic','-msmall-data-limit=0','-mno-relax','-fno-inline-functions',
               '-nostdlib','-nostartfiles','-Wall','-Wextra','-Werror',
               '-Wl,--no-relax','-T','firmware/link.ld',f'-Wl,-Map,build/firmware/{stem}.map']
        run([PREFIX+'gcc',*flags,*defines,'firmware/start.S','firmware/main.c','-o',str(elf)])
        dis=run([PREFIX+'objdump','-d','-M','no-aliases',str(elf)])
        (out/f'{stem}.dis').write_text(dis)
        message=audit(dis)
        assert '<multiply_i8' in dis and '<software_dot' in dis, 'Benchmark routines absent'
        (out/f'{stem}.audit.txt').write_text(message+'\n'+run([PREFIX+'size',str(elf)]))
        print(stem+': '+message)
        emit_images(elf,stem)
    (out/'toolchain.txt').write_text(run([PREFIX+'gcc','--version']))

if __name__=='__main__': main()
