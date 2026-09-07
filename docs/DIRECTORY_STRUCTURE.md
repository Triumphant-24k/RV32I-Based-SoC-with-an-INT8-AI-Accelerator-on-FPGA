# Directory structure

This is the layout of my RV32I SoC and INT8 accelerator project. Each comment describes the file's role. `riscv-int8-ai-accelerator/` below is the project name; the local checkout folder is named `RV32I-Based SoC with an INT8 AI Accelerator on FPGA`.

## Hardware

The processor's program counter and execution controller are inside `cpu_core.v`. Its instruction ROM and data RAM are inside `soc_bus.sv`, with **16 KiB each**. The accelerator uses **one signed 8x8 multiplier and a 32-bit accumulator**; its datapath, buffers and controller are together in `int8_accelerator.sv` at base address **`0x40000000`**.

```text
riscv-int8-ai-accelerator/
├── rtl/                              # CPU RTL, SoC hardware and generic board support
│   ├── alu.v                         # 32-bit add/subtract, logic, comparisons and shifts
│   ├── branch_unit.v                 # BEQ/BNE and signed/unsigned ordering decisions
│   ├── control_unit.v                # Opcode/funct decoder; enables, selects and trap flags
│   ├── cpu_core.v                    # RV32I core, PC, fetch/execute/memory FSM and traps
│   ├── cpu_sim_top.v                 # CPU plus simulation_memory; not the FPGA SoC top
│   ├── immediate_generator.v         # Reassembles and sign-extends I/S/B/U/J immediates
│   ├── load_store_unit.v             # Byte lanes, load extension, strobes and misalignment
│   ├── register_file.v               # 32 x 32-bit architectural registers, including x0
│   ├── simulation_memory.v           # Test memory with zero/fixed/random waits and stalls
│   ├── soc/                          # Board-independent CPU system and peripherals
│   │   ├── ai_soc.sv                 # Wires CPU to soc_bus; exposes UART and status
│   │   ├── soc_bus.sv                # 16 KiB ROM + 16 KiB RAM, decoding, counter and status
│   │   ├── int8_accelerator.sv        # Eight-element INT8 dot product, MMIO and busy/done FSM
│   │   └── uart_tx.sv                # Clock-divided UART TX, 8N1 framing; no receive engine
│   └── board/                        # Portable wrappers and isolated board diagnostics
│       ├── fpga_top.sv               # Generic SoC wrapper with active-high external reset
│       ├── led_test_top.sv           # Standalone heartbeat and reset diagnostic
│       ├── reset_conditioner.sv      # Async assertion; synchronized/debounced reset release
│       ├── uart_hello.sv             # Standalone Hello plus CR/LF greeting controller
│       └── uart_test_top.sv          # Repeated ASCII U for UART waveform inspection
└── boards/                           # Physical targets and vendor build settings
    ├── board.template.tcl            # Unfilled settings for a future generic board
    ├── pins.template.xdc             # Unconfigured pin template; intentionally stops builds
    ├── arty_a7_100t/                 # Primary target: Arty A7-100T, 100 MHz onboard clock
    │   ├── arty_a7_top.sv            # Physical top: active-high BTN0, UART and four LEDs
    │   ├── arty_a7_100t.xdc          # Digilent-source pin assignments and 10 ns clock
    │   └── build.tcl                 # Guarded Vivado synthesis/place/route/bitstream flow
    └── xilinx_artix7_unknown/        # Backup board pending exact identification
        └── BOARD_INFO.md            # Required model, part, clock, pin and voltage details
```

`cpu_sim_top.v` and `simulation_memory.v` support CPU simulation. The integrated FPGA hierarchy instead follows `arty_a7_top → ai_soc → cpu_core + soc_bus`. The RAM array used by the CPU is part of `soc_bus`; the accelerator's two eight-byte input buffers are separate from that RAM.

## Firmware and inherited software

The active accelerator demonstration is in `firmware/`. The small program under `software/` belongs to the original CPU project and uses a different simulation-memory arrangement.

```text
riscv-int8-ai-accelerator/
├── firmware/                         # Freestanding RV32I/ILP32 SoC demonstration
│   ├── main.c                        # Software/hardware comparison, counters and UART output
│   ├── start.S                       # Reset entry, stack setup, data copy, BSS clear and main
│   ├── link.ld                       # ROM at 0; RAM at 0x10000; reserved 4 KiB stack
│   ├── vectors.h                     # Generated C inputs and expected results for 26 cases
│   └── hex/                          # Tracked baseline images, each 4096 x 32-bit words
│       ├── demo_rom.hex              # Integrated accelerator program and constants
│       ├── demo_ram.hex              # Initial RAM contents for the integrated demo
│       ├── cpu_rom.hex               # CPU-only program and constants
│       └── cpu_ram.hex               # Initial RAM contents for the CPU-only demo
└── software/                         # Original CPU smoke-program support
    ├── assembly/
    │   └── smoke.S                   # Arithmetic, store/load and branch check; then trap
    └── hex/
        └── smoke.hex                 # Preserved word-oriented image checked by provenance
```

The same `main.c` produces four variants: `demo`, `cpu`, `board` and `board_cpu`. `CPU_ONLY` omits accelerator accesses; `BOARD_REPORT` adds readable decimal output. Board images are generated under `build/firmware/`. The processor has no MUL or DIV instruction, so multiplication and decimal division in firmware use RV32I-compatible software routines.

## Testbenches and reference data

```text
riscv-int8-ai-accelerator/
├── tb/                               # Simulation-only, self-checking testbenches
│   ├── unit/
│   │   └── unit_tb.sv                # 46 direct datapath/decoder checks
│   ├── core/
│   │   ├── core_tb.sv                # 176 checks over 63 directed instruction cases
│   │   ├── generated_tb.sv           # 300 deterministic arithmetic differential tests
│   │   └── memory_wait_tb.sv         # Zero-wait, fixed-delay and random/backpressure modes
│   ├── soc/
│   │   ├── accelerator_tb.sv         # 266 vectors; arithmetic, busy writes, reset and MMIO
│   │   ├── bus_tb.sv                 # 61 checks of memory, strobes, isolation and stalls
│   │   ├── soc_tb.sv                 # Real CPU firmware in normal, stalled and CPU-only modes
│   │   ├── uart_tb.sv                # All 256 bytes, exact framing, busy behavior and reset
│   │   ├── uart_monitor.sv           # Bit-level UART decoder shared by system tests
│   │   ├── board_tb.sv               # Generic reset, heartbeat and UART U smoke tests
│   │   ├── arty_smoke_tb.sv          # Arty LED/reset/RX activity and Hello at production baud
│   │   └── arty_tb.sv                # Arty wrapper, real CPU, startup/reset and decimal UART
│   └── programs/
│       └── README.md                 # Explains where CPU smoke software and system tests live
├── verification/                     # Provenance, independent vectors and external-test setup
│   ├── cpu-provenance.json           # Original CPU commit and 30 imported Git blob identifiers
│   ├── vectors/
│   │   ├── cases.json                # 266 signed inputs/results with case names and seed
│   │   └── cases.hex                 # HDL-readable vectors: 17 words per accelerator case
│   ├── upstream-docs/
│   │   ├── architectural-tests.txt   # Preserved original architectural-test README
│   │   └── test-programs.txt         # Preserved original CPU program README
│   └── act4/                         # Architectural-test preparation; certification pending
│       ├── README.md                 # Scope, missing DUT adapter and memory-map differences
│       ├── PINNED_REVISION           # Exact upstream test commit and intended Sail version
│       ├── educational-rv32i.yaml    # Base RV32I target description for ACT4/UDB
│       ├── test_config.yaml          # Compiler, reference model, linker and include settings
│       ├── link.ld                   # Separate architectural-test simulation-memory layout
│       └── rvmodel_macros.h          # Test pass/fail markers at simulation address 0x0000fff0
└── formal/                           # Inherited formal setup; no completed proof claimed
    ├── cpu_properties.sv             # CPU harness and assumptions; reset sequence needs review
    ├── cpu_properties.sby            # SymbiYosys prove configuration using ABC PDR
    └── equivalence.ys                # CPU optimization-equivalence script; tool compatibility pending
```

The simulation regression is separate from ACT4 certification and formal proof. The audit found that the installed Yosys rejects an option in the inherited equivalence script, and the formal reset harness needs correction before meaningful proof results can be claimed.

## Build and verification scripts

```text
riscv-int8-ai-accelerator/
├── scripts/
│   ├── regress.py                   # Full fail-fast regression and independent UART checks
│   ├── run-regression.ps1           # Windows entry point using the existing WSL toolchain
│   ├── baseline.py                  # Compiles/runs the four original CPU suites in Icarus
│   ├── reference.py                 # Independent Python dot product and seeded vector generator
│   ├── build_firmware.py            # Builds four ELFs, audits RV32I and packs ROM/RAM words
│   ├── validate_images.py           # Rejects malformed images and empty program contents
│   ├── check_reuse.py               # Verifies the 30 imported contents against recorded blobs
│   ├── check_rtl.py                 # Fatal lint, memory/multiplier checks and optional xc7 mapping
│   ├── check_fpga.py                # Arty simulations, XDC agreement, image and Tcl guard checks
│   ├── lint.vlt                     # Narrow waivers for explicitly unused fields/signals
│   ├── handoff.py                   # Refreshes small evidence reports from successful test outputs
│   ├── build-arty.ps1               # Windows Vivado launcher for LED/UART/CPU/integrated demos
│   ├── program-arty.tcl             # Manual JTAG programming; no hardware access by default
│   ├── vivado_prepare.tcl           # Older generic-board synthesis/checkpoint preparation
│   ├── build-programs.sh            # Inherited smoke builder; output byte-order issue documented
│   ├── run-questa.ps1               # Original ModelSim/Questa CPU suite launcher; recreates work/
│   ├── run-act4.sh                  # Checks dependencies and prepares pinned architectural tests
│   └── run-act4.ps1                 # Windows-to-WSL adapter for the ACT4 launcher
└── Makefile                          # Linux targets for regression, baseline, firmware and lint
```

The working SoC image flow is `build_firmware.py`. The optional inherited `build-programs.sh` produced byte-swapped words with the audited toolchain, so its regenerated smoke image should not replace the preserved image without a conversion fix. `run-questa.ps1` recreates `work/`; the audit instead used an isolated library under `build/` to preserve the existing import archive.

## Documentation and saved evidence

```text
riscv-int8-ai-accelerator/
├── docs/
│   ├── DIRECTORY_STRUCTURE.md        # This annotated folder and file guide
│   ├── ARCHITECTURE.md               # System diagram and CPU/bus/memory relationships
│   ├── SPEC.md                       # Arithmetic, register map, transaction and reset contract
│   ├── DEVELOPMENT.md                # Toolchain, regression commands and reproducibility notes
│   ├── DEMO.md                       # Presentation outline and benchmark explanation
│   ├── BRINGUP.md                    # Generic board guide with a pointer to the Arty target
│   ├── ARTY_BRINGUP.md               # Arty pins, build flow, UART/LED settings and bench sequence
│   ├── ARTY_HARDWARE_READINESS.md     # BTN0/busy LED changes and current board-flow verification
│   ├── VERIFICATION.md               # Original dated CPU/SoC verification snapshot
│   └── FPGA_READINESS.md             # Dated Arty readiness results and pending hardware work
├── reports/                          # Selected small evidence files retained in the repository
│   ├── regression.txt                # PASS summaries and audits from the full regression
│   ├── baseline.txt                  # Retained original CPU baseline evidence
│   ├── BENCHMARKS.md                 # Readable per-case and aggregate simulation measurements
│   ├── benchmarks.json               # Structured normal/stalled/CPU-only baseline measurements
│   ├── soc_uart.txt                  # Complete original integrated UART capture
│   ├── soc_stalls_uart.txt           # Integrated UART capture with request backpressure
│   ├── cpu_only_uart.txt             # Original CPU-only UART results
│   ├── demo.audit.txt                # Baseline integrated firmware ISA audit and sizes
│   ├── demo.dis                      # Disassembled baseline integrated firmware
│   ├── cpu.audit.txt                 # Baseline CPU-only firmware ISA audit and sizes
│   ├── cpu.dis                       # Disassembled baseline CPU-only firmware
│   ├── synthesis_summary.json        # Generic-top clocked memories and signed multiplier evidence
│   ├── arty_synthesis_summary.json   # Arty-top coarse memory/multiplier synthesis evidence
│   ├── arty_mapping_summary.json     # Yosys xc7 primitive counts; not Vivado utilization
│   ├── arty_benchmarks.json          # Board firmware results and measured cycle deltas
│   ├── arty_uart_sample.txt          # Boot and first two decoded board-demo result blocks
│   ├── tools.txt                     # Simulator, lint, synthesis, compiler and Python versions
│   └── toolchain.txt                 # Full firmware compiler version output
├── outputs/                          # Local document deliverables
│   └── RV32I_Repository_Audit_and_File_Guide.docx
│                                     # Detailed audit and RTL walkthrough; snapshot before this guide
├── .gitattributes                    # Git text normalization and LF endings for shell scripts
├── .gitignore                        # Excludes generated builds, caches, waveforms and tool logs
├── LICENSE                           # MIT licence and copyright notice
└── README.md                         # Project introduction, design, results and documentation links
```

The older documents are dated snapshots. The Word audit adds the later ModelSim cross-check and optional-tool findings. Neither the reports nor the prepared Vivado scripts establish that a physical FPGA has been programmed and tested.

## Local generated folders

These contents change as tools run. Individual executables, caches and large netlists are summarized here rather than treated as source modules.

```text
riscv-int8-ai-accelerator/
├── build/                            # Ignored generated outputs
│   ├── baseline/                     # Compiled original CPU testbenches and their results
│   ├── firmware/                     # Four ELF variants, maps, disassembly and board ROM/RAM images
│   ├── programs/                     # Optional smoke build and retained diagnostic image
│   ├── fpga-baseline/                # Saved evidence from before the Arty additions
│   ├── questa_audit/                 # Isolated compiled ModelSim CPU library
│   ├── tcl-contract/                 # Mock timing text for build-guard tests; not vendor reports
│   ├── vivado/                       # Target output location for actual Vivado runs
│   ├── repo-report/                  # Word report builder, inventory and page-render checks
│   └── ...                           # Simulation executables, UART logs and Yosys scripts/netlists
├── scripts/__pycache__/              # Generated Python bytecode caches
├── work/                             # Ignored local setup material
│   └── cpu-import.tar                # Retained CPU import archive
└── .git/                             # Git history, index, refs and configuration
```

The presence of a build folder does not imply its contents are successful or current. In particular, Tcl contract-test files are intentionally mocked, and the Vivado destination is not evidence of a completed vendor implementation.
