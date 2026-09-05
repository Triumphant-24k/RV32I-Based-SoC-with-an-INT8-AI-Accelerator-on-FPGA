RAM_ORIGIN = 0x00000000;
RAM_LENGTH = 0x00010000;
TEST_BASE = 0x00000000;
NUM_HARTS = 1;
STACK_SIZE = 0x1000;
OUTPUT_ARCH("riscv")
ENTRY(rvtest_entry_point)
MEMORY { ram (rwx) : ORIGIN = RAM_ORIGIN, LENGTH = RAM_LENGTH }
PROVIDE(__stack_size = STACK_SIZE);
PROVIDE(__num_harts = NUM_HARTS);
SECTIONS {
  .text.init TEST_BASE : { *(.text.init) } > ram
  .text.rvtest . : { *(.text.rvtest) *(.text.rvtest.*) } > ram
  . = ALIGN(16);
  .rodata . : { *(.rodata) *(.rodata.*) *(.srodata) *(.srodata.*) } > ram
  .data . : { *(.data) *(.data.*) *(.sdata) *(.sdata.*) } > ram
  .bss . : { __bss_start = .; *(.sbss*) *(.bss*) *(COMMON); __bss_end = .; } > ram
  . = ALIGN(16); __stack_bottom = .; . += STACK_SIZE; __stack_top = .;
  .text.rvmodel . : { *(.text.rvmodel) *(.text.rvmodel.*) *(.text) *(.text.*) } > ram
  _end = .;
  ASSERT(_end <= ORIGIN(ram) + LENGTH(ram), "ACT image exceeds simulation RAM")
}
