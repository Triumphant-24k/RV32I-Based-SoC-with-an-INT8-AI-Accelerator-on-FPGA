# Arty A7 bring-up

The primary target is the Digilent Arty A7-100T: `xc7a100tcsg324-1`, a 100 MHz onboard clock, and a USB UART at **115200 baud, 8 data bits, no parity, one stop bit, no flow control**. Simulation and Yosys checks are available; Vivado implementation and a programmed-board demonstration are still pending.

The unidentified Artix-7 backup is waiting for a model and schematic. Its [board checklist](../boards/xilinx_artix7_unknown/BOARD_INFO.md) deliberately contains no working pin constraints.

## What's connected

`boards/arty_a7_100t/arty_a7_top.sv` wraps the existing `rtl/soc/ai_soc.sv`. The CPU is `rtl/cpu_core.v`; the accelerator, bus/memories and transmitter are under `rtl/soc/`. CPU sources are Verilog; the SoC, wrapper and testbenches use SystemVerilog, compiled with Icarus `-g2012`. Firmware remains in `firmware/`; verification and build helpers are in `scripts/` and `tb/soc/`.

Everything runs on the input clock. Slow LEDs use counters, not extra clocks. BTN0 is active high: reset asserts asynchronously and releases after synchronization and 10 ms of stable button release. A four-clock FPGA-initialized shift register requests the same reset at configuration, so the CPU and UART remain reset throughout the startup delay. ROM initialization is part of FPGA configuration, not a software file read after boot. UART RX has a weak pull-up and passes through two synchronization registers for activity indication in smoke modes; this version has no receive command interface.

| FPGA port | Pin | Purpose |
| --- | --- | --- |
| clk | E3 | 100 MHz, constrained to 10 ns |
| reset_btn | D9 | User BTN0, pressed high; not the red CK_RST button |
| uart_rx | D10 | USB bridge to FPGA |
| uart_tx | A9 | FPGA to USB bridge |
| led[0] | H5 | Heartbeat: toggles every half second |
| led[1] | J5 | Reset or accelerator busy, stretched 50 ms; UART activity in smoke modes |
| led[2] | T9 | Firmware completed successfully |
| led[3] | T10 | Firmware reported failure |

All listed I/O uses LVCMOS33. The four discrete LEDs are active high. UART names above are **from the FPGA's perspective**; Digilent calls D10 `uart_rxd_out` and A9 `uart_txd_in` from the bridge's perspective.

Pins come from the official [Arty A7-100 master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Arty-A7-100-Master.xdc). Reset polarity and wiring were cross-checked against the [Digilent schematic](https://digilent.com/reference/_media/reference/programmable-logic/arty-a7/arty_a7_sch.pdf). The default part matches Digilent's [board definition](https://github.com/Digilent/vivado-boards/blob/master/new/board_files/arty-a7-100/E.0/1.1/board.xml). Check the physical board revision and chip marking before programming.

The XDC excludes only asynchronous external reset/RX inputs and unsynchronized external LED/TX endpoints from clock-relative timing. Internal CPU, memory, accelerator and reset-release paths remain timed. The exceptions are explained beside the constraints; review CDC and timing reports in Vivado.

## Reproduce the checks

Run from the repository root in PowerShell. The existing Ubuntu-22.04 WSL environment supplies Python 3, Icarus, Verilator, Yosys, Tcl 8.6's shared library and `riscv64-unknown-elf-gcc`. GCC uses `-march=rv32i -mabi=ilp32`; no M extension or runtime library is required.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-regression.ps1
wsl.exe -d Ubuntu-22.04 -- python3 scripts/build_firmware.py
wsl.exe -d Ubuntu-22.04 -- python3 scripts/check_fpga.py
```

The first command includes the other two stages. FPGA checks cover images, all wrapper modes, pin/port agreement, Tcl preflight and failure guards, UART timing, reset and real CPU firmware. Full firmware wrapper simulations shorten the UART divider to keep runs practical; separate Hello and all-byte transmitter tests use the real 100 MHz / 115200 divider (868 clocks per bit).

## Firmware and memory

Reset and ELF entry are at address zero. `firmware/start.S` initializes the stack, copies initialized data and clears BSS, then enters C. `firmware/link.ld` assigns ROM to `0x00000000..0x00003fff` and RAM to `0x00010000..0x00013fff`, reserving the upper 4 KiB for the stack.

The builder reads little-endian ELF32 load segments and emits 4096 lines of eight hexadecimal digits per image: one 32-bit word per line, with the lowest-addressed byte in bits 7:0. ROM contains code, constants and the startup copy of initialized data. RAM starts at zero. Validation rejects malformed, missing, all-zero and all-NOP programs and checks the reset instruction encoding; the complete instruction audit and CPU simulations provide the stronger executable checks.

Original `demo` and `cpu` images retain their existing locations in `firmware/hex/`. Board variants `board` and `board_cpu` are built under ignored `build/firmware/`. Tcl resolves the repository from its own path, validates the selected pair, copies them into the demo run as `rom.hex` and `ram.hex`, and changes into that run directory before synthesis. The RTL receives those local filenames for `$readmemh()`. Absolute source/XDC paths and staged images make invocation independent of the caller's directory, including paths with spaces. ELF, map, disassembly, vendor logs and bitstreams stay under ignored `build/`.

The [complete memory map](SPEC.md#address-map) is unchanged. Accelerator control/status/result/cycles are at `0x40000000/04/08/0c`; vector A occupies `0x40000020..3c`, B `0x40000040..5c`. The SoC cycle counter is `0x40000100`, UART data/status `0x40000104/08`, and persistent demo status `0x4000010c`.

Board firmware prints `RV32I SoC Booted`, the counter-read delta, then 26 sets of signed results, measured cycles, calculated ratios and `TEST PASSED`, followed by `ALL PASS`. A captured simulation example is in [arty_uart_sample.txt](../reports/arty_uart_sample.txt). Failed comparisons print `FAIL` with a reason and case number and latch the failure LED.

The report runs once per startup/reset. Open the terminal first, then press BTN0 to replay it. Integrated LED1 directly follows busy and holds activity for 50 ms after it ends; the actual computation still lasts eight clocks (80 ns at 100 MHz). UART/RX traffic does not light LED1 in integrated mode. CPU-only mode has no accelerator activity. Standalone modes retain the reset/UART activity diagnostic.

`Speedup` compares software cycles with the accelerator's complete MMIO transaction, including vector transfer, start and polling. `Compute-only speedup` divides by the accelerator's own eight-cycle compute count. Ratios are calculated from counters using RV32I software division and truncated to two decimal places. UART formatting occurs outside measured intervals. These are simulation measurements until reproduced on hardware, specific to this eight-element workload and CPU implementation.

## Build with Vivado

Install Vivado with 7-series device support and the board's cable drivers. Open its command prompt, start PowerShell and change to this repository. No board-file installation is required by the non-project flow.

```powershell
.\scripts\build-arty.ps1 -Demo led
.\scripts\build-arty.ps1 -Demo uart
.\scripts\build-arty.ps1 -Demo cpu
.\scripts\build-arty.ps1 -Demo integrated
```

If Vivado is not on PATH, pass `-Vivado 'C:\path\to\Vivado\bin\vivado.bat'`. The helper rebuilds firmware for CPU and integrated modes. Use `-Part` only after confirming a different exact chip marking for the same board/pinout. The direct invocation, after firmware generation, is:

```powershell
vivado.bat -mode batch -source boards/arty_a7_100t/build.tcl -tclargs --demo integrated --part xc7a100tcsg324-1
```

Outputs are in `build/vivado/arty_a7_100t/<demo>/`. The flow synthesizes, optimizes, places and routes, then saves utilization, route status, timing, clock interaction, CDC and DRC reports. It requires recognized clean `check_timing` output, nonnegative setup/hold slack and no error/critical-warning DRC violations before requesting `arty_a7_top.bit`. Tool errors propagate. If a Vivado version changes the timing-report format, the script stops for review. Tcl preflight and mocked guards do not validate vendor command execution; inspect the first real Vivado run carefully.

The helper starts Vivado inside the ignored run folder, containing its logs, journal and `.Xil` working data. For a direct invocation, create/change to an ignored build folder and use the absolute path to `boards/arty_a7_100t/build.tcl`; the Tcl still finds all sources and initialization files. The source list explicitly excludes testbenches, `cpu_sim_top.v` and `simulation_memory.v`. Synthesis-only elaboration excludes parameter-check `$fatal` blocks; FPGA-supported configuration initialization and `$readmemh` remain. Actual Vivado acceptance is pending, not implied by Yosys.

## Connect and program manually

Connect the board's USB-JTAG/UART port with a data-capable USB-A-to-micro-B cable and confirm the board's power selection. In Hardware Manager, auto-connect, verify the actual device/board and program the bitstream from the successful build. This is volatile FPGA configuration; no flash programming is provided.

The optional script does not open hardware unless explicitly invoked with `--program`:

```powershell
# Checks that the bitstream exists; opens no hardware
vivado.bat -mode batch -source scripts/program-arty.tcl -tclargs --demo integrated

# Manual action after confirming the connected Arty A7-100T
vivado.bat -mode batch -source scripts/program-arty.tcl -tclargs --demo integrated --program
```

It connects to the local hardware server, requires exactly one target and device, checks the XC7A100T die and lets Vivado validate/program the bitstream. A JTAG device ID cannot establish the development-board pinout; the operator must confirm the actual Arty board. Multiple targets/devices require explicit selection through Hardware Manager. The script was tested with mocks only and has not programmed hardware. To keep the direct command's default log/journal in an ignored folder, run it there using the absolute script path or supply `-log`/`-journal` paths under `build/`.

Use [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/) or [Tera Term](https://teratermproject.github.io/) with 115200, 8-N-1 and no flow control. Windows Device Manager's Ports (COM & LPT) list shows the USB serial port; compare it before/after connection. Select that COM port and close other applications holding it. The USB-JTAG and UART functions share the board connector but are separate interfaces.

## At the bench

1. **LED heartbeat:** confirm model, chip, revision and power configuration; connect the programming USB interface. Build/program `led` through Vivado Hardware Manager. LED0 should toggle every half second.
2. **Reset:** hold BTN0. LED1 should show reset and the heartbeat should restart after the synchronized release delay. Repeat several times; do not substitute the red reset button.
3. **UART:** program `uart`, open the serial port at the settings above, and check repeated `Hello` messages. Reset should restart the greeting.
4. **CPU:** program `cpu`, reset with the terminal open, and capture 26 `TEST PASSED` messages followed by `ALL CPU PASS`; LED2 should stay on.
5. **Accelerator:** program `integrated`, reset and capture both signed results for all 26 cases, `TEST PASSED` and final `ALL PASS`. Investigate LED3 or any `FAIL` before a demonstration.
6. **Cycle comparison:** retain the serial capture and record the exact bitstream, part, Vivado version and timing result alongside the measured counts and ratios.

A missing heartbeat suggests clock/reset/programming problems; a working heartbeat with no Hello suggests UART port/baud/wiring. CPU-only success narrows subsequent failures to accelerator integration. Reset restarts firmware but does not clear hardware RAM; startup handles data/BSS initialization.

The next evidence needed is real Vivado utilization and setup/hold slack, a successful bitstream, and serial output from the actual board. Yosys mapping is a preparation check, not a substitute for placement, routing or hardware validation.
