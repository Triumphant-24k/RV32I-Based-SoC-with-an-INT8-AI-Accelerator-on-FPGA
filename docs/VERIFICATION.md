# Verification summary — September 5, 2026

This is the original implementation snapshot. The September 6 baseline rerun and
Arty readiness results are recorded in [FPGA_READINESS.md](FPGA_READINESS.md).

## Baseline findings

The 30 imported files match source commit
`64977acc99bfd37eb6c43121e6377a9b47105b72`, allowing text CRLF normalization.
The imported CPU RTL and tests were not modified. Baseline tests ran before
accelerator implementation and passed: 46 unit checks; 176 directed checks across
63 instruction cases; zero-wait, fixed-delay, and randomized delay/backpressure
memory modes; 300 generated arithmetic tests with seed `0x52a1c0de`.
The 63 count is test cases, not 63 different supported opcodes. Baseline failures: none.

The CPU implements base RV32I, starts at PC 0 after asynchronous active-high reset,
and uses separate instruction/data valid/ready interfaces. Stores retire on
acceptance; reads accept immediate or delayed responses. Signed LB/LH, LW, byte
strobes, shifts, arithmetic and branch directions are exercised by original tests.
MUL and CSR encodings are outside the supported ISA. Firmware uses RV32I/ILP32,
bounded eight-step multiplication, and a new MMIO cycle counter. No replacement
CPU or CPU defect workaround was required.

## Executed checks

The complete command is `python3 scripts/regress.py`, or the documented PowerShell
wrapper. It completed with exit code 0. It fails fast on nonzero exit, missing PASS,
incorrect serial contents, timeouts, lint failures or unexpected synthesis structure.

| Check | Actual result / scope |
| --- | --- |
| CPU provenance and original baseline | PASS; counts above, also `reports/baseline.txt` |
| Firmware build | PASS; GCC 10.2.0, `-march=rv32i -mabi=ilp32 -O2 -nostdlib`, no relaxation or libc |
| Disassembly | PASS; 346 static demo instructions and 280 CPU-only instructions; no M/C/CSR instructions; LB/LW/SW and runtime software routines present |
| Accelerator | PASS; 266 vectors, 12,455 procedural checks plus clocked immediate assertions |
| UART | PASS; all 256 bytes, each clock of 8N1 framing, busy writes, reset abort |
| Bus | PASS; 61 checks of ROM/RAM, byte strobes, MMIO isolation, unsupported writes, holes, held requests, reset and counter wrap |
| Board preparation RTL | PASS; asynchronous reset assertion, synchronized/debounced release, LED toggling, decoded U characters |
| Real CPU integrated firmware | PASS; 26 operations, 337,242 total simulation clocks, 26 accepted starts, exact decoded UART/reference agreement |
| Real CPU integrated firmware with backpressure | PASS; 26 operations, 386,582 clocks, 26 starts, exact decoded UART/reference agreement |
| Real CPU CPU-only demonstration | PASS; 26 software cases, 216,078 clocks, zero accelerator starts |
| Verilator lint | PASS with fatal warnings on all three physical tops; only named unused signals/bits waived in `scripts/lint.vlt` |
| Yosys portable synthesis | PASS; process conversion, optimization, memory output-register merging, memory collection, `check -assert` |
| Synthesis structure audit | PASS; ROM and RAM each 4096x32, all read ports clocked; one signed 8x8 multiplier, 16-bit product; only intended top-level ports |

Total simulation clocks include startup and UART and are **not** the benchmark
regions. Benchmark deltas and measurement overhead are recorded separately in
`reports/BENCHMARKS.md` and raw serial logs. UART values are hexadecimal; benchmark
tables convert counters/results to decimal and signed two's complement.

## Required scenarios exercised

This table is a test traceability checklist, **not measured functional coverage**.

| Scenario | Evidence |
| --- | --- |
| Zero, positive, negative, cancellation, mixed signs | Python vectors 0–3 and 8–9, accelerator TB, CPU firmware |
| -128/127 extremes and exact upper/lower bounds | Vectors 4–6; results 131072 and -130048 |
| Last element only | Vector 7: result -16256; explicit post-reset repeat |
| Deterministic random vectors | 256 vectors seeded `0x20260907`; first 16 also executed by real CPU firmware |
| Consecutive operations without reset | 266 accelerator operations, 26 firmware operations in each integrated run |
| Start/input writes while busy, including final cycle | Accelerator TB drives attempted starts/A/B writes during all eight computation edges |
| Reset idle and during computation | Accelerator TB aborts at every age 0–7, verifies no later completion and restarts successfully |
| Done/result persistence | Immediate assertions plus procedural reads before, during and after operations |
| MMIO read/write, ignored strobes, alignment and holes | Accelerator and bus TB; CPU baseline covers misaligned load/store traps |
| No RAM alias / duplicate side effect under stalls | Bus TB holds start for five blocked cycles; integrated stalled CPU counts exactly 26 starts |
| Read latency / write acknowledgement | Original three memory modes plus synchronous ROM/RAM bus and CPU-driven tests |
| Stack and initialized data/BSS | Linker assertions, image-generator address checks, startup cookies, live stack monitor |
| UART timing / actual CPU reporting | Bit-level monitor reconstructs and checks 26 complete lines and final ALL PASS |

With `SIM_ASSERT`, Icarus executed immediate SystemVerilog assertions in the
accelerator for mutually exclusive busy/done, accepted-start state, exact index
progression, no early completion, completion after eight cycles, sticky done,
stable result until replacement, and reset abort. Procedural tests independently
check arithmetic and bounds. These are simulation assertions; no formal proof or
coverage percentage is claimed. The original CPU's FORMAL-only assertions and
SymbiYosys harness were preserved but were not executed by this regression.

## Issues found and resolved during implementation

- Icarus rejected the CPU-only testbench's ternary expression joining unequal-length
  filename strings. Explicit per-run filename parameters fixed ROM/RAM initialization.
- Initial lint flagged width comparisons on filename parameters and expected unused
  fields. Width comparisons were corrected; narrowly scoped unused-field waivers
  document the deliberate unused ports/decoder bits, including two upstream fields.
- Yosys 0.9 did not support sized casts used in parameterized reload constants.
  Portable explicit constant slices replaced them. A hierarchical busy reference
  was also replaced with an explicit module port for portable synthesis.
- The synthesis result reader was adapted for integer parameters emitted by old
  Yosys and binary strings emitted by newer versions.

All these were confined to newly added code or tools, and the final regression
passes. No unresolved failure is known in the tested configuration.

## Limits and work remaining

- No exact board, FPGA part, confirmed clock, pin map, bank voltage or PS/PL route.
  Board templates intentionally reject an unconfigured target.
- Vivado was not available on PATH; vendor Tcl is a preparation template, not a
  vendor-validated run. There is no placed/routed netlist, timing closure, utilization
  percentage, power result, bitstream, or physical-board evidence.
- Yosys retained synchronous memory cells; this is evidence of block-RAM-compatible
  coding, not a measured target mapping. It intentionally implements CPU register
  file and tiny accelerator vector buffers as registers (three documented warnings).
- Icarus, Verilator and Yosys were used. A native ModelSim installation was detected
  but not required or used. No software licence was bypassed.
- Full architectural certification (ACT4/Sail) and unbounded formal proofs were
  not run. The imported ACT4 script itself reports that a DUT execution adapter
  remains required; SymbiYosys and Sail were not available on the tested Linux PATH.
- Firmware uses a fixed ROM image and terminal output only; there is no host input
  protocol. Persistent PASS remains until reset or an explicit firmware status write.
- The benchmark is specific to this short dot product and selected software
  implementation. Competition reuse permission remains unconfirmed.
- GitHub CLI is unauthenticated and no repository-create connector was available.
  The new local history is ready; README includes the private-new-repository upload
  command. No original repository, branch, remote, or access setting was modified.

After allocation, follow `docs/BRINGUP.md`: configure physical interfaces, perform
vendor synthesis/place/route and timing/DRC review, then demonstrate CPU-only and
integrated firmware on the actual board before claiming FPGA validation.
