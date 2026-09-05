OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 16K
    RAM (rw) : ORIGIN = 0x00010000, LENGTH = 16K
}
SECTIONS {
    .text : { KEEP(*(.text.start)) *(.text .text.*) } > ROM
    .rodata : { *(.rodata .rodata.*) . = ALIGN(4); } > ROM
    .data : {
        . = ALIGN(4); _data_start = .;
        *(.data .data.* .sdata .sdata.*)
        . = ALIGN(4); _data_end = .;
    } > RAM AT> ROM
    _data_load = LOADADDR(.data);
    .bss (NOLOAD) : {
        . = ALIGN(4); _bss_start = .;
        *(.bss .bss.* .sbss .sbss.*) *(COMMON)
        . = ALIGN(4); _bss_end = .;
    } > RAM
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ASSERT(_bss_end <= _stack_top - 4096, "RAM overlaps reserved 4 KiB stack")
    ASSERT(LOADADDR(.data) + SIZEOF(.data) <= ORIGIN(ROM)+LENGTH(ROM), "ROM overflow")
    /DISCARD/ : { *(.comment) *(.eh_frame*) }
}
