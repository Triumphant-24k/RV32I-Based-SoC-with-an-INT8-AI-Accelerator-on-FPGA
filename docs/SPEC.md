# Interface specification (written before accelerator implementation)

## Arithmetic and state

Eight signed two's-complement bytes per vector. One signed 8x8 multiplier produces
a signed 16-bit product per clock, explicitly sign-extended into a signed 32-bit
accumulator. A product is in [-16256, 16384]; a sum is in [-130048, 131072].
No saturation, rounding, or overflow occurs for legal inputs. The completion
assignment must use accumulator + product so that element 7 is included.

IDLE and RUN FSM. A start accepted in IDLE clears sticky done, clears the working
accumulator and cycle count, sets busy and index 0. Each of the NEXT eight rising
edges accumulates one product. On edge 8 the result and done are set, busy is cleared,
and the cycle count is 8. Start and input writes sampled while busy are ignored,
including on the last computing edge. A completed result remains readable through
the next computation until replaced on completion. Done persists until accepted
start or reset. Reset aborts computation and clears vectors, busy, done, result,
index, accumulator, and accelerator cycle count. All logic uses one clock.

## Address map

The original CPU imposes no peripheral addresses; its simulation-only memories
are at zero. This SoC explicitly allocates the following disjoint regions:

| Address | Meaning |
| --- | --- |
| 0x00000000–0x00003fff | 16 KiB instruction ROM; also data-readable for constants |
| 0x00010000–0x00013fff | 16 KiB data RAM; initialized data, BSS, stack |
| 0x40000000 | Accelerator control: write bit 0 = start; reads zero |
| 0x40000004 | Status: bit 0 busy, bit 1 sticky done |
| 0x40000008 | Signed INT32 completed result, read-only |
| 0x4000000c | Accelerator compute cycles, read-only |
| 0x40000020–0x4000003c | A[0..7], one entry per four bytes |
| 0x40000040–0x4000005c | B[0..7], one entry per four bytes |
| 0x40000100 | SoC free-running 32-bit cycle counter, read-only |
| 0x40000104 | UART TX data, write low byte (word store) |
| 0x40000108 | UART status bit 0 busy, read-only |
| 0x4000010c | Persistent demo status: 1 pass, 2 fail; reset 0 |

RAM supports CPU byte enables and aligned byte/halfword/word ISA accesses.
Peripheral writes require aligned address and wstrb=1111; all other writes are
acknowledged but ignored. Input writes take bits [7:0]; readback sign-extends to 32
bits. Reads return the containing aligned register word: the CPU interface conveys
no read size, so the LSU performs byte/halfword selection and sign extension.
Unmapped reads return zero and writes are ignored. ROM writes are ignored.
Misaligned halfword/word instructions trap inside the CPU before reaching the bus.
Reserved bits read zero. Status/result/counter writes do nothing. UART writes while
busy are ignored; firmware polls first. Reset clears status and counters, but does
not clear ROM/RAM at runtime (firmware startup reinitializes BSS).

## Transactions and memory timing

Side effects occur exactly on request-valid AND request-ready. A request held
while ready=0 has no side effects; holding valid beyond an acceptance denotes a
new transaction under this convention. The CPU deasserts requests after acceptance.
Writes are complete at acceptance; there is no write response to wait for. Reads
return one registered response after acceptance. Instruction and data RAM/ROM use
synchronous reads, with no asynchronous runtime memory reset, suitable for block
RAM inference. A configurable test backpressure mode stalls request acceptance.
MMIO decoding is disjoint from RAM write enables; no peripheral write aliases RAM.

The FPGA top exposes only clock, external reset, UART TX, and status LEDs. Board
clock, part, pins, voltages, and reset polarity remain allocation-time decisions.

The paragraph above describes the original generic `fpga_top`. The separate Arty
shell now uses `clk`, active-high BTN0 `reset_btn`, `uart_rx`, `uart_tx`, and
four LEDs. RX is synchronized for a smoke-mode activity indicator only. Integrated
LED1 displays reset or accelerator activity stretched to 50 ms. This does not alter
the peripheral map or add a firmware input protocol. Arty settings and official
constraint sources are documented in `docs/ARTY_BRINGUP.md`.
