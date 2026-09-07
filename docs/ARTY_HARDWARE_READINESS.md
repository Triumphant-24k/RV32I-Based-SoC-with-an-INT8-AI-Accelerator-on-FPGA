# Arty A7-100T hardware readiness — September 7, 2026

The full regression passed before and after the BTN0 integration changes. The CPU,
SoC bus, UART engine, firmware and INT8 accelerator architecture are unchanged.
The board target is `xc7a100tcsg324-1`, using one 100 MHz input clock. Vivado was not
found on the checked Windows/WSL paths, so vendor synthesis, placement, routing,
timing, DRC, bitstream generation and physical observation remain **NOT RUN**.

## Board connections

The [official Digilent master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Arty-A7-100-Master.xdc)
confirms E3 clock, D9 BTN0, LEDs H5/J5/T9/T10 and USB-UART signals D10/A9.
The [official schematic](https://digilent.com/reference/_media/reference/programmable-logic/arty-a7/arty_a7_sch.pdf)
shows the user button wiring. BTN0 is high when pressed; it differs from the
active-low red reset input used by the previous board wrapper.

The FPGA-perspective names are **RX D10 and TX A9**. Digilent names D10
`uart_rxd_out` and A9 `uart_txd_in` from the USB bridge's perspective. The requested
RX A9 / TX D10 assignment was therefore not used. All eight physical signals use
LVCMOS33; RX also has a weak pull-up for idle-high behavior when undriven.

The top now exposes `clk`, `reset_btn`, `uart_rx`, `uart_tx` and `led[3:0]`.
Reset asserts asynchronously from BTN0 or the FPGA-initialized startup register;
release is synchronized and held for a stable 10 ms. CPU and UART share this reset.
ROM contents are initialized during configuration; the delay does not load files
at runtime. No generated or gated clock was introduced.

Integrated LED0 is a half-second-toggle heartbeat. LED1 indicates reset or actual
accelerator busy, with a 50 ms activity hold after busy to make the 80 ns compute
pulse visible. LED2 is persistent PASS; LED3 is FAIL or CPU trap. Smoke modes retain
their existing reset/UART activity indicator. CPU-only mode produces no accelerator
activity. The eight-clock accelerator timing is unchanged by the LED logic.

## Executed verification

Both complete runs used this command from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-regression.ps1
```

The updated FPGA checks were also run directly during development:

```powershell
wsl.exe -d Ubuntu-22.04 -- python3 scripts/check_fpga.py
```

| Check | Result | Actual evidence |
| --- | --- | --- |
| Imported source integrity | PASS | All 30 original contents match the pinned CPU commit |
| CPU units/core | PASS | 46 unit checks; 176 checks across 63 instruction cases |
| Memory waits | PASS | 3 modes; 14, 50 and 54 cycles |
| Generated CPU tests | PASS | 300 cases, seed 0x52a1c0de |
| Accelerator | PASS | 266 vectors; 12,455 checks, reset ages and busy writes |
| SoC bus | PASS | 61 checks |
| UART | PASS | All 256 bytes at original and production dividers |
| Generic board tests | PASS | Existing reset/heartbeat/UART tests retained |
| Baseline integrated CPU | PASS | 26 cases; 26 starts; 337,242 simulation clocks |
| Stalled integrated CPU | PASS | 26 cases; 26 starts; 386,582 clocks |
| Baseline CPU-only | PASS | 26 cases; zero starts; 216,078 clocks |
| Firmware audit | PASS | RV32I/ILP32 only; 346/280/489/334 static instructions in demo/cpu/board/board_cpu |
| Memory images | PASS | 8 current images; 6 invalid/empty fixtures rejected |
| Fatal Verilator lint | PASS | Three generic tops and three Arty modes; no new waivers |
| Portable Yosys | PASS | Two clocked 4096x32 memories and one signed 8x8 multiplier |
| Yosys xc7 mapping | PASS | 24 RAMB18E1; zero DSP48E1; no unmapped leaf cells or latches |
| XDC agreement | PASS | All eight pins match synthesized ports/directions; 10 ns clock and RX pull-up |
| Build Tcl | PASS | Four preflight modes from another directory; staged files/source checks; six mocked failure/success gates |
| Programming Tcl | PASS | Six mocked guards; default opens no hardware; missing/ambiguous/wrong-device cases stop |
| Arty smoke | PASS | BTN0/reset, heartbeat, RX activity and two decoded Hello messages at 115200 baud |
| Arty integrated CPU | PASS | 26 cases; 26 starts; 1,377,752 clocks; 208 busy clocks and pulse-stretch scoreboard |
| Arty CPU-only | PASS | 26 cases; zero starts/busy clocks; 515,942 clocks |
| Decimal results/ratios | PASS | 26 integrated results and all 52 calculated speedup values checked independently |
| PowerShell helper syntax | PASS | Parsed without errors; missing-Vivado path stops clearly |
| Vivado timing/utilization/bitstream | NOT RUN | Vivado unavailable |
| Actual programming and board demo | NOT RUN | No hardware programming command was executed |

Total simulation clocks include serial output and are not benchmark intervals.
Board case 0 reports matching zero results, CPU 1,870 cycles, accelerator compute
8 cycles, complete transaction 388 cycles and calculated speedup 4.81x. The unchanged
compact baseline firmware retains its separate 385-cycle transaction measurement.

The PowerShell build helper was invoked with
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-arty.ps1 -Demo integrated`
and stopped at the missing-Vivado check. This tests error handling, not implementation.
Full concise regression evidence is in [regression.txt](../reports/regression.txt).

## Build and programming

From a Vivado-enabled PowerShell session in the repository:

```powershell
.\scripts\build-arty.ps1 -Demo led
.\scripts\build-arty.ps1 -Demo uart
.\scripts\build-arty.ps1 -Demo cpu
.\scripts\build-arty.ps1 -Demo integrated
```

The integrated bitstream destination is
`build/vivado/arty_a7_100t/integrated/arty_a7_top.bit`. The helper rebuilds firmware,
launches Vivado inside the ignored run folder and passes the absolute Tcl path.
Tcl locates sources from its own repository path and stages validated initialization
images as local `rom.hex` and `ram.hex` before synthesis. No testbench or simulation
memory wrapper is included in the explicit source list. `$readmemh` and FPGA register
initialization remain synthesis inputs; parameter-check `$fatal` blocks are excluded.

The build generates utilization, route status, setup/hold timing, CDC, clock and DRC
reports. It stops before requesting a bitstream if timing checks are nonzero, their
format is unrecognized, setup/hold slack is negative/missing or blocking DRCs exist.
An old bitstream surviving a failed new run must not be treated as a new successful
build. Tool-format compatibility and real FPGA memory mapping still need Vivado.

Program manually through Hardware Manager after verifying the connected board, or
explicitly run the optional script after a successful build:

```powershell
vivado.bat -mode batch -source scripts/program-arty.tcl -tclargs --demo integrated --program
```

Omitting `--program` checks only that the bitstream exists and opens no hardware.
The script requires one target and one XC7A100T device. It does not program flash;
volatile JTAG configuration disappears when power is removed. JTAG device identity
does not verify the development-board pinout, so physical board identification is
still an operator responsibility. Use an ignored working directory and absolute
script path if default programming logs/journals also need to stay under `build/`.

## Warnings and remaining checks

Yosys reports the register file and small accelerator vectors as registers; this is
expected. The ROM and RAM remain clocked and map to block RAM in Yosys. Its zero-DSP
result is not a Vivado resource claim. There were no new fatal lint diagnostics or
test failures after these changes. Tcl guard tests use mocks and do not certify
vendor APIs, routed timing, DRC or programming success.

The previously documented optional smoke conversion, ACT4 dependencies and formal
setup limitations remain outside this board-integration change. No CPU or accelerator
assertion was removed or weakened. The older Word report is a historical snapshot
and predates this BTN0/LED mapping update.

At the bench, the operator must:

1. Confirm Arty A7-100T model/revision and part; connect the data-capable micro-USB cable.
2. Build with Vivado and inspect actual setup/hold timing, route/DRC and utilization reports.
3. Program LED mode; verify heartbeat and BTN0 reset/release.
4. Program UART mode; identify the USB serial COM port and capture Hello at 115200, 8-N-1, no flow control.
5. Program CPU mode; open the terminal, press BTN0 and capture 26 PASS cases and ALL CPU PASS.
6. Program integrated mode; capture both signed results for all cases, ALL PASS and LED2; investigate any LED3/FAIL.
7. Retain the serial capture and the exact successful bitstream/reports before claiming physical validation.

## Files changed in this board integration

| File | Change |
| --- | --- |
| boards/arty_a7_100t/arty_a7_top.sv | Active-high BTN0 reset and visible accelerator busy LED |
| boards/arty_a7_100t/arty_a7_100t.xdc | D9 BTN0 mapping, RX pull-up and matching reset port; correct UART directions retained |
| boards/arty_a7_100t/build.tcl | Isolated run directory, absolute source paths and staged initialization images |
| scripts/build-arty.ps1 | Launch vendor process inside the dedicated output folder |
| scripts/program-arty.tcl | New opt-in manual programming flow with device/target guards |
| scripts/check_rtl.py | Updated expected physical reset port |
| scripts/check_fpga.py | Separate-directory/image/source checks and programming guard tests |
| tb/soc/arty_tb.sv | BTN0 polarity and exact busy LED/pulse-stretch checks |
| tb/soc/arty_smoke_tb.sv | BTN0 polarity with original smoke assertions retained |
| README.md | Requested concise hardware setup, UART, LEDs and troubleshooting |
| docs/ARTY_BRINGUP.md | Current reset/pins, staged image flow and manual programming |
| docs/SPEC.md | Current board-shell port and LED semantics; peripheral map unchanged |
| docs/FPGA_READINESS.md | Marks earlier snapshot and links this update |
| docs/DIRECTORY_STRUCTURE.md | Current BTN0 description and new file entries |
| docs/ARTY_HARDWARE_READINESS.md | This current verification and handoff report |
| reports/regression.txt | Refreshed actual regression evidence |
| reports/arty_mapping_summary.json | Refreshed Yosys primitive counts for the changed wrapper |

Existing working changes were preserved. Git HEAD advanced externally during the
work; no commit, push or programming command was issued by this implementation run.
