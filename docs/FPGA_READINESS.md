# FPGA readiness — September 6, 2026

The full existing regression passed before edits and again after the Arty additions. The CPU, accelerator and memory map are unchanged. The 30 imported source files still match source commit `64977acc99bfd37eb6c43121e6377a9b47105b72`. No commit or push was made during this work.

## Reproduction and results

From the repository root in PowerShell, the baseline and final regression command was:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-regression.ps1
```

It runs `scripts/check_reuse.py`, `baseline.py`, `build_firmware.py`, all regression simulations, `check_rtl.py`, `check_fpga.py` and `handoff.py` through the existing WSL environment. Individual checks can be repeated with:

```powershell
wsl.exe -d Ubuntu-22.04 -- python3 scripts/build_firmware.py
wsl.exe -d Ubuntu-22.04 -- python3 scripts/check_rtl.py
wsl.exe -d Ubuntu-22.04 -- python3 scripts/check_rtl.py --arty
wsl.exe -d Ubuntu-22.04 -- python3 scripts/check_fpga.py
```

Actual subprocess commands and detailed logs are under ignored `build/`; the concise captured results are in [regression.txt](../reports/regression.txt).

| Check | Result | Actual coverage |
| --- | --- | --- |
| Reused source integrity | PASS | 30 files match recorded source commit |
| CPU units and directed core | PASS | 46 unit checks; 176 core checks across 63 instructions |
| Memory wait states | PASS | 3 modes; 14, 50 and 54 cycles |
| Generated CPU differential tests | PASS | 300 tests, seed 52a1c0de |
| Accelerator | PASS | 266 vectors, 12,455 checks |
| SoC bus | PASS | 61 checks |
| UART | PASS | All 256 byte values at both original and Arty dividers |
| Existing board smoke | PASS | Reset, LED and decoded UART |
| Original integrated firmware | PASS | 26 cases, 26 starts, 337,242 clocks |
| Original stalled integration | PASS | 26 cases, 26 starts, 386,582 clocks |
| Original CPU-only firmware | PASS | 26 cases, zero starts, 216,078 clocks |
| Firmware ISA audit | PASS | demo 346; cpu 280; board 489; board_cpu 334 static instructions |
| Memory image validation | PASS | 8 images; 6 negative fixtures rejected |
| Fatal Verilator lint | PASS | 3 existing tops plus 3 Arty modes |
| Coarse Yosys synthesis | PASS | Both tops: 2 clocked 4096x32 memories, 1 signed 8x8 multiplier |
| Yosys 7-series mapping | PASS | 24 RAMB18E1; zero DSP48E1; no unmapped leaf cells or latches |
| XDC agreement | PASS | All 8 physical pins match elaborated ports/directions; 10 ns clock |
| Tcl preflight/guards | PASS | 4 demo modes, missing-tool path, 6 mocked build scenarios |
| Arty smoke | PASS | Heartbeat, reset, RX activity, 2 decoded Hello messages at 100 MHz/115200 |
| Arty integrated firmware | PASS | 26 cases, 26 starts, 1,377,752 clocks; all 52 printed ratios verified |
| Arty CPU-only firmware | PASS | 26 cases, zero starts, 515,942 clocks |
| Vivado synthesis/place/route/timing/DRC | NOT RUN | Vivado unavailable |
| Bitstream generation and physical board | NOT RUN | Requires Vivado and board |

Clocks in the firmware rows count the entire simulation, including serial reporting. They are not the dot-product benchmark interval. The original benchmark remains unchanged; board reporting produces its own measurements in [arty_benchmarks.json](../reports/arty_benchmarks.json). For board case 0, software and hardware both return zero: CPU 1,870 cycles, compute 8, complete transaction 388, displayed speedup 4.81x and compute-only ratio 233.75x. Case 1 returns 120 with 1,909 CPU cycles and a displayed 4.92x complete-transaction speedup. These are measured simulation results, not hardware results.

Full wrapper firmware simulations use an accelerated UART divider. Separate all-byte and standalone Hello tests verify the production 868-clock divider. Startup reset, button assertion/release, bounce handling and status LEDs are checked in the wrapper simulations.

## Issues found and limits

The startup simulation exposed an initially unknown reset before the first clock; the wrapper now combines the startup/external reset request with the conditioned reset output. A Hello test fixture used a nonportable SystemVerilog carriage-return escape; it now expects explicit CR/LF bytes. The new Yosys resource walker initially mistook a generated parameterized module name for an unmapped primitive; it now descends into modules before checking leaf cells. The final regression passed after these fixes; assertions were retained.

Yosys reports that the CPU register file and small accelerator vectors become registers. ROM/RAM still infer clocked memories and map to block RAM. This Yosys version maps the multiplier without a DSP48; Vivado resource selection remains unmeasured. Git also reports normal LF-to-CRLF conversion notices on this Windows checkout.

The Vivado helper was invoked with `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-arty.ps1 -Demo led` and correctly stopped with exit code 1 and a clear missing-Vivado message. This verifies the unavailable-tool path, not a vendor build. Tcl was evaluated through the installed Tcl 8.6 library; simulated Vivado commands exercise failure guards only. Actual vendor command compatibility, memory initialization, CDC, constraints, utilization and setup/hold timing still need the first real Vivado run. No bitstream was produced or board programmed.

RX is an activity input only. The backup board remains unidentified. No new CPU architecture, receive protocol, formal proof or hardware performance claim is introduced.

The [bring-up guide](ARTY_BRINGUP.md) contains commands, official pin sources, memory details and the LED → reset → UART → CPU → accelerator → cycle-comparison sequence. The main README remains a project overview rather than a task checklist.
