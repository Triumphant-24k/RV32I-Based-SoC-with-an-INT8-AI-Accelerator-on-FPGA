# FPGA allocation and bring-up checklist

Status: simulation-tested engineering preparation only. Neither Arty A7-100T nor
EDGE Zynq Z7010 is confirmed for this event. Do not reuse constraints from the old
ASIC/OpenROAD project. No pin, clock, voltage, PS/PL UART route, or FPGA part has
been guessed in this repository.

1. Confirm reuse permission with the organizers. Record the allocated board name,
   revision, full FPGA part, board manual/schematic revision, oscillator or PL clock
   source/frequency, reset polarity, LED polarity, UART route and I/O bank voltages.
2. Install the appropriate licensed vendor tools and board programmer drivers.
   On Zynq, determine whether a PL clock and UART route require a PS block design.
   This project has no PS initialization or PS/PL routing configuration.
3. Copy `boards/board.template.tcl` and `boards/pins.template.xdc` into confirmed
   board-specific files. Fill pin/IOSTANDARD constraints from the manufacturer.
   Choose CLOCK_HZ and BAUD; actual baud is CLOCK_HZ/floor(CLOCK_HZ/BAUD). Keep error
   within the terminal/device tolerance (preparation script checks 2%). Choose
   RELEASE_CYCLES for an appropriate button debounce period, e.g. 10 ms converted
   using the actual clock. Current RTL defaults are simulation settings only.
4. Run `python3 scripts/regress.py`. Build `led_test_top`; inspect DRC/timing and
   program only the confirmed target. Assert/release reset; verify the LED toggles
   every half-second with the configured clock. Fix clock, polarity or constraints
   before proceeding.
5. Build `uart_test_top`. Configure the terminal for the chosen baud, 8 data bits,
   no parity, 1 stop bit, no flow control. Check repeated U characters and, if needed,
   measure the bit period on a scope. Confirm common ground and correct voltage.
6. Build `fpga_top` with CPU firmware images (`DEMO=cpu` in the preparation config).
   Firmware must print 26 CPU_TEST lines and ALL CPU PASS, then retain the PASS LED.
7. Build with integrated firmware (`DEMO=integrated`). Run:
   `vivado -mode batch -source scripts/vivado_prepare.tcl -tclargs boards/confirmed.tcl`
   This unexecuted vendor-tool template stops after synthesized checkpoint/reports.
   Verify ROM/RAM are block RAM and whether the multiplier maps to a DSP or LUTs.
   Account for synthesis-trimmed ROM bits and target resources using actual reports.
8. Complete placement and routing for the actual part; run DRC, check_timing,
   report_timing_summary with unconstrained paths, report_clock_interaction and
   report_utilization. Review setup/hold, reset recovery/removal, CDC, all ports,
   missing clocks and unjustified exceptions. Resolve violations; do not downgrade
   DRC severity or suppress unconstrained paths to make bitstream generation pass.
9. Generate and program a bitstream only after that review. Save tool versions,
   source commit, completed configuration, reports, bitstream hash and terminal log.
   Do not claim utilization, timing closure or power from portable Yosys results.
10. Assert reset, observe 26 TEST lines plus ALL PASS, check persistent LEDs, and
    repeat reset several times. Compare UART values with the simulation reports.
    CPU and accelerator perform all arithmetic; the laptop only displays UART.
    Label FPGA-validated only after this real-board demonstration is documented.

If UART is silent: check reset release, the clock, firmware initialization paths,
terminal settings and the TX route. If FAIL LED lights, capture UART failure reason;
if a CPU trap prevents UART, use internal ILA signals rather than exposing memory
arrays or raw debug buses at top-level pins.
