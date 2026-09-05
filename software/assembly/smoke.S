/* Small hand-written smoke program. The directed SystemVerilog regression is
 * substantially more comprehensive. This source is provided for toolchain use. */
.section .text
.globl _start
_start:
    addi x1, x0, 10
    addi x2, x0, 20
    add  x3, x1, x2
    lui  x4, 0x12345
    sw   x3, 0(x0)
    lw   x5, 0(x0)
    bne  x3, x5, fail
    ecall
fail:
    ebreak
