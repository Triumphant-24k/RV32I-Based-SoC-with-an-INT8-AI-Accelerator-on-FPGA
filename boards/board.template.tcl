# Copy to a new board-specific file and fill ONLY from the allocated board's
# manual, schematic, manufacturer master XDC, and confirmed clock configuration.
set PART ""
set CLOCK_HZ 0
set BAUD 115200
set RELEASE_CYCLES 0
set PIN_XDC ""
# fpga_top: use DEMO=integrated or cpu. LED/UART standalone tops can also be used.
set TOP fpga_top
set DEMO integrated
