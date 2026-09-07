# RV32I SoC with an INT8 AI Accelerator

This project builds on my earlier RV32I processor by adding a small accelerator for signed INT8 dot products. I wanted to put the full path together: the CPU runs a program, passes data to the accelerator, reads the answer, and compares it with a software result.

The project is being developed for the September 7–8, 2026 Design & Verification hackathon. The complete system has passed simulation with the actual CPU executing firmware. The primary hardware target is the Digilent Arty A7-100T. Physical FPGA testing is still pending.

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

## FPGA target

The Arty A7-100T version uses the onboard 100 MHz clock, USB-UART at 115200 baud, and four LEDs for heartbeat, reset/accelerator activity, PASS, and FAIL. BTN0 provides active-high reset. A separate board wrapper handles the pins and reset conditioning, so the CPU and accelerator stay portable.

The board firmware adds a boot message, decimal results, and speedup calculated from the measured cycle counts. Separate LED and UART smoke-test modes support the first stages of bring-up. An unidentified Artix-7 board is listed as a possible backup, with its pinout and device details still pending.

The Vivado flow and official-source Arty constraints are prepared. Vivado implementation and a programmed-board demonstration have not yet been completed.

## Arty A7-100T Hardware Setup

The target is the **Digilent Arty A7-100T, xc7a100tcsg324-1**. Connect a data-capable USB-A-to-micro-B cable to the board's USB-JTAG/UART port. Vivado needs 7-series device support and the cable drivers; the firmware helper uses the existing Ubuntu-22.04 WSL RISC-V toolchain.

From this repository in a Vivado-enabled PowerShell session:

```powershell
.\scripts\run-regression.ps1
.\scripts\build-arty.ps1 -Demo integrated
```

The build rebuilds firmware, runs implementation and checks timing/DRC before requesting `build/vivado/arty_a7_100t/integrated/arty_a7_top.bit`. Open **Vivado Hardware Manager → Open Target → Auto Connect**, confirm the connected XC7A100T board, and use **Program Device** with that bitstream. Programming is a separate manual step; the build never connects to hardware. The [bring-up guide](docs/ARTY_BRINGUP.md) also covers LED, UART and CPU-only smoke builds and the optional manual programming script.

Use [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/) or [Tera Term](https://teratermproject.github.io/) at **115200 baud, 8-N-1, no flow control**. In Windows Device Manager, expand **Ports (COM & LPT)** and compare the list before and after plugging in the board to find its USB serial COM port. Open that port before pressing **BTN0**. One complete 26-case report prints after startup or reset; it does not loop continuously.

| LED | Integrated demo meaning |
| --- | --- |
| LED0 | Heartbeat, toggling every half second |
| LED1 | Reset active, or accelerator busy/activity held visible for 50 ms |
| LED2 | All comparisons passed; stays on until reset |
| LED3 | Comparison failure or CPU trap |

BTN0 is D9, low at rest and high when pressed. Holding it resets the CPU and UART; release is synchronized and delayed by 10 ms. Configuration also starts that reset sequence automatically. The red reset button is not the demo reset input. UART directions are **FPGA RX = D10, FPGA TX = A9**, following the [official Digilent master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Arty-A7-100-Master.xdc); the bridge's signal names use the opposite perspective.

Example from simulation, with measured counters rather than fixed performance text:

```text
RV32I SoC Booted
COUNTER_READ_DELTA=00000005
Test: 0
CPU result: 0
Accelerator result: 0
CPU cycles: 1870
Accelerator cycles: 8
End-to-end cycles: 388
Speedup: 4.81x
Compute-only speedup: 233.75x
TEST PASSED
```

The remaining cases include positive, negative and INT8-limit inputs; the final line is `ALL PASS`. This is an INT8 dot-product accelerator for quantized-AI compute kernels, not a complete neural-network processor.

For **no UART output**, check heartbeat, USB data cable, 115200/8-N-1/no-flow settings, then press BTN0 with the terminal open; the standalone `-Demo uart` image isolates the serial path. For an **incorrect or busy COM port**, identify the newly connected USB serial device and close other programs using it. For **failed timing**, inspect `timing_summary.txt`, `check_timing.txt` and `drc.txt` in the demo build folder; do not treat an older bitstream as a successful new build. For **missing initialization**, rerun the build helper: it generates and validates the board images, then stages `rom.hex` and `ram.hex` beside the Vivado run.

## Directory structure

The CPU, SoC peripherals and board support are kept in separate folders. The program counter is part of `cpu_core.v`; the processor's 16 KiB instruction ROM and 16 KiB data RAM are inside `soc_bus.sv`.

```text
riscv-int8-ai-accelerator/
├── rtl/                          # Verilog CPU and SystemVerilog SoC hardware
│   ├── cpu_core.v                # RV32I core, program counter, execution FSM and traps
│   ├── control_unit.v            # Instruction decoder and datapath control signals
│   ├── register_file.v           # 32 x 32-bit CPU registers; x0 always reads zero
│   ├── alu.v                     # Integer arithmetic, logic, comparisons and shifts
│   ├── immediate_generator.v     # I/S/B/U/J immediate extraction and sign extension
│   ├── branch_unit.v             # Signed/unsigned branch comparisons
│   ├── load_store_unit.v         # Load extension, store byte enables and alignment
│   ├── cpu_sim_top.v             # Original CPU simulation wrapper
│   ├── simulation_memory.v       # Simulation-only memory with delays/backpressure
│   ├── soc/                      # Board-independent system and peripherals
│   │   ├── ai_soc.sv             # Connects the real CPU to the bus and peripherals
│   │   ├── soc_bus.sv            # 16 KiB ROM, 16 KiB RAM, MMIO decoder and counters
│   │   ├── int8_accelerator.sv    # Signed 8x8 multiply, INT32 accumulator and control
│   │   └── uart_tx.sv            # UART transmitter with 8N1 framing and busy flag
│   └── board/                    # Generic FPGA wrappers and standalone diagnostics
│       ├── fpga_top.sv           # Generic SoC top with UART and status LEDs
│       ├── reset_conditioner.sv  # Async reset assertion and stable synchronized release
│       ├── led_test_top.sv       # Standalone heartbeat/reset test
│       ├── uart_test_top.sv      # Standalone repeated ASCII U transmitter
│       └── uart_hello.sv         # Repeated Hello greeting for the Arty UART test
├── boards/                       # Arty wrapper, verified XDC and Vivado build flow
├── firmware/                     # C demo, startup assembly, linker and memory images
├── tb/                           # Self-checking CPU, accelerator, bus and board tests
├── scripts/                      # Regression, firmware, lint and synthesis helpers
├── software/                     # Preserved assembly smoke program from the CPU project
├── verification/                 # Reference vectors, CPU provenance and ACT4 setup
├── formal/                       # Inherited proof/equivalence setup; not a completed proof
├── reports/                      # Simulation measurements and selected test evidence
├── docs/                         # Architecture, register map, verification and bring-up
├── outputs/                      # Local Word audit report
├── build/                        # Generated simulations, firmware and synthesis outputs
├── work/                         # Local CPU import archive; excluded from Git
├── Makefile                      # Linux test, firmware and lint/synthesis entry points
├── LICENSE                       # MIT licence and copyright notice
└── README.md                     # Project overview
```

The accelerator operates on two vectors of eight signed INT8 values. Its input buffers, multiplier, accumulator and state control are all in one module, mapped at `0x40000000`.

The [complete directory guide](docs/DIRECTORY_STRUCTURE.md) expands every source folder and explains each file, including firmware, testbenches, scripts and reports. Generated build files are summarized by purpose.

## Project documentation

- [Architecture and block diagram](docs/ARCHITECTURE.md)
- [Complete directory and file guide](docs/DIRECTORY_STRUCTURE.md)
- [Register map and arithmetic specification](docs/SPEC.md)
- [Verification results](docs/VERIFICATION.md)
- [Development notes](docs/DEVELOPMENT.md)
- [FPGA bring-up notes](docs/BRINGUP.md)
- [Arty A7-100T build and demonstration](docs/ARTY_BRINGUP.md)

MIT License · Copyright © 2026 Shiv Sriram
