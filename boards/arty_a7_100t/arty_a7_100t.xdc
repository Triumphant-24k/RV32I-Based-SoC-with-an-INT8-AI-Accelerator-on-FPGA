# Digilent Arty A7-100 Rev. D/E pin source, checked 2026-09-07:
# https://github.com/Digilent/digilent-xdc/blob/master/Arty-A7-100-Master.xdc
# Reset polarity: official Arty A7 E.0 schematic, user BTN0 (active high), not CK_RST.
# https://digilent.com/reference/_media/reference/programmable-logic/arty-a7/arty_a7_sch.pdf
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports {clk}]
create_clock -name soc_clock -period 10.000 -waveform {0.000 5.000} [get_ports {clk}]
set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports {reset_btn}]
# Names below are FPGA-perspective. Digilent's UART_RXD_OUT is FTDI -> FPGA.
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports {uart_rx}]
# FTDI drives RX in normal use; the weak pull-up keeps UART idle high if undriven.
set_property PULLUP true [get_ports {uart_rx}]
# Digilent's UART_TXD_IN is FPGA -> FTDI.
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports {uart_tx}]
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

# Genuine asynchronous board inputs: reset and UART RX have no phase relationship
# to soc_clock. Their only uses are reset conditioning and a two-stage RX synchronizer.
# Internal register-to-register and reset-release timing remain timed.
set_false_path -from [get_ports {reset_btn}]
set_false_path -from [get_ports {uart_rx}]
# LEDs and UART TX are not sampled by an external soc_clock-related clock.
# These endpoint-only exceptions do not exempt any internal datapath from timing.
set_false_path -to [get_ports {uart_tx led[*]}]
