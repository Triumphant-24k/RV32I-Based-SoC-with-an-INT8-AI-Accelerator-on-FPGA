# Short demonstration script

1. State the scope: "Our reused RV32I CPU controls a newly added signed INT8
   dot-product accelerator through ordinary memory-mapped loads and stores. This
   accelerates an AI computation kernel; it is not a trained classifier."
2. Show README CPU URL/commit attribution, the architecture diagram, and the
   control/status/result register map. Identify one reusable MAC and eight inputs.
3. Run the documented full regression. Show CPU-driven UART lines for zero,
   maximum-positive, maximum-negative and last-element-only cases, then ALL PASS.
   Explain that the monitor reconstructs serial bits and independently checks them.
4. Show reports/BENCHMARKS.md. Distinguish the eight hardware computation cycles
   from MMIO input transfers/polling/result-read overhead. State that results measure
   this CPU and software shift/add implementation in simulation.
5. On an allocated, validated board, repeat the demo over UART and show the sticky
   PASS LED. Before that, say "simulation-verified, awaiting FPGA allocation".
6. Show reset-during-compute, busy-write, random-vector and delayed-memory tests.
   Close with actual limitations and the remaining board validation steps.

Suggested three-person split:

| Person | Primary responsibility | Evidence to bring |
| --- | --- | --- |
| 1 | CPU reuse, firmware, linker/ISA audit, UART and benchmark definitions | Disassembly, CPU-driven serial logs, cycle tables |
| 2 | Accelerator RTL, MMIO semantics, arithmetic/reference tests | Register specification, edge cases, assertions, random seed |
| 3 | Integration, reset/clock/constraints, synthesis and hardware bring-up | Full regression, confirmed board docs, vendor timing/DRC reports |

All three should be able to explain final-cycle accumulation, why RV32I needs
software multiplication, and why compute-only and end-to-end speedup differ.
