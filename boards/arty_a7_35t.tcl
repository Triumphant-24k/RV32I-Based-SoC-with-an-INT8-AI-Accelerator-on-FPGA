# Board configuration for Digilent Arty A7-35T (xc7a35tcsg324-1)
set PART "xc7a35tcsg324-1"
set CLOCK_HZ 100000000
set BAUD 115200
# 10ms debounce at 100 MHz clock
set RELEASE_CYCLES 1000000
set PIN_XDC "boards/arty_a7.xdc"
set TOP fpga_top
set DEMO integrated
