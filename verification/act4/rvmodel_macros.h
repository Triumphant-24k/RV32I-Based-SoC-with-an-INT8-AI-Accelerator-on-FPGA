#ifndef EDUCATIONAL_RV32I_RVMODEL_MACROS_H
#define EDUCATIONAL_RV32I_RVMODEL_MACROS_H
#define RVMODEL_DATA_SECTION
#define RVMODEL_BOOT_TO_MMODE
#define RVMODEL_HALT_PASS \
  li t0, 0x0000fff0; \
  li t1, 1;          \
  sw t1, 0(t0);      \
1: j 1b;
#define RVMODEL_HALT_FAIL \
  li t0, 0x0000fff0; \
  li t1, 2;          \
  sw t1, 0(t0);      \
1: j 1b;
#endif
