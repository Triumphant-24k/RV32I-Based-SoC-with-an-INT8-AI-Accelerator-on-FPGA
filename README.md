# RV32I SoC with an INT8 AI Accelerator

This project builds on my earlier RV32I processor by adding a small accelerator for signed INT8 dot products. I wanted to put the full path together: the CPU runs a program, passes data to the accelerator, reads the answer, and compares it with a software result.

The project is being developed for the September 7–8, 2026 Design & Verification hackathon. The complete system has passed simulation with the actual CPU executing firmware. FPGA testing is the next stage, once the board is allocated.

## What it does

The accelerator calculates an eight-element dot product:

```text
result = A[0] × B[0] + A[1] × B[1] + ... + A[7] × B[7]
```

Each input is a signed 8-bit integer, and the result is accumulated in 32 bits. Dot products are a basic operation in neural networks, so this gives the project a small, concrete AI computation kernel to work with.

The firmware loads the vectors through memory-mapped registers, starts the calculation, and polls for completion. It then prints the software result, hardware result, cycle counts, and PASS/FAIL over UART. Operations can run back to back without resetting the system.

## Design

I kept the accelerator small: one reusable signed multiplier, an accumulator, two input buffers, and a simple control FSM. It processes one pair of values per clock and finishes in eight compute cycles.

The CPU uses ordinary loads and stores to access it. Since the core implements RV32I without a multiply instruction, the software comparison uses an eight-step shift-and-add routine. A separate SoC counter measures elapsed cycles.

The system also includes synchronous instruction ROM and data RAM, a UART transmitter, reset conditioning, and persistent PASS/FAIL LEDs. All functional logic runs in one clock domain.

## Verification

The existing CPU tests pass with the CPU RTL unchanged. The added verification covers:

- 266 accelerator vectors, including zeros, mixed signs, INT8 limits, cancellation, and a case where only the last element contributes.
- Consecutive operations, writes while busy, reset during computation, and result persistence.
- Memory-mapped accesses, byte enables, memory isolation, and stalled requests.
- UART framing and all 256 possible transmitted byte values.
- 26 firmware cases executed by the real CPU, both with and without request backpressure. The decoded UART results match an independent Python reference.

Verilator lint and portable Yosys synthesis checks also pass. Yosys retains clocked ROM/RAM structures and one signed 8×8 multiplier. Physical FPGA mapping and timing are still pending.

## Simulation results

For the 26 firmware cases with no request backpressure:

| Measurement | Cycles |
| --- | ---: |
| Software dot product | 1,870–2,062 |
| Accelerator computation | 8 |
| Full accelerated operation, including MMIO transfers and polling | 385 |

Across these cases, the ratio of total software cycles to total accelerated cycles is **5.09× end to end**. The compute-only ratio is **245.06×**, excluding data transfers. Both figures compare against this project's shift-and-add software implementation. UART printing is outside the timed regions.

The [benchmark report](reports/BENCHMARKS.md) contains the individual measurements, counter-read overhead, and results with backpressure.

## CPU base

The CPU comes from my [riscv-r32-processor-v2](https://github.com/Triumphant-24k/riscv-r32-processor-v2) repository at commit `64977acc99bfd37eb6c43121e6377a9b47105b72`.

I reused the CPU datapath and control RTL, simulation memory and wrapper, existing CPU tests, smoke-program support, and formal/architectural-test configuration. The accelerator, SoC integration, demo firmware, UART, board wrappers, and additional verification are part of this project. The original CPU repository remains separate.

The reused code retains its MIT licence and copyright notice. Original versions of the two updated test READMEs are preserved alongside the provenance records.

## Project documentation

- [Architecture and block diagram](docs/ARCHITECTURE.md)
- [Register map and arithmetic specification](docs/SPEC.md)
- [Verification results](docs/VERIFICATION.md)
- [Development notes](docs/DEVELOPMENT.md)
- [FPGA bring-up notes](docs/BRINGUP.md)

MIT License · Copyright © 2026 Shiv Sriram
